#!/bin/bash
#
# Usage:
#
#   [DEBUG=<0-9>] [VERBOSE=<0-9>|-v ...] [PROFILE=<profile>] [SSH_IDENTITY=<key>] [SSH_CONFIG=<path_to>]
#       ssh-wrapper.sh [cmd] <host> [args]
#
# symlink to this wrapper will automatically set PROFILE

shopt -s nullglob extglob
${ABORT:+set -e}
${CONTINUE:+set +e}

case "${OSTYPE:-`uname`}" in
    [cC]ygwin|CYGWIN*) 
        WHICH='\which --skip-functions --skip-alias'
        ;;
    [dD]arwin*)
        WHICH='\which -s'
        ;;
    *)  WHICH='\which'
esac

declare -F log >/dev/null ||
function log() { echo "$*"; }

declare -F log_DEBUG >/dev/null ||
function log_DEBUG() { [ -z "$DEBUG" ] || log "${FUNCNAME#log_}" "$@"; }

declare -F log_INFO >/dev/null ||
function log_INFO()  { [ -z "${VERBOSE}${DEBUG}" ] || log "${FUNCNAME#log_}" "$@"; }

declare -F log_WARN >/dev/null ||
function log_WARN()  { >&2 log "${FUNCNAME#log_}" "$@"; }

declare -F log_ERROR >/dev/null ||
function log_ERROR() { >&2 log "${FUNCNAME#log_}" "$@"; [ ${SHLVL:-1} -eq 1 ] && return ${RC:-1} || exit ${RC:-1}; }

declare -F runv >/dev/null ||
function runv() { >&2 echo "+ $*"; "$@"; }

function genlist() {
  # Example list
  #
  # REGION/PROFILE/config REGION_PROFILE/config
  # PROFILE/REGION/config PROFILE_REGION/config
  # REGION/config_PROFILE REGION/config
  # PROFILE/config_REGION PROFILE/config
  # config_REGION_PROFILE config_PROFILE_REGION
  # config_REGION         config_PROFILE
  # config

  declare -a delim=('/' '.' '_')    # flavor to taste
  declare -a list=()

  local prefix stub combo
  local file="${1-config}"
  local D1 D2 D3 d1 d2 d3

  # TODO? if ${prefix: -1} overlaps $delim, single pass thru loop
#  [[ -n "$prefix" && "${prefix: -1}" =~ [`printf '%s' "${delim[@]}"`] ]] && {
#        D1="${prefix: -1}"; prefix="${prefix::-1}"
#    }

  # bulk initialize
  for i in D{1..3}; do eval "[ \${#$i[@]} -ne 0 ]" || declare -n $i=delim; done

  for b in $PROFILE $REGION ''; do
    for c in $PROFILE $REGION ''; do
        [ -n "$b" -a \( "$c" = "$b" -o -z "$c" \) ] && continue

        # create combined suffix 'e' when b and c are empty
        [ -z "$b$c" -a -n "$REGION" -a -n "$PROFILE"  ] &&
            combo="${REGION}\${d3}${PROFILE} ${PROFILE}\${d3}${REGION}"

        # NOTE if D# is Array, will only process 1st element
        for d1 in "${D1[@]}"; do
            for d2 in "${D2[@]}"; do
                [ -n "$b" -a -n "$c" ] && stub="$b$d2$c" || stub="$b$c"

                for e in $combo $REGION $PROFILE; do
                    [ "$e" = "$b" -o "$e" = "$c" ] && continue

                    for d3 in "${D3[@]}"; do
                        # TODO does '$prefix.../config/*' have merit?
                        # force '.../config*' format
                        [ "$d3" = '/' ] && continue

                        eval list+=("$prefix${stub:+$d1$stub}/${file}${d3}$e")
                    done
                done
                list+=("$prefix${stub:+$d1$stub}/$file")
                [ -z "$b$c" ] && break 2
                [ -z "$b" ] && break
            done
        done
    done
  done

  echo "${list[@]}"
}

