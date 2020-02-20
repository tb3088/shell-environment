#!/bin/bash

: ${SSH_CONFIG:="$HOME"/.ssh/`basename $BASH_SOURCE .sh`.config}
: ${SSH_KNOWN_HOSTS:=${SSH_CONFIG/config/known_hosts}}

: ${REGION:=${AWS_DEFAULT_REGION:-us-east-1}}

declare -F runv >/dev/null ||
function runv() {
    >&2 printf '%s %s\n' `printf '%.0s+' {1..$SHLVL}` "$*"
    [ -n "$NOOP" ] || "$@"
}

${DEBUG:+ runv} ${SSH:-ssh} ${DEBUG:+ -v} ${SSH_CONFIG:+ -F "$SSH_CONFIG"} ${SSH_KNOWN_HOSTS:+ -o UserKnownHostsFile="$SSH_KNOWN_HOSTS"} "$@"

