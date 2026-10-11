#!/bin/bash
# shellcheck disable=SC2034

# Usage:
#
#   env [DEBUG=<0-9>] [VERBOSE=<0-9>|-v ...] [PROFILE=<profile>] [REGION=<region>]
#     [SSH_IDENTITY=<key>] [SSH_CONFIG=<path>]
#   ssh-wrapper.sh [options] <ssh|scp|sftp> <host> -- [ssh_args]
#
# symlink to this wrapper will automatically set PROFILE

# shellcheck disable=SC1090
source ~/.functions

is_function log runv || {
  >&2 echo -e "ERROR\tmissing essential functions (log, runv)"
  exit "${__invalid:-2}"
}


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

  local prefix file stub combo=() item1=$1 item2=$2
  : "${file:?}"

  local -a delims=( '/' '.' '_' '-' )

  # bulk-set D* from defaults if unset
  for i in D{1..3}; do [ -n "${!i+X}" ] || declare -n "$i"=delims ; done

  # shellcheck disable=SC2016
  if [ -n "$item1" ] && [ -n "$item2" ]; then
    combo=( '${c}${d3}$b' '${b}${d3}$c' )
    stub='${b}${d2}$c'
  else stub='${b}$c'; fi

  for b in "$item1" "$item2" ''; do
    for c in "$item2" "$item1" ''; do
      # short-circuit blank or overlap
      if [ -n "${b}$c" ]; then [ "$b" != "$c" ] || continue; else unset stub; fi

      for d1 in "${D1[@]}"; do
        for d2 in "${D2[@]}"; do
#          if [ -n "$b" ] && [ -n "$c" ]; then stub=${b}${d2}$c ; else stub=${b}$c ; fi

          for e in "${combo[@]}"; do
            [ -n "$e" ] || continue     # d3 is pointless
            # detect overlap in context of either blank
#            if [ "$e" = "$b" ] || [ "$e" = "$c" ]; then continue; fi

            for d3 in "${D3[@]}"; do
              # force '.../config*' pattern
              [ "$d3" != '/' ] || { log.notice "unsupported final delimiter ($d3)"; continue; }

              # 'eval' unrolls embedded
              eval printf '%s\\n' "${prefix}${stub:+${d1}${stub}}"/{.ssh/,}"${file}${e:+${d3}$e}"
            done
          done
          # without 'e'
          eval printf '%s\\n' "${prefix}${stub:+${d1}${stub}}"/{.ssh/,}"${file}"

          [ -n "$stub" ] || return
          [ -n "$b" ] || break          # d2 is exhausted
        done
      done
    done
  done
}


function _ssh() (
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
    while read file; do
      # discard match on '.aws/config' since that is reserved
      [ "$file" = "${AWS_CONFIG_FILE:-$HOME/.aws/config}" ] && continue

      log.debug "\t$file"
      [ -s "$file" ] && { SSH_CONFIG="$file"; break; }
    done < <(
        for dir in "${SEARCH_DIRS[@]}"; do
          [ -d "$dir" ] || continue
          prefix=$dir file='config' genlist "$REGION" "$PROFILE"
        done
      )
  fi

  # pedant
  : ${SSH_CONFIG:?not found}

  # UserKnownHostFile must be carefully defined inside 'config' if
  # SSH binary is Windoze. Cygwin/Linux et. al. should be safe.
#  : "${SSH_KNOWN_HOSTS:=${SSH_CONFIG/config/known_hosts}}"
#  [ "${SSH_CONFIG%/*}" = "${SSH_KNOWN_HOSTS%/*}" ] ||
#      log.warn "mismatched parent" "$SSH_CONFIG" "$SSH_KNOWN_HOSTS"

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
    # disable Screen where persistent command output is helpful
    ssh)    unset _screen; shift ;;

    edit)   cmd=${EDITOR:-vi}
            ;&
    # assumes operation against either of SSH_CONFIG or SSH_KNOWN_HOSTS
    'echo'|'file')
            [ -f "$2" ] || declare -n file=${2:-SSH_CONFIG}
            ${cmd:-$1} "${file:-$2}"
            return
  esac
  : "${cmd:=SSH}"

  # save known env since 'screen' discards
  local -a save_env=(); local -u var

  while read var; do
    # ignore some SSH_* handled below
    [[ "$var" =~ SSH_?(IDENTITY|CONFIG|KNOWN_HOSTS|OPTS|VERBOSE) ]] && continue
    [ -n "${!var+X}" ] || continue

    while read item; do
      save_env+=( "$item" )
    done < <( printf '%s=%q\n' "$var" "${!var}" )

  done < <( eval printf '%s\\n' DEBUG VERBOSE REGION "\${!${CLOUD}_\*}" "${!SSH_*}" )

  # path-munge if Cygwin|WSL and binary is Windows
  if is_windows "${!cmd}"; then
    for v in SSH_{CONFIG,IDENTITY,KNOWN_HOSTS,LOGFILE}; do
      declare -n vref=$v
      vref=`convert_path "${!v}"`      # silently ignore empty value
    done
	unset vref
  fi

  # Add keys to agent
  local ssh_keys=( "${SSH_CONFIG%/*}"/{id_*,*.pem} )
  ssh-add "${SSH_VERBOSE}" "${ssh_keys[@]%/*.pub}"

  ${DEBUG:+ runv} "${_screen[@]}" /bin/env "${save_env[@]}" "${!cmd}" ${SSH_VERBOSE:-'-q'} \
      ${SSH_IDENTITY:+'-i' "$SSH_IDENTITY"} \
      ${SSH_CONFIG:+'-F' "$SSH_CONFIG"} \
      ${SSH_KNOWN_HOSTS:+'-o' UserKnownHostsFile="$SSH_KNOWN_HOSTS"} \
      ${SSH_LOGFILE:+'-E' "$SSH_LOGFILE"} \
      "${SSH_OPTS[@]}" "$@"

  # Remove requires .pub files to exist
  ssh-add "${SSH_VERBOSE}" -d "${ssh_keys[@]%/*.pub}"
)


