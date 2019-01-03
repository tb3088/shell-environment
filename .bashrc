# To pick up the latest recommended .bashrc content,
# look in /etc/defaults/etc/skel/.bashrc

ulimit -S -c 0 -u 80

${ABORT:+ set -eE}
${CONTINUE:+ set +e}

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
            sub(/\(no branch\)/, "")
            for (i=2; i<NF; i++)
                if ($i ~ /[[:alnum:]].*\.{3,}[[:alnum:]].*/)
                    break

            gsub(/[\[\],]/, "", $(i+1))
            printf "_branch='%s' _status='%s' _delta=%d ", $i, $(i+1), $(i+2)
            next
        }
        $1 ~ /M/ { mod++; } 
        $1 ~ /D/ { del++; } 
        $1 ~ /A/ { add++; }
        $1 ~ /\?/ { unk++; }
        $1 ~ /\!/ { ign++; }
        END { printf "_mod=%d _del=%d _add=%d _unk=%d _ign=%d _tot=%d", mod, del, add, unk, ign, NR-1; }
    ' < <(git --no-pager --no-optional-locks status --untracked-files=all \
            --ignore-submodules --porcelain --branch 2>/dev/null)
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
    _prompt+="
  ${UL}Git:$RS ${HC}${_upstream:-$_branch}$RS ${_status:+$_status} ${_stat:+${FRED}${_stat[@]}$RS}"
  fi
fi

  if [ -n "${AWS_PROFILE}${AWS_CONFIG_FILE}${AWS_DEFAULT_REGION}" ]; then
    local _config
    _config=${AWS_CONFIG_FILE#$HOME/}; _config=${_config%/*}; _config=${_config#.aws/}
    _prompt+="
  ${UL}AWS:$RS ${FMAG}${_config:+$_config:}${HC}${AWS_PROFILE:---}$RS / ${FBLE}${HC}${AWS_DEFAULT_REGION:---}$RS"
  fi

  #TODO use array with IFS
  PS1="\n${PS_PREFIX}${_prompt}\n"
  [ $EUID -eq 0 ] && PS1+="${BRED}"
  [ $_rc -eq 0 ] && unset _rc
  PS1+="\!${_rc:+($_rc)}$RS ${PS_SCREEN}\$ "
}

PS_SCREEN='\[\033k\033\\\]'
PS_PREFIX="${FCYN}\$USER${RS}@${FGRN}\h ${FYEL}\w${RS}"
PS1="\n${PS_PREFIX}\n\! ${PS_SCREEN}\$ "

# Examples:
# for ROOT
#  PS1="\n${FRED}\u${RS}@${FGRN}\h ${FYEL}\w\n${BRED}\!;\j${RS} \$ "
#
#PS1="\[\e]0;\w\a\]\n\[\e[32m\]\u@\h \[\e[33m\]\w\[\e[0m\]\n\!,\j \$ "
#\[\033[36m\][\t]\[\033[32m\][\u@\h:\[\033[33m\]\w\[\033[32m\]]-> \[\033[0m\]
#
# Whenever displaying the prompt, write the previous line to disk
#PROMPT_COMMAND="history -a"
declare -F __prompt &>/dev/null && PROMPT_COMMAND=__prompt


# Don't wait for job termination notification
# set -o notify

# Don't use ^D to exit
set -o ignoreeof checkjobs

# use VI mode on command-line (else emacs)
# http://www.catonmat.net/download/bash-vi-editing-mode-cheat-sheet.txt
set -o vi

# case-insensitive filename globbing, '*' matches all files and zero or more directories
shopt -s nocaseglob globstar extglob

# nullglob=off preserves '*' even if no files present. During interactive 
# this is rather silly but it appears that compgen (aka autocomplete) on Ubuntu(?)
# stops working if set.
shopt -u nullglob failglob

# When changing directory small typos can be ignored by bash
# for example, cd /vr/lgo/apaache would find /var/log/apache
shopt -s cdspell autocd

# History Options
shopt -s histappend histreedit no_empty_cmd_completion

HISTCONTROL="erasedups ignorespace"
HISTFILESIZE=100
HISTSIZE=500
HISTTIMEFORMAT="%H:%M "
# Ignore some controlling instructions
HISTIGNORE="[ \t]*:[bf]g:exit:ls:ll:d[uf]:pwd:history:nslookup:ping:screen"

# don't search PATH for target of 'source'
shopt -u sourcepath

for f in "$HOME"/.functions{,_${OSTYPE:-`uname`},.local}; do
  [ -f "$f" ] || continue
  source "$f" || echo >&2 "RC=$? in $f"
done
unset f

for f in "$HOME"/.{aliases{,.local},bashrc{.local,_*},dircolors}; do
  egrep -q '.swp$|.bak$|~$' <<< "$f" && continue
  [ -f "$f" ] || continue
  source "$f" || echo >&2 "RC=$? in $f"
done
unset f

addPath PATH -"$HOME"/{,.local/}bin

# Base16 color themes
if COLORSCHEME=`readlink -e "$HOME/.colorscheme"`; then
  source "$COLORSCHEME" || echo >&2 "RC=$? in $COLORSCHEME"
  COLORSCHEME=`basename $COLORSCHEME .sh`
fi

### Completion options
# If this shell is interactive, turn on programmable completion enhancements.
# Any completions you add in ~/.bash_completion are sourced last.
case $- in
  *i*)  for f in {,/usr/local}/etc/{,profile.d/}bash_completion{.sh,.d/*} "$HOME"/.bash_completion; do
          [ -f "$f" ] || continue
          source "$f" || echo >&2 "RC=$? in $f"
        done
        unset f
        ;;
  *c*)  SSH_AGENT=
esac

# vim: expandtab:ts=4:sw=4
