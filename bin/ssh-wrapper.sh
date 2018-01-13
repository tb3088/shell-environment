#!/bin/bash

shopt -s nullglob
# Usage:
#
#   [VERBOSE=-v] [PROFILE=<profile>] [IDENTITY=<key>]
#       ssh-wrapper.sh [cmd] <host> [args]
#
# just symlink to the wrapper to automatically set PROFILE

[ ${#@} -gt 0 ] || { >&2 echo ' insufficient arguments'; exit 1; }

case `uname -o` in
  Cygwin*) 
	WHICH='\which --skip-functions --skip-alias'
	;;
esac
: ${WHICH:=which}
: ${SSH:=`$WHICH ssh 2>/dev/null`}
: ${SCP:=`$WHICH scp 2>/dev/null`}
: ${SFTP:=`$WHICH sftp 2>/dev/null`}
: ${SCREEN:=`$WHICH screen 2>/dev/null`}

[ -x "$SSH" -a -x "$SCP" -a -x "$SFTP" ] || { 
    >&2 echo -e " missing binaries!\n  SSH=$SSH\n  SCP=$SCP\n  SFTP=$SFTP\n"
    exit 2;
  }

# compute from wrapper filename
: ${PROFILE:=`basename -s .sh "$0"`}

# disable Screen
for s in ${NO_SCREEN:-git rsync}; do
    [ "${PROFILE##*.}" = "$s" ] && { unset SCREEN; break; }
done

function runv() {
    echo >&2 "+ $*"
    "$@"
}

function _ssh() {
  # environment:
  #   SCREEN   - if set but empty, disable use of screen
  #   PROFILE  - name of SSH configuration file (-F)
  #   IDENTITY - path to identity file (-i)

  shopt -s extglob
  local _screen _conf _ident _cmd

  if [ "${TERM%.*}" = "screen" ]; then
      _screen="$SCREEN";
      TERM=${TERM/screen./}
      TERM=${TERM/screen/}
#    : ${TERM:=linux}
  fi

  [ -n "$IDENTITY" -a ! -f "$IDENTITY" ] && {
      >&2 echo "ERROR: '$IDENTITY' not found"; return 1
  }
  [ -n "$SSH_CONFIG" -a ! -f "$SSH_CONFIG" ] && {
      >&2 echo "ERROR: '$SSH_CONFIG' not found"; return 1
  }

  if [ -z "$SSH_CONFIG" ]; then
      # attempt a quick search - traversing CWD not advised.
      for _conf in $HOME/{.ssh,.aws/$AWS_PROFILE}/{,$PROFILE{,/$AWS_REGION}/}config{,{.,-,_}$PROFILE} ; do
          [ -f "$_conf" ] && {
	      SSH_CONFIG="$_conf"
	      >&2 echo "+ found '$SSH_CONFIG' for SSH_CONFIG"
	      break
	  }
      done
      [ -n "$SSH_CONFIG" ] || { >&2 echo "ERROR: search for SSH_CONFIG ($PROFILE) failed"; return 1; }
  fi
# casting about for IDENTITY is dangerous, don't do it!
#	{,${HOME:-\~}/{,.ssh,.aws/$AWS_PROFILE}/}{"$IDENTITY",id_rsa,$PROFILE}{,.pem}

  # UserKnownHostFile shouldn't be hard-coded inside 'config' because that makes it non-portable
  SSH_OPTS+=" -o UserKnownHostsFile=${SSH_CONFIG%/*}/known_hosts"

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

  : ${DEBUG:+${VERBOSE:=-v}}
  _env=
  for v in SSH_CONFIG SSH_OPTS PROFILE IDENTITY ${!AWS_*} VERBOSE; do
      [ -n "${!v}" ] || continue
      _env+=" $v='${!v}'"
  done

#${DEBUG:+runv} ${_screen:+$_screen -t "$PROFILE" ${TERM:+-T $TERM} bash -c \"$_vars} ${!_cmd} ${VERBOSE:+-v} \
  ${DEBUG:+runv} eval ${_screen:+ $_screen -t "$PROFILE:$1" ${TERM:+ -T $TERM} bash -c \"${_env:+ env $_env}} \
	${!_cmd} ${VERBOSE:- -q} \
	${IDENTITY:+ -i "$IDENTITY"} \
	${SSH_CONFIG:+ -F "$SSH_CONFIG"} \
	$SSH_OPTS \
	"$@" ${_screen:+ ${DEBUG:+|| sleep 5}\"}
#	${DEBUG:+ 2>"/tmp/ssh-$PROFILE_$1.err"}
}

_ssh "$@"
