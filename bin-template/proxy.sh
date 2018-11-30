#!/bin/bash
#
# typically placed in /etc/profile.d
# VERBOSE=1 will print to STDOUT while DEBUG=1 to STDERR
#
# During interactive use '-n' turns on VERBOSE, prints current value if any, but does NOT set
#
# NOTE 
# 'no_proxy' specifies trailing DOMAINs. An IP is invalid!
#
# However since no TLD ends in [0-9] that is one way to allow connections using IP to bypass.
#
#    [no_proxy]=`printf "%d," {0..9}`           # is dangling ',' benign?


# reset datatype with math
declare -i _verbose=$(( VERBOSE + 0 ))
declare -i _debug=$(( DEBUG + 0 ))
declare -i _noop=$(( NOOP + 0 ))

# quick-set Hash
eval declare -A spec=(`echo  [{ht,f}tp{,s}_proxy]='http://proxy:3128'` [no_proxy]='' )

while [ -n "${1+x}" ]; do
  k=${1%%=}; k=${k,,}

#FIXME use getopt
  case $k in
    -d) : ${DEBUG:=1} ;;
    -n) : ${VERBOSE:=1}
        noop=1
        ;;
    *_proxy)
        spec[$k]="${1#=}"
        ;;
  esac
  shift
done

for k in "${!spec[@]}"; do      # ordering is NOT guranteed
  # default unset values to 'http_proxy'
  [ "$k" = "no_proxy" ] && def= || def="${spec[http_proxy]}"

  K=${k^^}
  [ -n "$noop" ] ||
      export $k=${spec[$k]:-$def} $K=${spec[$k]:-$def}

  [ -n "${DEBUG}${VERBOSE}" ] && eval ${DEBUG:+'>&2'} echo -e "$k=${!k}\\\n$K=${!K}"
done

unset spec k K noop def

