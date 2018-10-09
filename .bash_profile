umask 022

source "$HOME"/.functions

#----------
#TODO have a Hash that defines $bin, $bindir and search paths specific to OS
#     and reduce this to a nested FOR loop (see bashrc.$prog)
#----------

addPath -"$HOME/bin"
export PATH MANPATH

if [[ "$-" == *i* ]] || tty -s ; then
  which ssh-agent &>/dev/null && {
    if [ -z "$SSH_AUTH_SOCK" ]; then
        eval `ssh-agent ${SSH_AGENT_ARGS:-${BASH_VERSION:+ -s}}`
        trap "kill -9 $SSH_AGENT_PID" EXIT
    fi
    [ -n "$SSH_AUTH_SOCK" ] && ssh-add -k 2>/dev/null
  }
fi

for f in "$HOME"/.{bash_profile.local,bashrc.${OSTYPE:=`uname`}}; do
  egrep -q '.swp$|.bak$|~$' <<< "$f" && continue
  [ -f "$f" ] || continue
  source "$f"
done

: ${EDITOR:=`which "$EDITOR" vim vi nano pico emacs 2>/dev/null | head -n 1`}
: ${PAGER:='less -RSF'}
export EDITOR PAGER
source "$HOME"/.bashrc

# vim: set expandtab:ts=4:sw=4
