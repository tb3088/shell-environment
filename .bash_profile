umask 022

export PATH MANPATH
export LANG='en_US.utf8'

: ${EDITOR:=`which "$EDITOR" vim vi nano pico emacs 2>/dev/null | head -n 1`}
: ${PAGER:='less -RF'}
export EDITOR PAGER

if [ -z "$SSH_AUTH_SOCK" -a `which ssh-agent 2>/dev/null` ]; then
  eval `ssh-agent ${SSH_AGENT_ARGS:-${BASH_VERSION:+ -s}}`
  trap "kill -9 $SSH_AGENT_PID" EXIT
fi
if [[ "$-" == *i* ]] || tty -s; then
  #FIXME technically could pipe in password from file
  [ -n "$SSH_AUTH_SOCK" ] && ssh-add "$HOME"/.ssh/{id_?sa,*.pem} 2>/dev/null
fi

for f in "$HOME"/.{bash_profile.local,bashrc}; do
  [ -f "$f" ] || continue
  source "$f" || echo >&2 "RC=$? in $f"
done
unset f

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

# vim: expandtab:ts=4:sw=4
