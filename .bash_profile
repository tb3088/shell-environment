umask 022

source "$HOME"/.functions || true

#----------
#TODO have a Hash that defines $bin, $bindir and search paths specific to OS
#     and reduce this to a nested FOR loop (see bashrc.$prog)
#----------

addPath "-$HOME/bin"
export PATH MANPATH

which ssh-agent &>/dev/null && \
    if [ -z "$SSH_AUTH_SOCK" ]; then
        eval `ssh-agent ${SSH_AGENT_ARGS:-${BASH_VERSION:+-s}}`
        trap "kill $SSH_AGENT_PID" 0
    fi

[[ "$-" == *i* ]] && { ssh-add; alias ssh='ssh -A'; }
# alternate:        tty -s && /usr/bin/ssh-add

for f in "$HOME"/.{bash_profile.local,bashrc.${OSTYPE:=`uname`}}; do
    [ -f "$f" ] && source "$f" || true
done

for ed in vim vi nano pico emacs; do
    : ${EDITOR:=`which $ed 2>/dev/null`}
    [ -n "$EDITOR" ] && { export EDITOR; break; }
done

source $HOME/.bashrc

# vim: set expandtab:ts=4:sw=4
