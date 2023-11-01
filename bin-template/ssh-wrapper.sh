#!/bin/bash

# Usage:
#
#   [DEBUG=<0-9>] [VERBOSE=<0-9>|-v ...] [PROFILE=<profile>] [SSH_IDENTITY=<key>] [SSH_CONFIG=<path_to>]
#       ssh-wrapper.sh [options] [cmd] <host> [args]
#
# symlink to this wrapper will automatically set PROFILE

source "$HOME"/.functions || exit
is_function log runv || { >&2 echo -e "ERROR\tmissing essential functions (log, runv)"; exit 1; }

shopt -s nullglob extglob


#TODO use recursion
function genlist() {
  #Example:
  #
  # REGION/PROFILE/[.ssh/]config    REGION_PROFILE/config
  # PROFILE/REGION/config           PROFILE_REGION/config
  # REGION/config_PROFILE           REGION/config
  # PROFILE/config_REGION           PROFILE/config
  # config_REGION_PROFILE           config_PROFILE_REGION
  # config_REGION                   config_PROFILE
  # [.ssh/]config

  declare -a delim=('/' '.' '_')    # flavor to taste

  local prefix stub combo=()
  local file
  : ${file:=config}
  local b c {d,D}{1..3} e
  local item1=${1:-$PROFILE} item2=${2:-$REGION}

  # bulk-set D* variable from defaults
  for i in D{1..3}; do eval "[ \${#$i[@]} -ne 0 ]" || declare -n $i=delim; done

  for b in $item1 $item2 ''; do
    for c in $item1 $item2 ''; do
        [ -n "$b" -a \( "$c" = "$b" -o -z "$c" \) ] && continue

        # create combined suffix 'e' when b and c are empty
        [ -z "$b$c" -a -n "$item2" -a -n "$item1"  ] &&
            combo=( "$item2\${d3}$item1" "$item1\${d3}$item2" )

        for d1 in "${D1[@]}"; do
            for d2 in "${D2[@]}"; do
                [ -n "$b" -a -n "$c" ] && stub="$b$d2$c" || stub="$b$c"

                for e in "${combo[@]}" "$item2" "$item1"; do
                    [ -n "$e" ] || continue
                    [ "$e" = "$b" -o "$e" = "$c" ] && continue

                    for d3 in "${D3[@]}"; do
                        # force '.../config*' style, prevent further '/'
                        [ "$d3" = '/' ] && continue

                        # 'eval' unrolls embedded $d3 inside $e when $combo
                        eval printf '%s\\n' "${prefix}${stub:+${d1}${stub}}/{.ssh/,}${file}${d3}$e"
                    done
                done
                # trivial '/' case
                eval printf '%s\\n' "$prefix${stub:+${d1}${stub}}/{.ssh/,}$file"

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

  local _cmd=SSH
  local -a _screen

  if [[ -n "$SCREEN" && "${TERM:-X}" =~ ^screen ]]; then
    _screen=( "$SCREEN" -t "$PROFILE:$1" -T vt100 '--' )
  elif [ -n "$WT_SESSION" ]; then
    #NOTE! Win10 'ssh' can NOT be on PATH
    _screen=( wt new-tab '--title' "($PROFILE) $1" '--suppressApplicationTitle' '--' )
  fi

  case ${1,,} in
    scp|sftp)
        _cmd=${1^^}
        ;&
    ssh)
        shift;
        # disable Screen where persistent command output is helpful
        unset _screen
        ;;
    echo|file)
        _cmd=$1 ;;
    edit)
        _cmd=${EDITOR:-vi}
  esac

  # check that SSH_* files exist if already defined
  local v
  for v in SSH_{CONFIG,KNOWN_HOSTS} ; do
    local -n vf=$v
    [ -s "${vf}" ] || { log.error "file $v not found (${vf})"; exit; }
  done

  # TODO? convert to function since identical
  if [ -z "$SSH_CONFIG" ]; then
    log.debug "looking for SSH_CONFIG"

    # NOTICE: This level of search can take a while, flavor to taste.
    while read _file; do
      # discard match on '.aws/config' since that is reserved
      [ "$_file" = "${AWS_CONFIG_FILE:-$HOME/.aws/config}" ] && continue

      log.debug "\t$_file"
      [ -s "$_file" ] && { SSH_CONFIG="$_file"; break; }
    done < <(
        [ -n "$BASEDIR" ] && prefix="$BASEDIR" genlist
        [ -n "$CLOUD_PROFILE" ] && prefix="$HOME/.$CLOUD/$CLOUD_PROFILE" genlist
        prefix="$HOME" genlist
      )

    : ${SSH_CONFIG:?not found}
  fi

  # UserKnownHostFile shouldn't be defined inside 'config' because brittle
  #TODO pre-process CONFIG for said directive
  : ${SSH_KNOWN_HOSTS=${SSH_CONFIG/config/known_hosts}}
  log.debug "assuming SSH_KNOWN_HOSTS co-located with SSH_CONFIG" "\t$SSH_KNOWN_HOSTS"

  # short-circuit
  [[ $_cmd =~ SSH|SCP|SFTP ]] || { $_cmd "${SSH_CONFIG}"; return; }

  # propagate environment when running Screen
  local v _env=()
  while read v; do
    case $v in      # skip explicitly handled
      SSH_IDENTITY|SSH_CONFIG|SSH_KNOWN_HOSTS|SSH_OPTS|SSH_VERBOSE)
            continue ;;
    esac
    _env+=( "$v=${!v}" )
  done < <( eval printf '%s\\n' DEBUG VERBOSE REGION \${!${CLOUD}_*} ${!SSH_*} )

