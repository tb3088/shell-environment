#!/bin/bash

# Usage:
#
#   [DEBUG=<0-9>] [VERBOSE=<0-9>|-v ...] [PROFILE=<profile>] [REGION=<region>]
#       [SSH_IDENTITY=<key>] [SSH_CONFIG=<path>]
#       ssh-wrapper.sh [options] [cmd] <host> [args]
#
# symlink to this wrapper will automatically set PROFILE

source ~/.functions
is_function log runv || { >&2 echo -e "ERROR\tmissing essential functions (log, runv)"; exit 1; }


#TODO? use recursion
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

  declare -a delim=('/' '.' '_' '-')    # flavor to taste

  local prefix stub combo=()
  local b c d{1..3} e
#  declare -I D{1..3}            # inherit from parent
  local item1=$1 item2=$2
  local file
  : ${file:?}

  # bulk-set D* variable from defaults
  for i in D{1..3}; do declare -p $i &>/dev/null || declare -n $i=delim; done

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
                # without 'e'
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
  #   SCREEN            disable use of screen if set+empty
  #   PROFILE, REGION   stub used to compute SSH_CONFIG
  #   SSH_LOGFILE       path to log (-E)
  #   SSH_CONFIG        name of SSH configuration file (-F)
  #   SSH_IDENTITY      path to identity file (-i)
  #   SSH_VERBOSE       specific to SSH verbosity and not script body
  #   SSH_OPTS          options intercepted by getopts()

  # check that SSH_* files exist if already defined
  for v in SSH_{CONFIG,KNOWN_HOSTS} ; do
    [ -n "${!v}" ] || continue

    [ -s "${!v}" ] || log.error "file not found ($v ${!v})"
  done

  if [ -z "$SSH_CONFIG" ]; then
    log.debug "searching for SSH_CONFIG"

    # NOTICE: This level of search can take a while, flavor to taste.
    local file
    while read file; do
      # discard match on '.aws/config' since that is reserved
      [ "$file" = "${AWS_CONFIG_FILE:-$HOME/.aws/config}" ] && continue

      log.debug "\t$file"
      [ -s "$file" ] && { SSH_CONFIG="$file"; break; }
    done < <(
        for dir in "${SEARCH_DIRS[@]}"; do
          [ -n "$dir" ] || continue

          prefix="$dir" file=config genlist $REGION $PROFILE
        done
      )

    : ${SSH_CONFIG:?not found}
  fi

  # UserKnownHostFile shouldn't be defined inside 'config' because brittle
  #TODO pre-process CONFIG for said directive

  : ${SSH_KNOWN_HOSTS:=${SSH_CONFIG/config/known_hosts}}

  [ "${SSH_CONFIG%/*}" = "${SSH_KNOWN_HOSTS%/*}" ] ||
      log.warn "mismatched parent" "$SSH_CONFIG" "$SSH_KNOWN_HOSTS"


  local -a _screen=()
  #TODO use __prompt_aws' contextual base if !PROFILE
  # WARN!  $1 could be anything at all, an option even; hoping for hostname
  if [[ -n "$SCREEN" && "${TERM:-X}" =~ ^screen ]]; then
    _screen=( "$SCREEN" -t "$PROFILE:$1" -T vt100 '--' )
  elif [ -n "$WT_SESSION" ]; then
    _screen=( wt new-tab '--title' "($PROFILE) $1" '--suppressApplicationTitle' '--' )
  fi

  local cmd
  case "$1" in
    scp|sftp) cmd=${1^^}
            ;&
    ssh)    # disable Screen where persistent command output is helpful
            unset _screen; shift
            ;;

    edit)   cmd=${EDITOR:-vi}
            ;&
    # assumes operation against either of SSH_CONFIG or SSH_KNOWN_HOSTS
    echo|file)
            declare -n file=${2:-SSH_CONFIG}
            ${cmd:-$1} "$file"
            return
  esac
  : ${cmd:=SSH}

  # propagate environment when running Screen
  local -a env=(); local -u var
  while read var; do
    [[ $var =~ SSH_?(IDENTITY|CONFIG|KNOWN_HOSTS|OPTS|VERBOSE) ]] && continue
    [ -n "${!var+X}" ] || continue

    env+=( `printf "%s=%q" "$var" "${!var}"` )
  done < <( eval printf '%s\\n' DEBUG VERBOSE REGION \${!${CLOUD}_*} ${!SSH_*} )

  # path-munge if Cygwin|WSL and binary is Windows
  if is_windows "${!cmd}"; then
    for v in SSH_{CONFIG,IDENTITY,KNOWN_HOSTS,LOGFILE}; do
      declare -n nv=$v
      nv=`convert_path "${!v}"`
    done
  fi

  # Add keys to agent
  ssh-add "${SSH_CONFIG%/*}"/*.pem 2>/dev/null

  ${DEBUG:+ runv} "${_screen[@]}" \
      /bin/env "${env[@]}" "${!cmd}" \
      ${SSH_VERBOSE:-'-q'} \
      ${SSH_IDENTITY:+ -i "$SSH_IDENTITY"} \
      ${SSH_CONFIG:+ -F "$SSH_CONFIG"} \
      ${SSH_KNOWN_HOSTS:+ -o UserKnownHostsFile="$SSH_KNOWN_HOSTS"} \
      ${SSH_LOGFILE:+ -E "$SSH_LOGFILE"} \
      "${SSH_OPTS[@]}" "$@"

  # Remove keys (requires .pub files)
  ssh-add -d "${SSH_CONFIG%/*}"/*.pem 2>/dev/null
}


function init_logs() {
  local -i _level=0

  [ -n "$VERBOSE" ] && _level=1
  [ -n "$DEBUG" ] && : $(( _level++ ))

  [ $_level -ge 1 ] && SSH_VERBOSE="-`printf '%.0sv' {1..$_level}`"
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

BASEDIR="${_progdir%/bin}"


declare -i OPTIND=
declare -a SSH_OPTS=()
# intercept standard options that need Cygwin->Windows path munging
while getopts ':qE:F:i:' opt; do
  case "$opt" in
    q)  unset DEBUG VERBOSE ;;

    E)  SSH_LOGFILE=$OPTARG ;;
    F)  SSH_CONFIG=$OPTARG ;;
    i)  SSH_IDENTITY=$OPTARG ;;

    \?) # unrecognized, possible long-option
        case "${@:$OPTIND:1}" in
#          -var)
#                SSH_OPTS+=('-var' "${@:$((++OPTIND)):1}")
#                ;;
#          -var-file=*)
#                _save+=("${@:$((OPTIND++)):1}")
#                ;;

          # assume program option, no arg
          -[46AaCfGgKkMNnqsTtVvXxYy]*)
                SSH_OPTS+=( "${@:$((OPTIND++)):1}" )
                ;;
          # assume program option, single arg
          -*)   SSH_OPTS+=( "${@:$((OPTIND++)):1}" )
                # check next word for option flag, but ignore missing
                [[ "${@:$OPTIND:1}" =~ ^\- ]] || {
                    [ -n "${@:$OPTIND:1}" ] && SSH_OPTS+=( "${@:$((OPTIND++)):1}" )
                  }
                ;;
          --)   break ;;            # pedant
        esac
        ;;
    :)  RC=2 log.error "missing argument (-$OPTARG)" ;;
#    *)  RC=2 log.warn "unhandled option (-$opt)"
  esac
done
shift $((OPTIND-1))

[ -n "$1" ] || RC=2 log.error 'insufficient arguments'
[ -n "$SSH_CONFIG" ] && unset PROFILE


init_logs

# Check for essential binaries
for p in SSH SCP SFTP SCREEN; do
  # don't clobber even if empty
  [ -n "${!p+X}" ] && continue

  declare -n pp=$p
  pp=`VERBOSE=1 is_exec "${p,,}"` || log.warn "missing binary ($p)"
  log.info "$p == ${!p}"
done


# There be DRAGONS!
# disable SCREEN and script debug output when invoked with special suffix
for s in ${NO_SCREEN:-git rsync}; do
  if [[ "${SSH_CONFIG:-$PROFILE}" =~ \.${s}$ ]]; then
    unset SCREEN DEBUG VERBOSE
    # highly unusual for SSH_CONFIG to use this
    [ -n "$PROFILE" ] && PROFILE=${PROFILE/%.$s}
    break
  fi
done

# tad contrived
[ -n "${!AWS_*}" ] && CLOUD=aws

if [ -n "$CLOUD" ]; then
#  source ~/.functions_$CLOUD || exit

  # do NOT override PROFILE
  case $CLOUD in
    aws)    declare -n REGION=${CLOUD^^}_REGION
            [ -n "$AWS_CONFIG_FILE" ] && CLOUD_PREFIX=${AWS_CONFIG_FILE%/*}
            ;;
  esac

  # don't repeat search - won't catch symlink equivalency
  [ "$BASEDIR" != "$CLOUD_PREFIX" ] || unset CLOUD_PREFIX
fi

SEARCH_DIRS=( "$CLOUD_PREFIX" "$BASEDIR" "$HOME/.ssh" )

#TODO $# = 0 and CLOUD; select host from 
#   aws ec2 describe-instances --query "Reservations[].Instances[?State.Name == 'running'].InstanceId[]" --output text

# My personal definitions for D{1..3} delimiter sets.
# One can also override via args to genlist() or change the defaults
D1='/'
D2=( '/' '.' )

_ssh "$@"


# vim: expandtab:ts=4:sw=4
