#!/bin/bash


declare -A fields=(
    [AccessKeyId]=aws_access_key_id 
    [SecretAccessKey]=aws_secret_access_key 
    [SessionToken]=aws_session_token
    [Expiration]=aws_session_expire
)

target="${AWS_PROFILE:?}.${1:?}"
[ "$AWS_PROFILE" != "$target" ] || exit 2

case $target in
  nyu.*) 
	account_id=120017232434
	role=
	mfa="arn:aws:iam::$account_id:mfa/patton"
	;;&
  nyu.it-sandbox) 
	account_id=231328997772
	role="OrganizationAccountAccessRole"
	;;
  nyu.it-dev) 
	account_id=508939681246
	role="Migration_Contractor"
	;;
  *)	echo "Error: unsupported value ($1)"; exit 1
esac


set -e -o pipefail

[ -n "$mfa" -a \( -n "$AWS_SESSION_TOKEN"  -o -n "`aws configure get aws_session_token --profile $AWS_PROFILE`" \) ] || {
  output=`aws sts get-session-token ${mfa:+ --serial-number $mfa --token-code $2} ${DURATION:+ --duration-seconds $DURATION}`

  for key in "${!fields[@]}"; do
    val="${fields[$key]}"
    [ -n "$val" ] || continue

    eval ${val^^}=`jq -r .Credentials.$key <<< "$output"`
#    aws configure set --profile=$target $val `jq -r .Credentials.$key <<< "$output"`
  done
}

[ -n "$DEBUG" ] && for v in ${!AWS_*}; do echo "$v=${!v}"; done

#aws sts assume-role --role-arn "arn:aws:iam::${account_id:?}:assumed-role/${role:?}" --role-session-name "rs-$target-$$" ||
#aws sts assume-role --role-arn "arn:aws:iam::${account_id:?}:role/${role:?}" --role-session-name "rs-$target-$$"
#
#AWS_PROFILE=$target
