#!/bin/bash


declare -A fields=(
    [AccessKeyId]=aws_access_key_id 
    [SecretAccessKey]=aws_secret_access_key 
    [SessionToken]=aws_session_token
    [Expiration]=aws_session_expire
)

target="${AWS_PROFILE:?}.${1:?}"
[ "$AWS_PROFILE" != "$target" ] || return 0

case $target in
  *.reset|*.clear)
	unset ${!AWS_*}
	AWS_PROFILE=${target%%.*}
	return 0
	;;
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
  *)	echo "Error: unsupported value ($target)"; return 1
esac

declare -a cmd=(
    "aws sts assume-role --role-arn arn:aws:iam::${account_id:?}:role/${role:?} --role-session-name rs-$target-$$"
    "aws sts get-session-token"
)
    

[ -n "$mfa" -a \( -n "$AWS_SESSION_TOKEN"  -o -n "`aws configure get aws_session_token --profile $AWS_PROFILE`" \) ] || {

  for c in "${cmd[@]}"; do
    output=`$c ${mfa:+ --serial-number $mfa --token-code ${2:?}} ${DURATION:+ --duration-seconds $DURATION}` && break
  done
  [ -n "$output" ] || return 1

  for key in "${!fields[@]}"; do
    val="${fields[$key]}"
    [ -n "$val" ] || continue

    eval ${val^^}=`jq -r .Credentials.$key <<< "$output"`
#    aws configure set --profile=$target $val `jq -r .Credentials.$key <<< "$output"`
  done
}

[ -z "$DEBUG" ] || for v in ${!AWS_*}; do echo "$v=${!v}"; done

AWS_PROFILE=$target
export ${!AWS_*}

