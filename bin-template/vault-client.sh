#!/bin/bash
#
# typically called as part of
# 	ansible-playbook ... [ --vault-id <label>@<prompt|file|script> ... ]
#
# ref: https://docs.ansible.com/ansible/2.8/user_guide/vault.html
#
# assumes VAULT_DIR=../vault/ if unspecified
# options:
#   -f	    armored vault item en|decryption key
#   -k	    "passphrase" aka crypto seed (cleartext) OpenSSL uses to deterministically
#           compute armor key

shopt -s extglob

_prog=${BASH_SOURCE##*/}
_progdir=$( cd "`dirname "$BASH_SOURCE"`" && pwd )
# ext pattern '?(bin|scripts)' must be injected via variable
_suffix='?(bin|scripts)'
BASEDIR=${_progdir%/$_suffix}
#_PROG=`readlink -e "$BASH_SOURCE"`
#_PROGDIR="${_PROG%/*}"
#_PROG="${_PROG##*/}"


function log() {
  local IFS=$'\n' LEVEL; echo -e >&2 "${LEVEL:-INFO}\t$*"
}
function log.error() { LEVEL=ERROR log "$@"; false; }
function log.notice() { LEVEL=NOTICE log "$@"; }
function log.debug() { LEVEL=DEBUG log "$@"; }
#alt: source .functions_logging

# simple search driven by magic array 'dirs'
function file_search() {
  local -n narg
  local -i found=0 first_match    # injected

  while (( $# )); do
    [ -n "$1" ] || { shift; continue; }

    #WARN!! Bash exits if dereference an invalid variable name
    if [[ "${1,,}" =~ [^a-z0-9_] ]]; then arg=$1
    else narg=$1; arg=${narg:-$1}; fi

    # short-circuit on trivial case
    [ -f "$arg" ] && { echo "$arg"; found=1; ((first_match)) && break; }

    while read prefix; do
      item=${prefix:-.}/$arg
      [ -f "$item" ] && { echo "$item"; found=1; ((first_match)) && break 2; }
    done < <( IFS=$'\n'; echo "${dirs[*]}" )

    shift
  done
  (( $found & 1 ))
}


declare -i use_stdin=0 ROUNDS
declare op='-d' VAULT_DIR vault_id vault_key passphrase= mode='pass'
: ${VAULT_DIR:=vault}

# when invoked by Ansible, command-line args not supported
# inject via self-named variable of type Array
declare -u venv=${_prog%.*}; venv=${venv//[^a-zA-Z0-9]/_}_ARGS

# temporarily save contents of $venv if set on commandline
# or environment since sourcing .env could obliterate it
_venv=`declare -p "$venv" 2>/dev/null`

dirs=( {.,"$BASEDIR","$HOME/.ansible"} )
files=( {,"${_prog%.*}"}.env )
while read item; do
  source "$item"
done < <( file_search "${files[@]}" )

# restore venv
[ -n "$_venv" ] && eval "$_venv"
unset _venv

# load $venv into arguments. nameref needed to cast as array
declare -n vref=$venv
set -- "${vref[@]}" "$@"
unset vref

dirs=( {.,"$BASEDIR","$HOME/.ansible"}{,/"$VAULT_DIR"} )

${DEBUG:+set -x}

  # process command-line arguments
  declare -i OPTIND
  declare opt optval OPTARG
  declare long_opts=()

  while getopts ':hef:P:p:-' opt; do
    case "$opt" in
      e)    op='-e' ;;
      f)    vault_key=$OPTARG
            ;;

      # stdin is preferred for safety
      p)    mode='file' ;&
      P)    passphrase=$OPTARG
            if [ $mode = 'file' ]; then
              passphrase=`first_match=1 file_search "$passphrase"` || {
                  log.error "file not found (passphrase: $passphrase)"; exit 1
                }
            fi
            ;;

      :)    log.error "missing argument (${!OPTIND})" ;;&

    # parse long options without getopt() or re-ordering terms
     \-)    OPTARG=${!OPTIND}
            # special keywords
            if [[ "${OPTARG}" == '--vault-id' ]]; then
              ((OPTIND++)); vault_id=${!OPTIND}

            elif [[ "$OPTARG" =~ \= ]]; then
              optval=${OPTARG#*=}; OPTARG=${OPTARG%%=*}
              declare -n vref=${OPTARG#--}; vref=$optval; unset vref
              #alt: long_opts+=( "${OPTARG%%=*}" "$optval" )
	    else
#              [[ "$OPTARG" =~ [a-zA-Z]{3,} ]] ||
#                log.notice "argument seems short (${OPTARG})"
	      log.debug "assuming simple flag (${OPTARG})"
              long_opts+=( "${OPTARG}" )
            fi
            # discard accumulated and reset
            shift $OPTIND; OPTIND=0
	    ;;

     \?)    log.error "unsupported option (-${OPTARG}, $OPTIND)" ;&
      h|*)  >&2 cat << _USAGE; exit 2

Usage: $_prog ...
_USAGE
    esac
  done
  shift $((OPTIND - 1))

# naked '-' implies problem with getopts
[ "$1" != '-' ] || { log.error "naked dash(-) argument"; exit 22; }


#pedantic
[ "${BASH_SOURCE[1]}" = 'ansible-vault' ] && : ${vault_id:?}

files=( 'vault_key' )       # trigger nameref in file_search()
[ -n "$vault_id" ] && files+=( "$vault_id"{.,-,_}{key,enc} )
vault_key=`first_match=1 file_search "${files[@]}"` || {
    log.error "file not found (vault key: ${vault_key:-$vault_id})"; exit 127
  }

#--------------

# '-md sha256' is pedantic in case of old/bad defaults
ossl_args=( '-salt' '-base64' '-A' '-aes-256-cbc' '-pbkdf2' '-iter' ${ROUNDS:-17568} )

# last-ditch before openssl takes matters into own hands
[ -n "$passphrase" ] || read -t 30 -ep "passphrase:  " passphrase

#deprecated: -k and '-kfile <file>' replaced with -pass
[ -n "$passphrase" ] &&
    ossl_args+=( '-pass' "$mode:$passphrase" ) ||
    ossl_args+=( '-pass' 'stdin' )

#TODO runv()
openssl enc $op "${ossl_args[@]}" "${long_opts[@]}" ${vault_key:+'-in' "$vault_key"}


# vim: expandtab:ts=8:sw=4
