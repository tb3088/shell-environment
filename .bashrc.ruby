which ruby &>/dev/null && return

#TODO system-wide Ruby, not the embedded ones that ship with Chef/Puppet
if [ -d "$PUPPET_BASE/sys/ruby" ]; then
    : ${RUBY_BASE:="$PUPPET_BASE/sys/ruby"}
else
    : ${RUBY_BASE:="${PROGRAMFILES:-/opt}/ruby${RUBY_VERSION}"}
fi

for v in RUBY_BASE; do
    [ -n "${!v}" ] || { unset $v; continue; }
    [ -d "${!v}/bin" ] && addPath "${!v}/bin"
done

# setting GEM_HOME will alter 'INSTALLATION' and 'EXECUTABLE' directory. see 
#   gem env
# However 'USER INSTALLATION DIRECTORY' is hard-coded to $HOME/.gem/ruby/<version>
# To prevent Dropbox from syncing contents and making a royal mess:
#   ln -s $LOCALAPPDATA/.{gem,bundle,berkshelf} $HOME/

export GEM_HOME="${LOCALAPPDATA:-$HOME}/.gem"
# if Ruby is Windows Native (look at final field of `ruby --version' eg. not [x86_64-cygwin]) then
#export GEM_HOME=`cygpath -w -- "${LOCALAPPDATA:-$HOME}/.gem"`


# vim: set expandtab:ts=4:sw=4
