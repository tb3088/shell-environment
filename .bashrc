# To pick up the latest recommended .bashrc content,
# look in /etc/defaults/etc/skel/.bashrc

# Disable core files
ulimit -S -c 0

${ABORT:+ set -eE}
${CONTINUE:+ set +e}

# Get immediate notification of background job termination
# set -o notify

# Disable [CTRL-D] to exit the shell
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
  *i*)  for f in {,/usr/local}/etc/{,profile.d/}bash_completion{.sh,.d/*} "$HOME"/.bash_completion{,.d/*}; do
          [ -f "$f" ] || continue
          source "$f" || echo >&2 "RC=$? in $f"
        done
        unset f
        ;;
  *c*)  SSH_AGENT=
esac

# vim: expandtab:ts=4:sw=4
