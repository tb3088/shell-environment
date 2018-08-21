#!/bin/bash

# Usage:

function runv() { 
  echo >&2 "+ $*"
  "$@"
}

function cleanup() {
  echo "unset ${!AWS_*}"
  exit 1
}

trap cleanup SIGHUP SIGTERM SIGINT ERR

declare -A fields=(
    [AccessKeyId]=aws_access_key_id 
    [SecretAccessKey]=aws_secret_access_key 
    [SessionToken]=aws_session_token
    [Expiration]=aws_session_expire
)
cmd_id='get-session'

profile="${1:-${AWS_PROFILE:?}}"

case "$profile" in
  nyu|nyu.*) 
	account_id=120017232434
	role=
	mfa="arn:aws:iam::$account_id:mfa/patton"
	;;&
  nyu.it-sandbox) 
	account_id=231328997772
	role='OrganizationAccountAccessRole'
	cmd_id='assume-role'
	;;
  nyu.it-dev) 
	account_id=508939681246
	role='Migration_Contractor'
	cmd_id='assume-role'
	;;
  *)	echo "Error: unsupported value ($profile)"; exit 1
esac

declare -A cmd=(
    [assume-role]="assume-role --role-arn arn:aws:iam::${account_id:?}:role/${role:?} --role-session-name RSN-$profile-$$"
    [get-session]='get-session-token'
)


[ "${profile%.*}" == "${AWS_PROFILE%.*}" ] || unset ${!AWS_*}
AWS_PROFILE=$profile
unset profile

if [ -n "$mfa" -o \( -z "$AWS_SESSION_TOKEN"  -o \
	-z "`aws configure get aws_session_token --profile $AWS_PROFILE`" \) -o \
    false ]; then
  # TODO replace 'false' with check for expired

  set -euo pipefail
  output=`${DEBUG:+ runv} aws sts ${cmd[$cmd_id]} ${mfa:+ --serial-number $mfa --token-code ${2:?}} \
	${DURATION:+ --duration-seconds $DURATION} --profile ${AWS_PROFILE%.*}`

  for key in "${!fields[@]}"; do
    val="${fields[$key]}"
    [ -n "$val" ] || continue

#    eval ${val^^}=`jq -r .Credentials.$key <<< "$output"`
    ${DEBUG:+ runv} aws configure set $val `jq -r .Credentials.$key <<< "$output"` --profile $AWS_PROFILE 
  done
  set +x
fi

#for v in ${!AWS_*}; do echo "$v='${!v}'"; done
echo "export AWS_PROFILE=$AWS_PROFILE"

