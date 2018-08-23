#!/bin/bash

# Usage: MFA_ID=<mfa_device_id> $0 [ options ] <AWS_PROFILE> <MFA_CODE>
#
# most common use case is to set the AWS environment variables
#
#       $ eval `MFA_ID=... $0 ...`
#
# Author: Matthew Patton (mpatton@Enquizit.com)
# License: BSD

function runv() { echo >&2 "+ $*"; [ -n "${NOOP:+x}" ] || "$@"; }
function cleanup() { exit 1; }

which jq &>/dev/null || { echo >&2 "ERROR: command 'jq' not found on \$PATH"; exit 1; }

: {$VERBOSE:=0}
: {$DEBUG:=0}
stscmd='get-session-token'
role=''
print2env=1
print2creds=0
declare -A fields=(
    [AccessKeyId]=aws_access_key_id 
    [SecretAccessKey]=aws_secret_access_key 
    [SessionToken]=aws_session_token
    [Expiration]=aws_session_expire
)

options='cdEnv'
while getopts ":$options" opt; do
  case "$opt" in
    c)	# modify .aws/credentials (potentially DANGEROUS!)
	print2creds=1
	;;

    n)  NOOP=1 ;&
    d)  DEBUG+=1 ;&
    v)  VERBOSE+=1 ;;

    E)	# don't print out for environnment
	unset print2env
	;;
#    q)	# no output
#	;;
#    r)	# assume role (automatic)
#	;;
#    s)	# get session (default)
#	;;
    :)	echo >&2 "ERROR! missing argument (-$OPTARG)"
	exit 2
	;;
    \?)	echo >&2 "ERROR! invalid option (-$OPTARG)"
	exit 2
	;;
    *)	echo >&2 "NOTICE: unhandled option (-$OPTARG)"
	exit 255
  esac
done
shift "$((OPTIND-1))"

# alternatively ...
#set -- "`getopt "$@"`"
#while [ ${#@} -gt 0 ]; do
#  case $1 in
#   e)  ...; shift [2]
#  esac
#done


# ------- MAIN --------

profile="${1:-${AWS_PROFILE:?}}"

case "$profile" in
  nyu|nyu.*)
        account_id=120017232434
        mfa="arn:aws:iam::$account_id:mfa/${MFA_ID:?}"
        ;;&
  nyu)  ;;
  nyu.it-sandbox) 
	account_id=231328997772
	role='OrganizationAccountAccessRole'
	;;
  nyu.it-dev) 
	account_id=508939681246
	role='Migration_Contractor'
	;;
  *)	echo "NOTICE: unhandled AWS Profile ($profile)"
	exit 255
esac

[ -n "$role" ] && 
    stscmd="assume-role --role-arn arn:aws:iam::${account_id:?}:role/$role --role-session-name RSN-$profile-$$"


# assumes 'master.trusting' AWS profile naming pattern where
# the 'master' defines IAM principals that the 'trusting' will accept

[ "${profile%.*}" == "${AWS_PROFILE%.*}" ] || unset ${!AWS_*}
AWS_PROFILE=$profile
unset profile


if [ -n "$mfa" -o \( -z "$AWS_SESSION_TOKEN"  -o \
	-z "`aws configure get aws_session_token --profile $AWS_PROFILE`" \) -o \
    false ]; then
  # TODO replace 'false' with check for expired

  set -euo pipefail
  trap cleanup SIGHUP SIGTERM SIGINT ERR

  output=`${DEBUG:+ runv} aws sts $stscmd ${mfa:+ --serial-number $mfa --token-code $2} \
	${DURATION:+ --duration-seconds $DURATION} --profile ${AWS_PROFILE%.*}`

  [ ${VERBOSE:-0} -gt 0 ] && jq -MS <<< "$output"

  for key in "${!fields[@]}"; do
    val="${fields[$key]}"
    [ -n "$val" ] || continue

    eval ${val^^}=`jq -r .Credentials.$key <<< "$output"`
    if [ ${print2creds:-0} = '1' ]; then
	${DEBUG:+ runv} eval aws configure set $val \$${val^^} --profile $AWS_PROFILE 
    fi
  done
fi


# ------- OUTPUT -------
set +e

if [ ${print2env:-0} = '1' ]; then
  echo
  for v in ${!AWS_*}; do echo "$v='${!v}'"; done
  echo "export ${!AWS_*}"
fi

# vim: set expandtab:ts=4:sw=4