function _ssh() {
  # environment:
  #   SCREEN        - if set but empty, disable use of screen
  #   PROFILE       - stub used to compute SSH_CONFIG
  #   SSH_CONFIG    - name of SSH configuration file (-F)
  #   SSH_IDENTITY  - path to identity file (-i)

  local _screen _file _cmd _env _prefix _verbose
  local i v p

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
    # Ssh option or Host arg
  esac

  # check that SSH_* files exist
  for v in ${!SSH_*}; do
    # skip irrelevent
    case $v in
        SSH_AGENT_PID|SSH_AUTH_SOCK|SSH_VERBOSE) continue ;;
    esac

    [ -n "${!v}" -a -f "${!v}" ] || log_ERROR "file $v (${!v}) not found!"
  done

  # TODO? convert to function since identical

  [ -n "$SSH_CONFIG" ] || {
    log_DEBUG "looking for SSH_CONFIG ..."

    # NOTICE: this level of search can take a while. Flavor to taste.
    for _file in `[ -n "$BASEDIR" ] && prefix="$BASEDIR" genlist` \
          `[ -d "$HOME/.$CLOUD/$CLOUD_PROFILE" ] && prefix="$HOME/.$CLOUD/$CLOUD_PROFILE" genlist` \
          `prefix="$HOME/.ssh" genlist`; do

        # discard match on '.aws/config' since that is reserved
        grep -q -- "${AWS_CONFIG_FILE:-\.aws/config$}" <<< "$_file" && continue

        log_DEBUG "    $_file"
        [ -f "$_file" ] && { SSH_CONFIG="$_file"; break; }
    done
    unset _file
    : ${SSH_CONFIG:?not found}
  }

  # UserKnownHostFile shouldn't be defined inside 'config' because brittle
  [ -n "$SSH_KNOWN_HOSTS" ] || {
    log_DEBUG "looking for SSH_KNOWN_HOSTS ..."

    for _file in ${SSH_CONFIG/config/known_hosts} \
          `[ -n "$BASEDIR" ] && prefix="$BASEDIR" genlist 'known_hosts'` \
          `[ -d "$HOME/.$CLOUD/$CLOUD_PROFILE" ] && prefix="$HOME/.$CLOUD/$CLOUD_PROFILE" genlist 'known_hosts'` \
          `prefix="$HOME/.ssh" genlist 'known_hosts'`; do

        log_DEBUG "    $_file"
        [ -f "$_file" ] && { SSH_KNOWN_HOSTS="$_file"; break; }
    done
    unset _file
    : ${SSH_KNOWN_HOSTS:?not found}
  }

  # propagate environment when running Screen
  _env=
  for v in DEBUG VERBOSE REGION ${!CLOUD*} ${!SSH_*} ${!AWS_*}; do
    [ -n "${!v}" ] || continue

    log_INFO "$v = ${!v}"
    _env+=" $v='${!v}'"
  done

  ${DEBUG:+runv} eval ${_screen:+ $_screen -t "$PROFILE:$1" ${TERM:+ -T $TERM} bash -c \"} \
        ${_env:+ env $_env} \
        ${!_cmd} ${SSH_VERBOSE- -q} \
        ${SSH_IDENTITY:+ -i "$SSH_IDENTITY"} \
        ${SSH_KNOWN_HOSTS:+ -o UserKnownHostsFile="$SSH_KNOWN_HOSTS"} \
        ${SSH_CONFIG:+ -F "$SSH_CONFIG"} \
        $SSH_OPTS \
        "$@" ${_screen:+ ${DEBUG:+ || sleep 15}\"}
}


#--- main ---

[ $# -gt 0 ] || RC=2 log_ERROR 'insufficient arguments'

case "${VERBOSE:-$DEBUG}" in
    -*|'') ;;  # skip

    # LOGMASK useful only if advanced logging (implemented separately)
    [4-9]) VERBOSE=3 ;&
    [1-3]) eval printf -v SSH_VERBOSE -- '%.0s-v\ ' {1..${VERBOSE:-$DEBUG} ;;&
    3)  LOGMASK=DEBUG ;;
    2)  LOGMASK=INFO ;;
    1)  LOGMASK=NOTICE ;;
    0)  unset LOGMASK ;;        # unlikely
    *)  log_ERROR "invalid value (${VERBOSE+VERBOSE=$VERBOSE}${DEBUG+DEBUG=$DEBUG})"
esac
# tone down verbosity 1 level unless DEBUG set
[ -n "$DEBUG" ] && LOGMASK=DEBUG || SSH_VERBOSE=${SSH_VERBOSE/-v }

for p in SSH SCP SFTP SCREEN; do
    # skip variables set to anything, even '' so as to not clobber aliases
    [ -n "${p+x}" ] || continue

    eval $p=`$WHICH ${p,,} 2>/dev/null`
    # screen not found is benign
    [ -n "${!p}" -o "$p" = 'SCEEN' ] || log_ERROR "missing $p binary"
done

BASEDIR=`dirname "$BASH_SOURCE"`
BASEDIR="${BASEDIR%/bin}"
[ "$BASEDIR" = "$HOME" ] && { log_WARN "ignoring BASEDIR=HOME"; unset BASEDIR; } || log_INFO "BASEDIR = $BASEDIR"

[ -n "${SSH_CONFIG:-$PROFILE}" ] || {
    # compute from wrapper filename
    _origin=$( basename -s .sh `readlink "$BASH_SOURCE"` )
    _prog=$( basename -s .sh "$BASH_SOURCE" )
    [ "$_prog" = "$_origin" ] || PROFILE="$_prog"
}
unset _origin _prog

[ -n "$SSH_CONFIG" ] && log_INFO "SSH_CONFIG = $SSH_CONFIG" || log_INFO "PROFILE = $PROFILE"

# disable Screen
for s in ${NO_SCREEN:-git rsync}; do
    [[ "$PROFILE" =~ .$s ]] && { SCREEN= ; break; }
done

: ${CLOUD:=aws}
: ${CLOUD_PROFILE:=$AWS_PROFILE}
: ${REGION:=$AWS_DEFAULT_REGION}

# My personal definitions for D{1..3} delimiter sets.
# One can also override via args to genlist() or change the defaults
declare -a D2=( '/' '.' )
D1='/' _ssh "$@"


# vim: set expandtab:ts=4:sw=4
