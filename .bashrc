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

PS1="\n${FCYN}\u${RS}@${FGRN}\h ${FYEL}\w${RS}\n\!.\j \$ "
#if [[ ${EUID} == 0 ]]; 
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


### Completion options
# If this shell is interactive, turn on programmable completion enhancements.
# Any completions you add in ~/.bash_completion are sourced last.
case $- in
    *i*)
	. {,/usr/local}/etc/bash_completion 2>/dev/null
	. {,/usr/local}/etc/bash_completion.d/* 2>/dev/null
	. ~/.bash_completion 2>/dev/null
	;;
    *c*)
	SSH_AGENT=""
esac


### History Options
shopt -s histappend

# Don't put duplicate lines in the history.
export HISTCONTROL="erasedups ignorespace"

HISTFILESIZE=500
HISTSIZE=300
HISTTIMEFORMAT="%H:%M "

# Ignore some controlling instructions
HISTIGNORE="[ \t]*:[bf]g:exit:ls:ll:d[uf]:pwd:history:nslookup:ping:screen"

for f in .{functions,aliases}{,.local}; do
    [ -f "$HOME/$f" ] && source "$HOME/$f"
    [ -n "$USERPROFILE" ] && {
	f=`cygpath "$USERPROFILE"`/$f
	[ -f "$f" ] && source "$f"
    }
done

