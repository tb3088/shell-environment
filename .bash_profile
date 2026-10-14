# kill WINDOWS' PATH inheritance, but MUST set in ControlPanel->System->Environment
# see logic in /etc/profile via CYGWIN_NOWINPATH


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


for f in ${BASH_SOURCE}.local /etc/profile.d/*.sh; do
  [ -s "$f" ] || continue
  source "$f" || { >&2 echo -e "ERROR\tRC=$? during $f"; }
done


#TODO? detect inside SSH session; [ -n "$SSH_CONNECTION" ]
if [ -z "$SSH_AUTH_SOCK" ] && type -p ssh-agent >/dev/null; then
  #NOTE if '~/.ssh/' symlinks into Dropbox the socket is unusable
  eval $( ssh-agent "${SSH_AGENT_ARGS[@]:-'-T'}" ${BASH_VERSION:+'-s'} )

  [ -n "$SSH_AGENT_PID" ] && trap "kill -9 $SSH_AGENT_PID" EXIT
  #alt: ssh-add -k for trap statement
fi

# Amazon Linux doesn't support flags ('-q')
[ -S "$SSH_AUTH_SOCK" ] && ssh-add ${DEBUG:+'-v'} ${VERBOSE:+'-v'}

source "$HOME"/.bashrc


# vim: expandtab:ts=4:sw=4
