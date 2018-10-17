# To pick up the latest recommended .bashrc content,
# look in /etc/defaults/etc/skel/.bashrc

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
  local _branch _upstream _status _delta _mod _del _add _unk _ign _tot
  local _prompt=

if [ -n "$GIT_PROMPT" ]; then
  eval $(
    set -e -o pipefail
    awk '
        NR==1 {
	    gsub(/[\[\],]/, " "); sub(/\.{3,}/, " ")
	    printf "_branch=%s _upstream=%s _status=%s _delta=%s ", $2, $3, $4, $5
	    next
	}
        $1 ~ /M/ { mod++; } 
	$1 ~ /D/ { del++; } 
	$1 ~ /A/ { add++; }
	$1 ~ /\?/ { unk++; }
	$1 ~ /\!/ { ign++; }
	END { printf "_mod=%d _del=%d _add=%d _unk=%d _ign=%d _tot=%d", mod, del, add, unk, ign, NR-1; }
    ' < <(git --no-pager --no-optional-locks status --untracked-files=all --ignore-submodules --porcelain --branch 2>/dev/null)
  # TODO handle .svn
  )

  if [ -n "$_branch" ]; then
    # TODO handle both ahead AND behind
    case "$_status" in
	'ahead')  _status+=" $FGRN${_delta}$RS"
	    ;;
	'behind') _status=" $FRED${_delta}$RS"
	    ;;
	'up-to-date'|*)
	    # _status=`echo -e '\u2713'`
	    unset _status _delta
    esac
    for v in _mod _del _add _unk _ign _tot; do
      [ ${!v} -eq 0 ] && unset $v
    done

    _stat="${_mod+ M$_mod}${_del+ D$_del}${_add+ A$_add}${_unk+ U$_unk}${_ign+ I$_ign}"
    _prompt+="\nGIT: ${_upstream:-$_branch} ${_status:+[$_status]}${_stat:+ $FRED${_stat## }$RS}"
  fi
fi

  [ -n "${!AWS_*}" ] && _prompt+="\nAWS: $FMAG${AWS_PROFILE:--}/${AWS_DEFAULT_REGION:--}$RS"

  PS1="$PS_PREFIX${_prompt}\n"
  [ $EUID -eq 0 ] && PS1+="${BRED}"

  [ $_rc -ne 0 ] || unset _rc
  PS1+="\!${_rc:+($_rc)} \$${RS} "
}

PS_PREFIX="\n${FCYN}\$USER${RS}@${FGRN}\h ${FYEL}\w${RS}"
PS1="${PS_PREFIX}\n\! \$${RS} "

# put into ROOT's .bashrc
#  PS1="\n${FRED}\u${RS}@${FGRN}\h ${FYEL}\w\n${BRED}\!;\j${RS} \$ "

# other examples
#PS1="\[\e]0;\w\a\]\n\[\e[32m\]\u@\h \[\e[33m\]\w\[\e[0m\]\n\!,\j \$ "
#\[\033[36m\][\t]\[\033[32m\][\u@\h:\[\033[33m\]\w\[\033[32m\]]-> \[\033[0m\]

# Whenever displaying the prompt, write the previous line to disk
#PROMPT_COMMAND="history -a"
PROMPT_COMMAND=__prompt

### Shell Options

# Don't wait for job termination notification
# set -o notify

# Don't use ^D to exit
set -o ignoreeof

# case-insensitive filename globbing, '*' matches all files and zero or more directories
shopt -s nocaseglob globstar

# When changing directory small typos can be ignored by bash
# for example, cd /vr/lgo/apaache would find /var/log/apache
shopt -s cdspell

### History Options
shopt -s histappend

# Don't put duplicate lines in the history.
export HISTCONTROL="erasedups ignorespace"
HISTFILESIZE=300
HISTSIZE=1000
HISTTIMEFORMAT="%H:%M "
# Ignore some controlling instructions
HISTIGNORE="[ \t]*:[bf]g:exit:ls:ll:d[uf]:pwd:history:nslookup:ping:screen"


for f in "$HOME"/.{functions{,.*},bashrc.*,aliases{,.*}}; do
  egrep -q '.swp$|.bak$|~$' <<< "$f" && continue
  [ -f "$f" ] || continue
  source "$f"
done

# save PATH to minimize clutter when adding multiple AWS helpers
_PATH=$PATH

### Completion options
# If this shell is interactive, turn on programmable completion enhancements.
# Any completions you add in ~/.bash_completion are sourced last.
case $- in
  *i*)
        for f in {,/usr/local}/etc/{,profile.d/}bash_completion{.sh,.d/*} ~/.bash_completion; do
          source "$f" 2>/dev/null
        done
	;;
  *c*)  SSH_AGENT=
esac

# vim: set expandtab:ts=4:sw=4
