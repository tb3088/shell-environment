#!/bin/bash

#Usage:
# if Key=Value then be default entire row returned. but can be modified by specifying Key again

declare -A fields=(
  [status]=1	    [1]='Status'
  [extrequestid]=2  [2]=blah
  [endtime]=3 
  [requestid]=4
  [size]=5 
  [starttime]=6 
  [request]=7 
  [otag]=8 
  [etag]=9
  [version]=10 
  [retries]=11 
  [sdkinvocationid]=12
  [key]=13 
  [md5]=14
)

delim='EOE\n------------------------------------------------------------------------'
declare cols=
declare -A flags=(
  [RS]="${delim}\n*"
  [ORS]="${delim}\n"
  [OFS]='\n'
)

#flags -k 
# -X strips the delim sequence, by unset ORS, but even with delim you can still use 'sort|uniq'
# -1 puts all items on 1 row per record with space delim (by unset OFS) for use with read() or shell eval
#   also implies -X

getopt

# NOTE unset a HASH doesn't remove the KEY like it does in normal arrays,
# so use a canary (undef) to differentiate from empty strings which may be valid value

while [ "$1" ]; do
  k=${1%=*} v=${1#*=}

  # validate argument
  declare -i _index="${fields[${k,,}]}"
  [ $_index -ne 0 ] || log.error "unknwon KEY ($k)"

  if [ "$k" == "$v" ]; then
    cols+=\$"$_index, "
  else
    # pattern matched if values shorter after sub
    [ "${fields[@]/$k/}" != "${fields[@]}" ] ||
	log.error "invalid KEY (capitalization: $k)"
    pattern+="$1|"
  fi
done

# remove dangling punctuation
cols=${cols%, }
pattern=${pattoner%|}

# if '-1' then flags[OFS]='undef'
# if '-X' then flags[ORS]='undef'

#build_command b iterating thru ${!flags[@]}
declare -a cmd=( gawk )
for k in "${!flags[@]}"; do
  kv=${flags[$k]}
  [ "$kv" = "undef" ] && continue
  cmd+=( -v $k=\"$kv\" )
done

#may need to change last term to " " for direct expansion
set -x
gawk -v RS="${delim}\n*" -v ORS="${delim}\n"  "${pattern:+/$pattern/} { print $cols }"
set +x



## format from AWS StorageGateway S3 operations log ##

# Status=200
# ExtRequestId=dk5NqsyS+kc/7/Askc2kMW8m78/FJ1FkNuopOcFE9htNgW4ZIGdUWanJtLH6JCrDW0hbsP8Vd9E=
# EndTime=1614557553032
# RequestId=E84356F834308B6D
# Size=20759
# StartTime=1614557552981
# Request=PutObjectRequest
# Otag=74c76d4c15ecbd130ac27d99862abf15fab56e7cfa82b192bfdab40f9b04a15f
# Etag=0adb472c5c28e325926f908ba48adee4
# Version=zvSorO8F5EDxUpe.zou_0pIDTZiKFlZ2
# Retries=0/0/500
# SdkInvocationId=1817131375
# Key=pmwptp/user/rpalomo/BNSF210223F.751659.rsc
# Md5=CttHLFwo4yWSb5CLpIre5A==
# EOE
# ------------------------------------------------------------------------

