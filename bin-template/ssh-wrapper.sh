#!/bin/bash
#
# Usage:
#
#   [DEBUG=<0-9>] [VERBOSE=<0-9>|-v ...] [PROFILE=<profile>] [SSH_IDENTITY=<key>] [SSH_CONFIG=<path_to>]
#       ssh-wrapper.sh [options] [cmd] <host> [args]
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

declare -F debug >/dev/null ||
function debug() {
    if declare -F log_${FUNCNAME^^} >/dev/null ; then
        log_${FUNCNAME^^} "$@"
    else
        [ -z "$DEBUG" ] || log "${FUNCNAME^^}" "$@"
    fi
}

declare -F info >/dev/null ||
function info() {
    if declare -F log_${FUNCNAME^^} >/dev/null ; then
        log_${FUNCNAME^^} "$@"
    else
        [ -z "${VERBOSE}${DEBUG}" ] || log "${FUNCNAME^^}" "$@"
    fi
}

declare -F warn >/dev/null ||
function warn() {
    if declare -F log_${FUNCNAME^^} >/dev/null ; then
        log_${FUNCNAME^^} "$@"
    else
        >&2 log "${FUNCNAME^^}" "$@"
    fi
}

declare -F error >/dev/null ||
function error() {
    if declare -F log_${FUNCNAME^^} >/dev/null ; then
        log_${FUNCNAME^^} "$@"
    else
        >&2 log "${FUNCNAME^^}" "$@"
        [ ${SHLVL:-1} -eq 1 -o -z "$BASH_SOURCE" ] && return ${RC:-1} || exit ${RC:-1}
    fi
}

declare -F runv >/dev/null ||
function runv() { >&2 echo "+ $*"; "$@"; }

# Check for essential binaries
for p in SSH SCP SFTP SCREEN; do
    # skip variables set to anything, even '' so as to not clobber aliases
    [ -n "${p+x}" ] || continue

    eval $p=`$WHICH ${p,,} 2>/dev/null`
    # screen not found is benign
    [ -n "${!p}" -o "$p" = 'SCREEN' ] || error "missing binary ($p)"
done

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

  local prefix stub combo
  local file=config
  local b c {d,D}{1..3} e
  local item1=${1:-$PROFILE} item2=${2:-$REGION}

  # TODO? if ${prefix: -1} overlaps $delim, single pass thru loop
#  [[ -n "$prefix" && "${prefix: -1}" =~ [`printf '%s' "${delim[@]}"`] ]] && {
#        D1="${prefix: -1}"; prefix="${prefix::-1}"
#    }

  # bulk-set D* variable from defaults
  for i in D{1..3}; do eval "[ \${#$i[@]} -ne 0 ]" || declare -n $i=delim; done

  for b in $item1 $item2 ''; do
    for c in $item1 $item2 ''; do
        [ -n "$b" -a \( "$c" = "$b" -o -z "$c" \) ] && continue

        # create combined suffix 'e' when b and c are empty
        [ -z "$b$c" -a -n "$item2" -a -n "$item1"  ] &&
            combo="$item2\${d3}$item1 $item1\${d3}$item2"

        # NOTE if D# is Array, will only process 1st element
        for d1 in "${D1[@]}"; do
            for d2 in "${D2[@]}"; do
                [ -n "$b" -a -n "$c" ] && stub="$b$d2$c" || stub="$b$c"

                for e in $combo $item2 $item1; do
                    [ "$e" = "$b" -o "$e" = "$c" ] && continue

                    for d3 in "${D3[@]}"; do
                        # XXX does '$prefix.../config/*' have merit?
                        # force '.../config*' format
                        [ "$d3" = '/' ] && continue

                        echo "$prefix${stub:+$d1$stub}/${file}${d3}$e"
                    done
                done
                echo "$prefix${stub:+$d1$stub}/$file"
                [ -z "$b$c" ] && break 2
                [ -z "$b" ] && break
            done
        done
    done
  done
}


