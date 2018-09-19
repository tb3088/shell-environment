#!/bin/bash

shopt -s nullglob extglob

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

function genlist() {
    # Example list
    #
    # AWS_PROFILE/REGION/PROFILE/config AWS_PROFILE_REGION_PROFILE/config
    # AWS_PROFILE/PROFILE/REGION/config AWS_PROFILE_PROFILE_REGION/config
    # AWS_PROFILE/REGION/config_PROFILE AWS_PROFILE/REGION/config
    # AWS_PROFILE_REGION/config_PROFILE AWS_PROFILE_REGION/config
    # AWS_PROFILE/PROFILE/config_REGION AWS_PROFILE/PROFILE/config
    # AWS_PROFILE_PROFILE/config_REGION AWS_PROFILE_PROFILE/config
    # AWS_PROFILE/config_REGION_PROFILE AWS_PROFILE/config_PROFILE_REGION
    # AWS_PROFILE/config_REGION         AWS_PROFILE/config_PROFILE
    # AWS_PROFILE/config

    # REGION/PROFILE/config REGION_PROFILE/config
    # PROFILE/REGION/config PROFILE_REGION/config
    # REGION/config_PROFILE REGION/config
    # PROFILE/config_REGION PROFILE/config
    # config_REGION_PROFILE config_PROFILE_REGION
    # config_REGION         config_PROFILE
    # config

  local prefix=${1-.ssh}
  local file=${2-config}
  local stub
  local combo
  declare -a delim=('/' '.' '_' '-')
  declare -a list=()

  for a in $AWS_PROFILE ''; do
    for b in $AWS_DEFAULT_REGION $PROFILE ''; do
        for c in $AWS_DEFAULT_REGION $PROFILE ''; do
            [ -n "$b" -a \( "$c" = "$b" -o -z "$c" \) ] && continue

            for d1 in "${delim[@]}"; do
#              for d2 in "${delim[@]}"; do
#                stub="${a:+$a$d1}${b:+$b$d2}$c"
                stub="${a:+$a$d1}${b:+$b$d1}$c"
                # strip possible dangling delim
                stub="${stub%$d1}"

                for d3 in "${delim[@]}"; do
                    [ "$d3" = '/' ] && continue
                    combo=
                    [ -z "$b$c" -a -n "$AWS_DEFAULT_REGION" ] &&
                        combo="$AWS_DEFAULT_REGION$d3$PROFILE $PROFILE$d3$AWS_DEFAULT_REGION"

                    for e in $combo $AWS_DEFAULT_REGION $PROFILE; do
                        [ "$e" = "$b" -o "$e" = "$c" ] && continue
                        list+=("$prefix${stub:+$stub/}${file}${d3}$e")
                    done
                done
                list+=("$prefix${stub:+$stub/}${file}")
                [ -z "$b$c" ] && break 3
                [ -z "$a$b" ] && break
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

  local _screen _conf _known_hosts _cmd _env _prefix
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

    if [ -n "${!v}" -a ! -f "${!v}" ]; then
        echo >&2 "ERROR: file $v = '${!v}' not found"; return 1
    fi
  done

  if [ -z "$SSH_CONFIG" ]; then
    # NOTICE: this level of search can take a while. Flavor to taste.
    for _conf in `genlist "$BASEDIR"/` \
          `[ -n "$AWS_PROFILE" ] && genlist "$HOME/.aws"/` \
          `genlist "$HOME/.ssh"/`; do

        # discard match on '.aws/config' since that is reserved
        grep -q -- "${AWS_CONFIG_FILE:-\.aws/config$}" <<< "$_conf" && continue

        [ -n "${DEBUG:+x}" ] && echo >&2 "DEBUG: trying SSH_CONFIG = $_conf"
        [ -f "$_conf" ] && { SSH_CONFIG="$_conf"; break; }
    done
    : ${SSH_CONFIG:?ERROR: no file for PROFILE ($PROFILE)}
  fi

  # UserKnownHostFile shouldn't be defined inside 'config' because brittle
  if [ -z "$SSH_KNOWN_HOSTS" ]; then
    for _known_hosts in ${SSH_CONFIG/config/known_hosts} \
          `genlist $(dirname "$BASH_SOURCE")/ known_hosts` \
          `[ -n "$AWS_PROFILE" ] && genlist "$HOME/.aws/" known_hosts` \
          `genlist "$HOME/.ssh/" known_hosts`; do

        [ -n "${DEBUG:+x}" ] && echo >&2 "DEBUG: trying SSH_KNOWN_HOSTS = $_known_hosts"
        [ -f "$_known_hosts" ] && { SSH_KNOWN_HOSTS="$_known_hosts"; break; }
    done
    : ${SSH_KNOWN_HOSTS:?ERROR: no file for PROFILE ($PROFILE)}
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


#--- main ---

BASEDIR=`dirname "$BASH_SOURCE"`
BASEDIR="${BASEDIR%/bin}"

if [ -z "$PROFILE" ]; then
    # compute from wrapper filename
    _origin=$( basename -s .sh `readlink "$BASH_SOURCE"` )
    _prog=$( basename -s .sh "$BASH_SOURCE" )
    [ "$_prog" != "$_origin" ] && PROFILE="$_prog"
fi
unset _origin _prog

# disable Screen
for s in ${NO_SCREEN:-git rsync}; do
    [[ "$PROFILE" =~ .$s ]] && { SCREEN= ; break; }
done

_ssh "$@"


# vim: set expandtab:ts=4:sw=4
