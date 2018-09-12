#!/bin/bash

shopt -s nullglob
# Usage:
#
#   [VERBOSE=-v] [PROFILE=<profile>] [SSH_IDENTITY=<key>] [SSH_CONFIG=<path_to>]
#       ssh-wrapper.sh [cmd] <host> [args]
#
# just symlink to the wrapper to automatically set PROFILE

[ $# -gt 0 ] || { echo >&2 ' insufficient arguments'; exit 1; }

case "${OSTYPE:-`uname`}" in
    [cC]ygwin|CYGWIN*) 
        WHICH='\which --skip-functions --skip-alias'
	;;
    [dD]arwin*)
        WHICH='\which -s'
	;;
    *)  WHICH='\which'
esac

for p in SSH SCP SFTP SCREEN; do
    # skip variables set to anything, even '' to not clobber aliases
    [ -n "${p+x}" ] || continue

    eval $p=`$WHICH ${p,,} 2>/dev/null`
    # screen not found is benign
    [ -n "${!p}" -o "$p" = 'SCEEN' ] || {
        echo >&2 -e "ERROR: missing $p binary"; exit 1; }
done

function runv() { echo >&2 "+ $*"; "$@"; }

function _ssh() {
  # environment:
  #   SCREEN        - if set but empty, disable use of screen
  #   PROFILE       - stub used to compute SSH_CONFIG
  #   SSH_CONFIG    - name of SSH configuration file (-F)
  #   SSH_IDENTITY  - path to identity file (-i)

  shopt -s extglob
  local _screen _conf _ident _cmd _env _prefix _mid
  local i v p

  : ${PROFILE:?}

  if [ "${TERM#screen}" != "$TERM" ]; then
      _screen="$SCREEN";
      TERM=${TERM/#screen}
      TERM=${TERM/#.}
  fi

  _cmd=SSH
  case ${1^^} in
    SCP|SFTP)
        _cmd=${1^^}
        ;&
    SSH)
        shift; 
        # disable Screen where persistent command output is helpful
        unset _screen
        ;;
  esac

  case "$DEBUG" in
    [0-9])  for i in `seq $DEBUG`; do v+='v'; done
            _verbose="-${v}"
            ;;
    -*)	    _verbose="$DEBUG"
            ;;
  esac
  grep -q -- "$_verbose" <<< "$VERBOSE" || VERBOSE+=" $_verbose"

  for v in ${!SSH_*}; do
    # skip irrelevent items
    case $v in
        SSH_AGENT_PID|SSH_AUTH_SOCK)
            continue
            ;;
    esac

    [ -n "${!v}" -a ! -f "${!v}" ] && {
        echo >&2 "ERROR: file $v='${!v}' not found"; return 1; }
  done

  if [ -z "$SSH_CONFIG" ]; then
    # attempt a quick search
    [ "${BASH_SOURCE%/bin/*}" = "$HOME" ] && _prefix="$HOME" || _prefix='{${BASH_SOURCE%/bin/*},$HOME}'
#    _prefix='{`dirname $BASH_SOURCE`,$HOME}'
    _mid='.ssh{/$PROFILE,}'
    [ -n "$AWS_PROFILE" ] && 
        _mid="{.aws/$AWS_PROFILE/{$PROFILE{{/,.}$AWS_DEFAULT_REGION,},$AWS_DEFAULT_REGION},$_mid}"