function _ssh() {
  # environment:
  #   SCREEN        - if set but empty, disable use of screen
  #   PROFILE       - stub used to compute SSH_CONFIG
  #   SSH_CONFIG    - name of SSH configuration file (-F)
  #   SSH_IDENTITY  - path to identity file (-i)
  #   SSH_VERBOSE   - specific to SSH and not this script

  local _{screen,file,cmd,env,prefix,verbose}
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
    case $v in
        # skip irrelevent
        SSH_AGENT_PID|SSH_AUTH_SOCK|SSH_VERBOSE|SSH_OPTS) continue ;;
    esac

    [ -n "${!v}" -a -f "${!v}" ] || error "file $v (${!v}) not found!"
  done

  # TODO? convert to function since identical
  [ -n "$SSH_CONFIG" ] || {
    debug "looking for SSH_CONFIG"

    # NOTICE: This level of search can take a while, flavor to taste.
    for _file in `[ -n "$BASEDIR" ] && prefix="$BASEDIR" genlist` \
          `[ -n "${!CLOUD*}" ] && prefix="$HOME/${CLOUD:+.$CLOUD/}$CLOUD_PROFILE" genlist` \
          `prefix="$HOME/.ssh" genlist`; do

        # discard match on '.aws/config' since that is reserved
        grep -q -- "${AWS_CONFIG_FILE:-\.aws/config$}" <<< "$_file" && continue

        debug "    $_file"
        [ -f "$_file" ] && { SSH_CONFIG="$_file"; break; }
    done
    : ${SSH_CONFIG:?not found}
  }

  # UserKnownHostFile shouldn't be defined inside 'config' because brittle
  [ -n "$SSH_KNOWN_HOSTS" ] || {
    debug "looking for SSH_KNOWN_HOSTS"

    for _file in ${SSH_CONFIG/config/known_hosts} \
          `[ -n "$BASEDIR" ] && prefix="$BASEDIR" file='known_hosts' genlist` \
          `[ -n "${!CLOUD*}" ] && prefix="$HOME/${CLOUD:+.$CLOUD/}$CLOUD_PROFILE" file='known_hosts' genlist` \
          `prefix="$HOME/.ssh" file='known_hosts' genlist`; do

        debug "    $_file"
        [ -f "$_file" ] && { SSH_KNOWN_HOSTS="$_file"; break; }
    done
    : ${SSH_KNOWN_HOSTS:?not found}
  }

  # propagate environment when running Screen
  _env=
  for v in DEBUG VERBOSE REGION ${!CLOUD*} ${!SSH_*} ${!AWS_*}; do
    [ -n "${!v}" ] || continue

    info "$v = ${!v}"
    _env+=" $v='${!v}'"
  done

  ${DEBUG:+runv} eval ${_screen:+ $_screen -t "$PROFILE:$1" ${TERM:+ -T $TERM} bash -c \"} \
        ${_env:+ env $_env} \
        ${!_cmd} ${SSH_VERBOSE:- -q} \
        ${SSH_IDENTITY:+ -i "$SSH_IDENTITY"} \
        ${SSH_KNOWN_HOSTS:+ -o UserKnownHostsFile="$SSH_KNOWN_HOSTS"} \
        ${SSH_CONFIG:+ -F "$SSH_CONFIG"} \
        $SSH_OPTS \
        "$@" ${_screen:+ ${DEBUG:+ || sleep 15}\"}
}

function init_logs() {
  local _level=${VERBOSE:=$DEBUG}

  case "$_level" in
    -*) ;;  # ignore like '-v -d'

    [4-9])  VERBOSE=3 ;&
    [1-3])
        [ -n "$SSH_VERBOSE" ] || {
            # tone down SSH verbosity 1 level unless DEBUG set
            [ -n "$DEBUG" ] || : $((_level--))
            [ $_level -eq 0 ] || eval printf -v SSH_VERBOSE -- '%.0s-v\ ' {1..$_level}
        }
        ;;&
    # IFF advanced logging (implemented separately)
    3)  LOGMASK=DEBUG ;;
    2)  LOGMASK=INFO ;;
    1)  LOGMASK=NOTICE ;;
    0|'') unset LOGMASK ;;     # defaults to >NOTICE
    *)  error "invalid level ($_level) from VERBOSE or DEBUG"
  esac
  [ -n "$DEBUG" ] && LOGMASK=DEBUG
}


#--- main ---

while getopts 'dvqF:i:' _opt; do
  case "$_opt" in
    d)  : $((DEBUG++)) ;;
    v)  : $((VERBOSE++)) ;;
    q)  unset DEBUG VERBOSE ;;
    F)  SSH_CONFIG="$OPTARG" ;;
    i)  SSH_IDENTITY="$OPTARG" ;;
#    \?)
  esac
done
shift $((OPTIND - 1))

[ -n "$1" ] || RC=2 error 'insufficient arguments'

_prog=$( basename -s .sh "$BASH_SOURCE" )
_progdir=$( cd `dirname "$BASH_SOURCE"`; pwd )
BASEDIR="${_progdir%/bin}"

[ -n "${SSH_CONFIG:-$PROFILE}" ] || {
    # compute from wrapper filename
    _origin=$( basename -s .sh `readlink "$BASH_SOURCE"` )
    [ "$_prog" = "$_origin" ] || PROFILE="$_prog"
}

# MAGIC: disable SCREEN and script output when invoked with special suffix.
# However SSH_VERBOSE functionality preserved by calling init_logs() first
init_logs
for s in ${NO_SCREEN:-.git .rsync}; do
    [[ "$PROFILE" =~ $s$ || "$BASH_SOURCE" =~ $s$ ]] && {
        unset SCREEN DEBUG VERBOSE
        [ -n "$PROFILE" ] && PROFILE=${PROFILE/%$s}
        break
    }
done

debug "BASEDIR = $BASEDIR"
[ -n "$SSH_CONFIG" ] && info "SSH_CONFIG = $SSH_CONFIG" || info "PROFILE = $PROFILE"

: ${CLOUD:=aws}
: ${CLOUD_PROFILE:=\$${CLOUD^^}_PROFILE}
: ${REGION:=$AWS_DEFAULT_REGION}

# My personal definitions for D{1..3} delimiter sets.
# One can also override via args to genlist() or change the defaults
declare -a D2=('/' '.')
D1='/' _ssh "$@"

unset ${!_*} BASEDIR ${!SSH_*} PROFILE D{1..3} ${!CLOUD*} REGION
# vim: set expandtab:ts=4:sw=4
