#!/bin/bash

shopt -s nullglob
# Usage:
#
#   [VERBOSE=-v] [PROFILE=<profile>] [SSH_IDENTITY=<key>] [SSH_CONFIG=<path_to>]
#       ssh-wrapper.sh [cmd] <host> [args]
#
# just symlink to the wrapper to automatically set PROFILE

[ ${#@} -gt 0 ] || { >&2 echo ' insufficient arguments'; exit 1; }

case ${OSTYPE:-`uname`} in
    [cC]ygwin|CYGWIN*) 
        WHICH='\which --skip-functions --skip-alias'
	;;
    [dD]arwin*)
        WHICH='\which -s'
	;;
    *)
	WHICH='\which'
esac

for p in SSH SCP SFTP SCREEN; do
    [ "${!p:0:1}" = '/' ] || eval $p=`$WHICH ${!p:-${p,,}} 2>/dev/null`
    [ -x "${!p}" -o "$p" = "SCREEN" ] || {
        >&2 echo -e "ERROR: missing $p binary '${!p}'"; exit 2; }
done

function runv() {
    >&2 echo "+ $*"
    "$@"
}

function _ssh() {
  # environment:
  #   SCREEN        - if set but empty, disable use of screen
  #   PROFILE       - stub used to compute SSH_CONFIG
  #   SSH_CONFIG    - name of SSH configuration file (-F)
  #   SSH_IDENTITY  - path to identity file (-i)

  shopt -s extglob
  local _screen _conf _ident _cmd _env _aws
  local i v p

  : ${PROFILE:?}

  if [ "${TERM%.*}" = "screen" ]; then
      _screen="$SCREEN";
      TERM=${TERM/screen./}
      TERM=${TERM/screen/}
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
            VERBOSE+=" -${v}"
            ;;
    -*)	    VERBOSE+=" $DEBUG"
            ;;
  esac

  for v in ${!SSH_*}; do
      # skip not relevent items
      case $v in
        SSH_AGENT_PID|SSH_AUTH_SOCK)
            continue
            ;;
      esac

      [ -n "${!v}" -a ! -f "${!v}" ] && {
          >&2 echo "ERROR: file $v='${!v}' not found"; return 1; }
  done

  [ -n "$SSH_CONFIG" ] || {
      # attempt a quick search
      [ "${0%/bin/*}" = "$HOME" ] && _prefix="$HOME" || _prefix='{${0%/bin/*},$HOME}'
      [ -n "$AWS_PROFILE" ] && 
          _aws='.aws/$AWS_PROFILE/{$PROFILE{{/,.}$AWS_DEFAULT_REGION,},$AWS_DEFAULT_REGION}' ||
          _aws='.ssh{/$PROFILE,}'

      # can safely ignore duplicates when $0%/bin/* == $HOME
      for _conf in `eval echo "$_prefix/$_aws/config{{.,-,_}$PROFILE,}"`; do
          # discard match on '.aws/config' since that is reserved
          egrep -q "${AWS_CONFIG_FILE:-\.aws/config$}" <<< "$_conf" && continue

          [ -n "${DEBUG:+x}" ] && echo >&2 "DEBUG: trying config $_conf"
          [ -f "$_conf" ] && { SSH_CONFIG="$_conf"; break; }
      done
      : ${SSH_CONFIG:?ERROR: no SSH_CONFIG found for PROFILE=$PROFILE}
# gratuitous output screws with 'rsync' etc.
#      >&2 echo "INFO: found SSH_CONFIG '$SSH_CONFIG' ${PROFILE+for PROFILE '$PROFILE'}"
  }

  # UserKnownHostFile shouldn't be hard-coded inside 'config' because brittle
  [ -n "$SSH_KNOWN_HOSTS" ] ||
      for SSH_KNOWN_HOSTS in "${SSH_CONFIG%/*}"/known_hosts{."$PROFILE",}; do
          [ -n "${DEBUG:+x}" ] && echo "DEBUG: trying known_host $SSH_KNOWN_HOSTS"
          [ -f "$SSH_KNOWN_HOSTS" ] && break
      done

  # propagate environment when running Screen
  _env=
  for v in PROFILE ${!SSH_*} ${!AWS_*} VERBOSE; do
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
    _origin=$( basename -s .sh `readlink "$0"`)
    _prog=$( basename -s .sh "$0")
    [ "$_prog" != "$_origin" ] && PROFILE="$_prog"
fi

# disable Screen
for s in ${NO_SCREEN:-git rsync}; do
    [[ "$PROFILE" =~ .$s ]] && { unset SCREEN; break; }
done

_ssh "$@"


# vim: set expandtab:ts=4:sw=4
