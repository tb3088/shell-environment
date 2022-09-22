umask 022

export PATH MANPATH
export LANG='en_US.utf8'

# kill WINDOWS' PATH inheritance, but MUST set in ControlPanel->System->Environment
# see logic in /etc/profile via CYGWIN_NOWINPATH

if [ -z "$SSH_AUTH_SOCK" -a `type -p ssh-agent` ]; then
  eval `ssh-agent ${SSH_AGENT_ARGS:-${BASH_VERSION:+ -s}}`
  trap "kill -9 $SSH_AGENT_PID" EXIT
fi

# Amazon Linux family doesn't support '-q' or much of anything
[ -n "$SSH_AUTH_SOCK" ] && ssh-add "$HOME"/.ssh/{id_?sa,*.pem} 2>/dev/null

# CAC/PIF card support
#FIXME paths should come from bashrc_`uname`, not hard-coded here
#case ${OSTYPE:-`uname`} in
#  [lL]inux*)
#        : ${OPENSC_LIB:=/usr/lib/`uname -m`-linux-gnu/opensc-pkcs11.so} ;;
#  cygwin|CYGWIN_*)
#        # MSI doesn't allow tailoring path
#        : ${OPENSC_LIB:=`convert_path "$PROGRAMFILES/OpenSC Project/OpenSC/pkcs11/opensc-pkcs11.dll"`} ;;
##  [dD]arwin*)
#        : ${OPENSC_LIB:=/usr/local/lib/opensc-pkcs11.so}
#esac
#[ -f "$OPENSC_LIB" -a  -n "$SSH_AUTH_SOCK" ] && ssh-add -s "$OPENSC_LIB" 2>/dev/null


for f in ${BASH_SOURCE}.local "$HOME"/.bashrc; do
  [ -f "$f" ] || continue
  source "$f"
done

: ${EDITOR:=`type -p vim vi nano pico emacs | head -n 1`}
: ${PAGER:='\less -RF'}
export EDITOR PAGER


# vim: expandtab:ts=4:sw=4
