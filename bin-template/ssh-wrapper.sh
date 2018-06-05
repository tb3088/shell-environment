#!/bin/bash

shopt -s nullglob
# Usage:
#
#   [VERBOSE=-v] [PROFILE=<profile>] [IDENTITY=<key>]
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
  #   SCREEN   - if set but empty, disable use of screen
  #   SSH_CONFIG - name of SSH configuration file (-F)
  #   PROFILE  - stub used to compute SSH_CONFIG
  #   IDENTITY - path to identity file (-i)

  shopt -s extglob
  local _screen _conf _ident _cmd _env
  local i v p

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
    [0-9]|'') for i in `seq ${DEBUG:-1}`; do v+='v'; done
	        VERBOSE+=" -${v}"
            ;;
    -*)	    VERBOSE+=" $DEBUG"
            ;;
  esac

  # casting about for IDENTITY is risky, so don't do it!
  for v in IDENTITY SSH_CONFIG; do
      [ -n "${!v}" -a ! -f "${!v}" ] && {
          >&2 echo "ERROR: $v file (${!v}) not found"; return 1; }
  done

  if [ -z "$SSH_CONFIG" ]; then
      # attempt a quick search - traversing CWD not advised.
      for _conf in {${0%/bin/*},$HOME}/.{ssh,aws}{/$AWS_PROFILE,}{/$AWS_REGION,}{/$PROFILE,}/config{{.,-,_}$PROFILE,} ; do
          # discard candidate without a hit on $PROFILE 
          [[ "$_conf" =~ $PROFILE ]] || continue
          [ -f "$_conf" ] && { SSH_CONFIG="$_conf"; break; }
      done
      : ${SSH_CONFIG:?"ERROR: no SSH_CONFIG found for SSH profile (${PROFILE:-none})"}
# gratuitous output screws with 'rsync' etc.
#      >&2 echo "INFO: found SSH_CONFIG '$SSH_CONFIG' ${PROFILE+for PROFILE '$PROFILE'}"
  fi

  # UserKnownHostFile shouldn't be hard-coded inside 'config' because brittle
  if [ -z "$SSH_KNOWN_HOSTS" ]; then
      [ -f "${SSH_CONFIG%/*}/known_hosts.$PROFILE" ] &&
        SSH_KNOWN_HOSTS="${SSH_CONFIG%/*}/known_hosts.$PROFILE" ||
        SSH_KNOWN_HOSTS="${SSH_CONFIG%/*}/known_hosts"
  fi

  # propagate environment when running Screen
  _env=
  for v in SSH_CONFIG PROFILE IDENTITY ${!AWS_*} VERBOSE; do
      [ -n "${!v}" ] || continue
      _env+=" $v='${!v}'"
  done

  ${DEBUG:+runv} eval ${_screen:+$_screen -t "$PROFILE:$1" ${TERM:+ -T $TERM} bash -c \"} \
      ${_env:+ env $_env} \
      ${!_cmd} $VERBOSE \
      ${IDENTITY:+ -i "$IDENTITY"} \
      ${SSH_CONFIG:+ -F "$SSH_CONFIG"} \
      ${SSH_KNOWN_HOSTS:+ -o UserKnownHostsFile="$SSH_KNOWN_HOSTS"} \
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
