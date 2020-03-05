#!/bin/bash

: ${REGION:=${AWS_DEFAULT_REGION:-us-east-1}}

config=`readlink -e $BASH_SOURCE`
config=`dirname "$config"`/`basename "$config" .sh`/config
[ -f "$config" ] || config="$HOME/.ssh/`basename $BASH_SOURCE .sh`.config"
[ -f "$config" ] || unset config

: ${SSH_CONFIG:=${config:-"$HOME/.ssh/config"}}
: ${SSH_KNOWN_HOSTS:=${SSH_CONFIG/config/known_hosts}}


declare -F runv >/dev/null ||
function runv() {
    >&2 printf '%s %s\n' `printf '%.0s+' {1..$SHLVL}` "$*"
    [ -n "$NOOP" ] || "$@"
}

export ${!SSH_*} REGION

${DEBUG:+ runv} ${SSH:-ssh} ${DEBUG:+ -v} ${SSH_CONFIG:+ -F "$SSH_CONFIG"} ${SSH_KNOWN_HOSTS:+ -o UserKnownHostsFile="$SSH_KNOWN_HOSTS"} "$@"

