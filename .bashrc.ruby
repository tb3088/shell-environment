which ruby &>/dev/null && return

# Mixing Windows/Unix style PATH/DIRSEP doesn't work!
for v in `convert_path -p "$RUBY_BASE" "$PROGRAMFILES" "$LOCALAPPDATA"` /opt /usr/local; do
  for v2 in "$v"{,/ruby$RUBY_VERSION}/bin; do
    [ -d "$v2" ] && { addPath "$v2"; break; }
  done
done

# setting GEM_HOME will alter 'INSTALLATION' and 'EXECUTABLE' directory. see 
#   gem env
# However 'USER INSTALLATION DIRECTORY' is hard-coded to $HOME/.gem/ruby/<version>
# To prevent Dropbox from syncing contents and making a royal mess:
#   ln -s $LOCALAPPDATA/.{gem,bundle,berkshelf} $HOME/

export GEM_HOME="`convert_path "${LOCALAPPDATA:-$HOME}"`/.gem"

return 0
# vim: set expandtab:ts=4:sw=4
