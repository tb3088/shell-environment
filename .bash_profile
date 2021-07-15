umask 022

export PATH MANPATH
export LANG='en_US.utf8'

# ANSI color codes
RS="\[\033[0m\]"    # reset
HC="\[\033[1m\]"    # hicolor
UL="\[\033[4m\]"    # underline
INV="\[\033[7m\]"   # inverse background and foreground
FBLK="\[\033[30m\]" # foreground black
FRED="\[\033[31m\]" # foreground red
FGRN="\[\033[32m\]" # foreground green
FYEL="\[\033[33m\]" # foreground yellow
FBLE="\[\033[34m\]" # foreground blue
FMAG="\[\033[35m\]" # foreground magenta
FCYN="\[\033[36m\]" # foreground cyan
FWHT="\[\033[37m\]" # foreground white
BBLK="\[\033[40m\]" # background black
BRED="\[\033[41m\]" # background red
BGRN="\[\033[42m\]" # background green
BYEL="\[\033[43m\]" # background yellow
BBLE="\[\033[44m\]" # background blue
BMAG="\[\033[45m\]" # background magenta
BCYN="\[\033[46m\]" # background cyan
BWHT="\[\033[47m\]" # background white

function __prompt() {
  local _rc=$?
  #TODO _prompt=() and use IFS='<enter' to join elements
  local _prompt=

if [ -n "$GIT_PROMPT" ]; then
  local _branch _upstream _stat{us,} _delta 
  local -i _mod _del _add _unk _ign _tot
  eval $(
    set -e -o pipefail
    awk '
        NR==1 {
            sub(/\(no branch\)/, ""); gsub(/[\[\],]/, "")
            i=2
            printf "_branch='%s' _status='%s' _delta=%d ", $i, $(i+1), $(i+2)
            next
        }
        $1 ~ /M/ { mod++ }
        $1 ~ /D/ { del++ }
        $1 ~ /A/ { add++ }
        $1 ~ /\?/ { unk++ }
        $1 ~ /!/ { ign++ }
        END { printf "_mod=%d _del=%d _add=%d _unk=%d _ign=%d _tot=%d", mod, del, add, unk, ign, NR-1 }
    ' < <( git --no-pager status --untracked-files=all \
            --ignore-submodules --porcelain --branch 2>/dev/null )
  )

  if [ -n "$_branch" ]; then
    _upstream=${_branch#*...}
    _branch=${_branch%...*}
    [ "$_upstream" != "$_branch" ] || unset _upstream

    # TODO handle both ahead AND behind?
    case "$_status" in
	'ahead')  _status="[${FGRN}${_status}$RS $_delta]"
	    ;;
	'behind') _status="[${FRED}${_status}$RS $_delta]"
	    ;;
	'up-to-date'|*)
	    # _status=`echo -e '\u2713'`
	    unset _status _delta
    esac

    local v
    for v in _mod _del _add _unk _ign _tot; do
      [ ${!v} -ne 0 ] || unset $v
    done

    _stat=( ${_mod+M$_mod} ${_del+D$_del} ${_add+A$_add} ${_unk+U$_unk} ${_ign+I$_ign} )
    _prompt+="\n${UL}Git:$RS ${HC}${_upstream:-$_branch}$RS ${_status:+$_status} ${_stat:+${FRED}${_stat[@]}$RS}"
  fi
fi

  if [ -n "${AWS_PROFILE}${AWS_CONFIG_FILE}${AWS_DEFAULT_REGION}" ]; then
    local _config=${AWS_CONFIG_FILE#$HOME/}
    _config=${_config%/*}; _config=${_config#.aws/}
    _prompt+="\n${UL}AWS:$RS ${FMAG}${_config:+$_config:}${HC}${AWS_PROFILE:---}$RS / ${FBLE}${HC}${AWS_DEFAULT_REGION:---}$RS"

    if [ "$AWS_SESSION_EXPIRE" ]; then
      local _session
      [ `date -d $AWS_SESSION_EXPIRE '+%s' 2>/dev/null` -gt `date '+%s'` ] && _session=`date -d $AWS_SESSION_EXPIRE '+%R'`
      _prompt+="  (${_session:-${BRED}expired$RS})"
    fi
  fi

  #TODO use array with IFS
  PS1="\n${PS_PREFIX}${_prompt}\n"
  [ $EUID -eq 0 ] && PS1+="${BRED}"
  [ $_rc -eq 0 ] && unset _rc
  PS1+="\!${_rc:+($_rc)}$RS "${PS_SCREEN}'\$ '
}

PS_SCREEN='\[\033k\033\134\]'
PS_PREFIX="${FCYN}\u${RS}@${FGRN}\h ${FYEL}\w${RS}"
PS1="\n${PS_PREFIX}\n\! "${PS_SCREEN}'\$ '

# Examples:
# for ROOT
#  PS1="\n${FRED}\u${RS}@${FGRN}\h ${FYEL}\w\n${BRED}\!;\j${RS} \$ "
#
#PS1="\[\e]0;\w\a\]\n\[\e[32m\]\u@\h \[\e[33m\]\w\[\e[0m\]\n\!,\j \$ "
#\[\033[36m\][\t]\[\033[32m\][\u@\h:\[\033[33m\]\w\[\033[32m\]]-> \[\033[0m\]
#
# Whenever displaying the prompt, write the previous line to disk
#PROMPT_COMMAND="history -a"
declare -F __prompt >/dev/null && PROMPT_COMMAND=__prompt

if [ -z "$SSH_AUTH_SOCK" -a `type -p ssh-agent` ]; then
  eval `ssh-agent ${SSH_AGENT_ARGS:-${BASH_VERSION:+ -s}}`
  trap "kill -9 $SSH_AGENT_PID" EXIT
fi

for f in "$HOME"/.bash{_profile.local,rc}; do
  [ -f "$f" ] || continue
  source "$f" || >&2 echo "RC=$? during $f"
done

: ${EDITOR:=`type -p vim vi nano pico emacs | head -n 1`}
: ${PAGER:='less -RF'}
export EDITOR PAGER

[ -n "$SSH_AUTH_SOCK" ] && ssh-add -q "$HOME"/.ssh/{id_?sa,*.pem}


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
