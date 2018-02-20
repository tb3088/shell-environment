which java &>/dev/null && return

: ${JAVA_HOME:="${PROGRAMFILES:-/opt}/java${JAVA_VERSION}"}

for v in JAVA_HOME; do
    [ -n "${!v}" ] || { unset $v; continue; }
    [ -d "${!v}/bin" ] && addPath "${!v}/bin"
done

# vim: set expandtab:ts=4:sw=4