# search pattern
#
#   .aws/$AWS_PROFILE/$PROFILE/$AWS_DEFAULT_REGION/config.$PROFILE
#   .aws/$AWS_PROFILE/$PROFILE/$AWS_DEFAULT_REGION/config-$PROFILE
#   .aws/$AWS_PROFILE/$PROFILE/$AWS_DEFAULT_REGION/config_$PROFILE
#   .aws/$AWS_PROFILE/$PROFILE/$AWS_DEFAULT_REGION/config
#   .aws/$AWS_PROFILE/$PROFILE.$AWS_DEFAULT_REGION/config.$PROFILE
#   .aws/$AWS_PROFILE/$PROFILE.$AWS_DEFAULT_REGION/config-$PROFILE
#   .aws/$AWS_PROFILE/$PROFILE.$AWS_DEFAULT_REGION/config_$PROFILE
#   .aws/$AWS_PROFILE/$PROFILE.$AWS_DEFAULT_REGION/config
#   .aws/$AWS_PROFILE/$PROFILE/config.$PROFILE
#   .aws/$AWS_PROFILE/$PROFILE/config-$PROFILE
#   .aws/$AWS_PROFILE/$PROFILE/config_$PROFILE
#   .aws/$AWS_PROFILE/$PROFILE/config
#   .aws/$AWS_PROFILE/$AWS_DEFAULT_REGION/config.$PROFILE
#   .aws/$AWS_PROFILE/$AWS_DEFAULT_REGION/config-$PROFILE
#   .aws/$AWS_PROFILE/$AWS_DEFAULT_REGION/config_$PROFILE
#   .aws/$AWS_PROFILE/$AWS_DEFAULT_REGION/config
#   .ssh/$PROFILE/config.$PROFILE
#   .ssh/$PROFILE/config-$PROFILE
#   .ssh/$PROFILE/config_$PROFILE
#   .ssh/$PROFILE/config
#   .ssh/config.$PROFILE
#   .ssh/config-$PROFILE
#   .ssh/config_$PROFILE
#   .ssh/config

    for _conf in `eval echo "$_prefix/$_mid/config{{.,-,_}$PROFILE,}"`; do

        # discard match on '.aws/config' since that is reserved
        grep -q -- "${AWS_CONFIG_FILE:-\.aws/config$}" <<< "$_conf" && continue

        [ -n "${DEBUG:+x}" ] && echo >&2 "DEBUG: trying SSH_CONFIG $_conf"
        [ -f "$_conf" ] && { SSH_CONFIG="$_conf"; break; }
    done
    : ${SSH_CONFIG:?ERROR: no SSH_CONFIG found for PROFILE=$PROFILE}
  fi

  # UserKnownHostFile shouldn't be hard-coded inside 'config' because brittle
  if [ -z "$SSH_KNOWN_HOSTS" ]; then
    for SSH_KNOWN_HOSTS in ${SSH_CONFIG%/*}/known_hosts{{.,-,_}$PROFILE,}; do
        [ -n "${DEBUG:+x}" ] && echo >&2 "DEBUG: trying SSH_KNOWN_HOSTS $SSH_KNOWN_HOSTS"
        [ -f "$SSH_KNOWN_HOSTS" ] && break
    done
  fi

  # propagate environment when running Screen
  _env=
  for v in PROFILE ${!SSH_*} ${!AWS_*}; do
    [ -n "${!v}" ] || continue
    _env+=" $v='${!v}'"
  done

  ${DEBUG:+runv} eval ${_screen:+ $_screen -t "$PROFILE:$1" ${TERM:+ -T $TERM} bash -c \"} \
    ${_env:+ env $_env} \
    ${!_cmd} $VERBOSE \
    ${SSH_IDENTITY:+ -i "$SSH_IDENTITY"} \
    ${SSH_KNOWN_HOSTS:+ -o UserKnownHostsFile="$SSH_KNOWN_HOSTS"} \
    ${SSH_CONFIG:+ -F "$SSH_CONFIG"} \
    $SSH_OPTS \
    "$@" ${_screen:+ ${DEBUG:+ || sleep 15}\"}
}


#--- main---
if [ -z "$PROFILE" ]; then
    # compute from wrapper filename
    _origin=$( basename -s .sh `readlink "$BASH_SOURCE"` )
    _prog=$( basename -s .sh "$BASH_SOURCE" )
    [ "$_prog" != "$_origin" ] && PROFILE="$_prog"
fi

# disable Screen
for s in ${NO_SCREEN:-git rsync}; do
    [[ "$PROFILE" =~ .$s ]] && { SCREEN= ; break; }
done

_ssh "$@"


# vim: set expandtab:ts=4:sw=4
