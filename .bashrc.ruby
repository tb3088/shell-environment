which ruby &>/dev/null && return

# do a simple search
for v in "$RUBY_BASE" {"$PROGRAMFILES","$LOCALAPPDATA",/opt,/usr/local,"${PUPPET_BASE:+$PUPPET_BASE/sys}"}/ruby$RUBY_VERSION
do
    [ -n "$v" ] || continue
    v=`convert_path "$v"`
    [ -d "$v/bin" ] && { addPath "$v/bin"; break; }
done

# setting GEM_HOME will alter 'INSTALLATION' and 'EXECUTABLE' directory. see 
#   gem env
# However 'USER INSTALLATION DIRECTORY' is hard-coded to $HOME/.gem/ruby/<version>
# To prevent Dropbox from syncing contents and making a royal mess:
#   ln -s $LOCALAPPDATA/.{gem,bundle,berkshelf} $HOME/

export GEM_HOME=`convert_path "${LOCALAPPDATA:-$HOME}/.gem"`

# vim: set expandtab:ts=4:sw=4
