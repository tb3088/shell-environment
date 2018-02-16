umask 022
case `uname -o` in
    Cygwin)
        export CYGWIN+=" winsymlinks:native"
        ;;
esac
[ -f "$HOME/.functions" ] && source "$HOME/.functions" || true
[ -f "$HOME/.bash_profile.local" ] && source "$HOME/.bash_profile.local" || true

for ed in vim vi nano pico emacs; do
  : ${EDITOR:=`which $ed 2>/dev/null`}
  [ -n "$EDITOR" ] && { export EDITOR; break; }
done

which ec2-version &>/dev/null || \
for d in `\ls -d /usr/local/ec2-api-tools* 2>/dev/null`; do
    [ -z "$d" -o -h "$d" ] && continue
    addPath "$d/bin"; break
done

addPath "-$HOME/bin"
export PATH MANPATH

[[ $- == *i* ]] && {	# interactive
    : ${SSH_AGENT=`which ssh-agent 2>/dev/null`}
    if [ -z "$SSH_AUTH_SOCK" -a -n "$SSH_AGENT" ]; then
        eval `$SSH_AGENT ${SSH_AGENT_ARGS:-${BASH_VERSION:+-s}}`
        trap "kill $SSH_AGENT_PID" 0
        /usr/bin/ssh-add
        alias ssh='ssh -A'
    fi
  }

[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc" || true