function init_logs() {
  local -i level=0

  [ -n "$VERBOSE" ] && level=1
  [ -n "$DEBUG" ] && : $((level++))

  (( $level )) && SSH_VERBOSE="-$( eval printf '%.0sv' "{1..$level}" )"
}


#--- main ---

_prog="${BASH_SOURCE[0]##*/}"
_progdir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
_PROG=$( readlink -e "${BASH_SOURCE[0]}" ) || log.error "broken link (${BASH_SOURCE[0]})"
_PROGDIR="${_PROG%/*}"
_PROG="${_PROG##*/}"
BASEDIR="${_progdir%/bin}"

[ "${_prog%.*}" = "${_PROG%.*}" ] || PROFILE=$_prog


declare -a SSH_OPTS=() long_opts=()
declare -i OPTIND; declare opt OPTARG
while getopts ':qE:F:i:' opt; do
  case "$opt" in
    q)  unset DEBUG VERBOSE ;;

    # trap filename-based args for platform-specific rewrite
    E)  SSH_LOGFILE=$OPTARG ;;
    F)  SSH_CONFIG=$OPTARG ;;
    i)  SSH_IDENTITY=$OPTARG ;;

    # possible long-option
    \?) OPTARG=${!OPTIND}       #alt: ${@:$OPTIND:1}
        case "$OPTARG" in
          '--')   break ;;      # impossible?
#          '-var')
#                SSH_OPTS+=('-var' "${@:$((++OPTIND)):1}")
#                ;;
#          -var-file=*)
#                _save+=("${@:$((OPTIND++)):1}")
#                ;;

          # assume program option, no arg
          -[46AaCfGgKkMNnqsTtVvXxYy]*)
                SSH_OPTS+=( "$OPTARG" )
                ;;
          # assume program option, single arg
          '--'[a-z]*) SSH_OPTS+=( "$OPTARG" )
                # check next word for option flag, but ignore missing
                declare -i next=$((OPTIND + 1))
                [[ "${!next}" =~ ^\- ]] || {
                    [ -n "${!next}" ] && { SSH_OPTS+=( "${!next}" ); : $((OPTIND++)); }
                  }
                ;;
        esac
        : $((OPTIND++))
        ;;
    :)  RC=2 log.error "missing argument (-$OPTARG)" ;;
  esac
done
shift $((OPTIND-1))


[ -n "$1" ] || RC=2 log.error 'insufficient arguments'
[ -n "$SSH_CONFIG" ] && unset PROFILE

init_logs

# Check for essential binaries
for p in SSH SCP SFTP SCREEN; do
  declare -n pp=$p

  # don't clobber even if empty
  [ -n "${!p+X}" ] || pp=$( is_exec -v "${p,,}" )
  log.info "$p == ${!p-undefined}"
done
unset -n pp


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


[ -n "${SEARCH_DIRS+X}" ] || SEARCH_DIRS=( "$BASEDIR" "$HOME/.ssh" )

# tad contrived
[ -n "${!AWS_*}" ] && CLOUD=aws

if [ -n "$CLOUD" ]; then
  #NOTE do NOT override PROFILE
  cloud_prefix=

  case "$CLOUD" in
    #TODO?  source ~/.functions_$CLOUD || exit
    #TODO? run `aws config show`
    aws)    declare -n REGION=${CLOUD^^}_REGION
            [ -s "$AWS_CONFIG_FILE" ] && : ${cloud_prefix:=${AWS_CONFIG_FILE%/*}}
            ;;
  esac

  #NOTE will NOT catch symlink equivalency
  # don't duplicate search
  [ "$BASEDIR" != "${cloud_prefix}" ] &&
      SEARCH_DIRS=( "${cloud_prefix}" "${SEARCH_DIRS[@]}" )

  unset cloud_prefix
fi


#TODO $# = 0 and CLOUD; select host from
#   aws ec2 describe-instances --query "Reservations[].Instances[?State.Name == 'running'].InstanceId[]" --output text

# My personal definitions for D{1..3} delimiter sets.
# One can also override via args to genlist() or change the defaults
D1=( '/' ) D2=( '/' '.' ) _ssh "$@"


#TODO VerifyHostKeyDNS=yes to query 'IN SSHFP' record,
# check/add fingerprint: ssh-keyscan <hostname> | ssh-keygen [-E md5] -lf -
# scrape SSM parameter store for same
#ref: https://github.com/kepi/ssh-fingerprints
# VisualHostKey yes for pics, ssh-keygen -lv <pub_key_file> for visual art
# from just fingerprint requires 3rd party
#ref:
#  https://github.com/atoponce/keyart
#  https://github.com/openssh/openssh-portable/blob/f703757234a5c585553e72bba279b255a272750a/sshkey.c#L1005-L1100
#  https://dev.to/krofdrakula/improving-security-by-drawing-identicons-for-ssh-keys-24mc
#  https://stackoverflow.com/questions/30082230/a-command-to-display-a-a-keys-randomart-image-from-a-fingerprint


# vim: expandtab:ts=4:sw=4
