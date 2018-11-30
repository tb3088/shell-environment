#!/bin/bash

# Usage: MFA_ID=<mfa_device_id> $0 [ options ] <AWS_PROFILE> <MFA_CODE>
#
# most common use case is to set the AWS environment variables
#
#       $ eval `MFA_ID=... $0 ...`
#
# Author: Matthew Patton (mpatton@Enquizit.com)
# License: BSD

function runv() {
  [ -z "${_DEBUG}${_VERBOSE}" ] || echo >&2 "+ $*"
  "$@"
}

#TODO hook functions if defined, compute -vvv, -ddd and add if applicable to awscli commands
#FIXME also check BASH_SOURCE
function cleanup() { [ $SHLVL -gt 1 ] && exit 1 || return 1; }

which jq &>/dev/null || { echo >&2 "ERROR: command 'jq' not found on \$PATH"; exit 1; }

stscmd='get-session-token'
role=''
write2creds=0
declare -A fields=(
    [AccessKeyId]=aws_access_key_id 
    [SecretAccessKey]=aws_secret_access_key 
    [SessionToken]=aws_session_token
    [Expiration]=aws_session_expire
)

declare -i _VERBOSE=$(( VERBOSE + 0 ))
declare -i _DEBUG=$(( DEBUG + 0 ))

options='A:dnvw'
while getopts "$options" opt; do
  case "$opt" in
    d)  _DEBUG+=1   ;;
    n)  write2creds=0 ;;
    v)  _VERBOSE+=1 ;;
    A)  declare -i _duration=$(( OPTARG + 0 ))
        ;;
#    r)	# assume role (automatic)
#	;;
#    s)	# get session (default)
#	;;
    w)	# modify .aws/credentials (potentially DANGEROUS!)
	write2creds=1
	;;
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
shift $((OPTIND-1))

# unset/clear variables for simplified logic
for v in _{DEBUG,VERBOSE}; do
  [ -n "${!v}" -a ${!v} -ne 0 ] || unset $v
done


# ------- MAIN --------

profile="${1:-${AWS_PROFILE:?}}"
# FIXME assumes 'master.trusting' AWS profile naming pattern where
# the 'master' defines IAM principals that the 'trusting' will accept - NO!
# '/' as delimiter also makes sense
[ "${profile%.*}" == "${AWS_PROFILE%.*}" ] || unset ${!AWS_*}
AWS_PROFILE=$profile
unset profile

case "$AWS_PROFILE" in
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

#FIXME params belong in properly filled out ~/.aws/config or AWS_CONFIG_FILE. This form should only be
# used if -a, -r, -p have been specified but really shouldn't be used.
[ -n "$role" ] && 
    stscmd="assume-role --role-arn arn:aws:iam::${account_id:?}:role/$role --role-session-name RSN-$profile-$$"

if [ -n "$mfa" -o \( -z "$AWS_SESSION_TOKEN"  -o \
	-z `aws configure get aws_session_token --profile $AWS_PROFILE` \) -o \
    false ]; then
  # TODO replace 'false' with check for expired

  set -euo pipefail
  trap cleanup SIGHUP SIGTERM SIGINT ERR

  output=`${_DEBUG:+ runv} aws sts $stscmd ${mfa:+ --serial-number $mfa --token-code $2} \
	${_duration:+ --duration-seconds $_duration} --profile "$AWS_PROFILE"`

  [ -z "${_VERBOSE}${_DEBUG}" ] || jq -MS <<< "$output"

  declare -u V
  for key in "${!fields[@]}"; do
    V="${fields[$key]}"
    [ -n "$V" ] || continue

    declare -n nref=$V
    nref=`jq -r .Credentials.$key <<< "$output"`

    [ ${write2creds:-0} -eq 1 ] &&
        ${_DEBUG:+ runv} aws configure set "${V,,}" "${!V}" --profile "$AWS_PROFILE"
  done
fi


# ------- OUTPUT -------
set +e

for v in ${!AWS_*}; do echo "$v='${!v}'"; done
echo "export ${!AWS_*}"

# vim: expandtab:ts=4:sw=4
