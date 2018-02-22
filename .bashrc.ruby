

#TODO system-wide Ruby, not the embedded ones that ship with Chef/Puppet

which ruby &>/dev/null && return

if [ -d "$PUPPET_BASE/sys/ruby" ]; then
    : ${RUBY_BASE:="$PUPPET_BASE/sys/ruby"}
else
    : ${RUBY_BASE:="${PROGRAMFILES:-/opt}/ruby${RUBY_VERSION}"}
fi

for v in RUBY_BASE; do
    [ -n "${!v}" ] || { unset $v; continue; }
    [ -d "${!v}/bin" ] && addPath "${!v}/bin"
done

 # vim: set expandtab:ts=4:sw=4