#  is_windows "${!_cmd}" && __READLINK -am $SSH_CONFIG $SSH_IDENTITY $SSH_KNOWN_HOSTS

  # Add keys to agent
  ssh-add "${SSH_CONFIG%/*}"/*.pem 2>/dev/null

  ${DEBUG:+ runv} "${_screen[@]}" \
      /bin/env "${_env[@]}" \
      ${!_cmd} ${SSH_VERBOSE:-'-q'} \
      ${SSH_IDENTITY:+ -i "$SSH_IDENTITY"} \
      ${SSH_KNOWN_HOSTS:+ -o UserKnownHostsFile="$SSH_KNOWN_HOSTS"} \
      ${SSH_CONFIG:+ -F "$SSH_CONFIG"} \
      $SSH_OPTS \
      "$@"

  # Remove keys (requires .pub files)
  ssh-add -d "${SSH_CONFIG%/*}"/*.pem 2>/dev/null
}


function init_logs() {
  local -i _level
  : ${level:=${VERBOSE:-$DEBUG}}

  case "$_level" in
    -*) ;;  # ignore like '-v -d'

    [4-9])  VERBOSE=3 ;&
    [1-3])  if [ -z "$SSH_VERBOSE" ]; then
              # tone down SSH verbosity 1 level unless DEBUG set
              [ -n "$DEBUG" ] || : $((_level--))
              [ $_level -ge 1 ] && SSH_VERBOSE="-`printf -- '%.0sv' {1..$_level}`"
            fi
            ;;&

    # IFF advanced logging (implemented separately)
    3)      LOG_MASK='DEBUG' ;;
    2)      LOG_MASK='INFO' ;;
    1)      LOG_MASK='NOTICE' ;;
    0|'')   unset LOG_MASK ;;     # defaults to WARN
    *)      log.error "invalid level ($_level) from VERBOSE or DEBUG"
  esac
  [ -n "$DEBUG" ] && LOG_MASK='DEBUG'
}


#--- main ---

_prog="${BASH_SOURCE##*/}"
_progdir=$( cd `dirname "$BASH_SOURCE"`; pwd )
_PROG=`readlink -e "$BASH_SOURCE"` || {
    # impossible error
    log.error "broken link ($BASH_SOURCE)"
}
_PROGDIR="${_PROG%/*}"
_PROG="${_PROG##*/}"
[ "${_prog%.*}" = "${_PROG%.*}" ] || PROFILE="$_prog"

BASEDIR="${_progdir%/bin}"          # rather arbitrary...
_args=()

while getopts ':dvqE:F:i:W:' _opt; do
  case "$_opt" in
    d)  : $((DEBUG++)) ;;
    v)  : $((VERBOSE++)) ;;
    q)  unset DEBUG VERBOSE ;;
    E)  LOGFILE="${OPTARG}-wrapper"; _args+=(-E "$OPTARG") ;;
    F)  SSH_CONFIG="$OPTARG"; unset PROFILE ;;
    i)  SSH_IDENTITY="$OPTARG" ;;
    W)  _args+=(-W "$OPTARG") ;;
    \?) # unrecognized
        _opt="${@:$OPTIND:1}"
        case "$_opt" in
#          -var)
#                args+=('-var' "${@:$((++OPTIND)):1}")
#                ;;
#          -var-file=*)
#                _save+=("${@:$((OPTIND++)):1}")
#                ;;
          --)   break ;;                # stop processing
          -*)   # assume program option
                _args+=("${@:$((OPTIND++)):1}")
        esac
        ;;
    :)  RC=2 log.error "missing argument (-$OPTARG)" ;;
    *)  RC=2 log.warn "unhandled option (-$sw)"
  esac
done
shift $((OPTIND-1))

[ -n "$1" ] || RC=2 log.error 'insufficient arguments'

init_logs

# Check for essential binaries
for p in SSH SCP SFTP SCREEN; do
    declare -n pp=$p
    # skip variables set to anything, even '' so as to not clobber aliases
    [ -n "${pp+X}" ] && continue

    pp=`VERBOSE=1; is_exec ${p,,}`
    # screen not found is benign
    [ -n "$pp" -o "$p" = 'SCREEN' ] && log.info "$p=$pp" || log.error "missing binary ($p)"
done

# There be DRAGONS!
# disable SCREEN and script output when invoked with special suffix.
# However SSH_VERBOSE functionality preserved by calling init_logs() first
for s in ${NO_SCREEN:-git rsync}; do
  if [[ "${SSH_CONFIG:-$PROFILE}" =~ \.$s$ ]]; then
    unset SCREEN DEBUG VERBOSE
    # highly unusual for SSH_CONFIG to use this
    [ -n "$PROFILE" ] && PROFILE=${PROFILE/%.$s}
    break
  fi
done

[ -n "$SSH_CONFIG" ] && log.info "SSH_CONFIG=$SSH_CONFIG" || log.info "PROFILE=$PROFILE"

: ${CLOUD:='aws'}
declare -n CLOUD_PROFILE=${CLOUD^^}_PROFILE
#FIXME rename to CLOUD_REGION (keep compat) and check for optional '_DEFAULT'
declare -n REGION=${CLOUD^^}_DEFAULT_REGION

# My personal definitions for D{1..3} delimiter sets.
# One can also override via args to genlist() or change the defaults
D1='/'
D2=('/' '.')
_ssh "${_args[@]}" "$@"

# vim: expandtab:ts=4:sw=4
