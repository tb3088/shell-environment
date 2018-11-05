which java &>/dev/null && return

for v in JAVA_HOME "${PROGRAMFILES:-/opt}/java${JAVA_VERSION}"; do
    [ -n "${!v}" ] || continue
    [ -d "${!v}/bin" ] && addPath "${!v}/bin"
done
unset v

# vim: set expandtab:ts=4:sw=4
