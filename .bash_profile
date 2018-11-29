umask 022

source "$HOME"/.functions

#----------
#TODO have a Hash that defines $bin, $bindir and search paths specific to OS
#     and reduce this to a nested FOR loop (see bashrc.$prog)
#----------

addPath PATH -"$HOME"/{.local/,}bin
export PATH MANPATH
export LANG=$(locale -uU)

if [[ "$-" == *i* ]] || tty -s ; then
  if which ssh-agent &>/dev/null; then
    if [ -z "$SSH_AUTH_SOCK" ]; then
        eval `ssh-agent ${SSH_AGENT_ARGS:-${BASH_VERSION:+ -s}}`
        trap "kill -9 $SSH_AGENT_PID" EXIT
    fi
    [ -n "$SSH_AUTH_SOCK" ] && ssh-add ${DEBUG:- -q} "$HOME"/.ssh/{id_?sa,*.pem} 2>/dev/null

    # CAC/PIF card support
    case ${OSTYPE:-`uname`} in
      [lL]inux*)
            : ${OPENSC_LIB:=/usr/lib/`uname -m`-linux-gnu/opensc-pkcs11.so} ;;
      cygwin|CYGWIN_*)
            # MSI doesn't allow tailoring path
            : ${OPENSC_LIB:="`convert_path -p "$PROGRAMFILES"`/OpenSC Project/OpenSC/pkcs11/opensc-pkcs11.dll"} ;;
      [dD]arwin*)
            : ${OPENSC_LIB:=/usr/local/lib/opensc-pkcs11.so}
    esac
    if [ -f "$OPENSC_LIB" ]; then
      export OPENSC_LIB
      [ -n "$SSH_AUTH_SOCK" ] && ssh-add ${DEBUG:- -q} -s "$OPENSC_LIB"
    fi
  fi
fi

for f in "$HOME"/.{bash_profile.local,bashrc_${OSTYPE:=`uname`}}; do
  egrep -q '.swp$|.bak$|~$' <<< "$f" && continue
  [ -f "$f" ] || continue
  source "$f"
done

: ${EDITOR:=`which "$EDITOR" vim vi nano pico emacs 2>/dev/null | head -n 1`}
: ${PAGER:='less -RSF'}
export EDITOR PAGER
source "$HOME"/.bashrc

# vim: expandtab:ts=4:sw=4
