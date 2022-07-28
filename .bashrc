# To pick up the latest recommended .bashrc content,
# look in /etc/defaults/etc/skel/.bashrc

# Disable core files
ulimit -S -c 0

${ABORT:+ set -eE}
${CONTINUE:+ set +e}

# don't search PATH for target of 'source'
shopt -u sourcepath

#---------------
shopt -s nullglob

for f in "$HOME"/.functions{,.local,_logging}; do
  [ -f "$f" ] || continue
  source "$f" || { >&2 echo -e "ERROR\tRC=$? during $f\n"; return; }
done

for f in "$HOME"/{.bashrc{.local,_{prompt,os,*}},.aliases{,.local},.dircolors}; do
  \egrep -q '.swp$|.bak$|~$' <<< "$f" && continue
  [ -f "$f" ] || continue
  source "$f" || { log.error "RC=$? during $f"; return; }
done

addPath -"$HOME"/{,.local/}bin

# programmable completion enhancements
# Any completions you add in ~/.bash_completion are sourced last.
case $- in
  *i*)  for f in {,/usr/local}/etc/{,profile.d/}bash_completion{,.sh,.d/*} "$HOME"/.bash_completion{,.d/*}; do
          [ -f "$f" ] || continue
          source "$f" || log.error "RC=$? during $f"
        done
        ;;
  *c*)  SSH_AGENT=
esac
unset f

#---------------

# Get immediate notification of background job termination
# set -o notify

# Disable [CTRL-D] to exit the shell
set -o ignoreeof checkjobs

# use VI mode on command-line (else emacs)
# http://www.catonmat.net/download/bash-vi-editing-mode-cheat-sheet.txt
#set -o vi

# ref: https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html
shopt -s globstar extglob dotglob

# ref: http://mywiki.wooledge.org/glob#nullglob
# nullglob=off returns glob-spec despite no match, which (if failglob=off too) can be
# useful for passing thru to '/bin/ls' etc without SHELL preemption.
#
#   nullglob=off + failglob=?   (interactive)
#   nullglob=on + failglob=off  (scripts)
shopt -u nullglob

# compgen (aka autocomplete) on Ubuntu(WSL, but not Cygwin) used to fail
# TAB-completion if nullglob=on. (Jan 2021: this may be fixed)
#[[ `uname -r` =~ microsoft ]] && shopt -u nullglob

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


# vim: expandtab:ts=4:sw=4
