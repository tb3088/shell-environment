# To pick up the latest recommended .bashrc content,
# look in /etc/defaults/etc/skel/.bashrc

# Disable core files
ulimit -S -c 0

${ABORT:+set -eE}
${CONTINUE:+set +e}

# ref: https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html
# don't search PATH for target of 'source'
shopt -u sourcepath
shopt -s nullglob

#---------------

#for f in "$HOME"/.functions{,.local,_logging}; do
for f in "$HOME"/.functions; do
  [ -s "$f" ] || continue
  source "$f" || { >&2 echo -e "ERROR\tRC=$? during $f"; return 1; }
done

addPath -P -k PATH "$HOME"/{,.local/}bin

case $- in
  # a bit redundant since whole point of .bashrc is 'interactive' use...
  *i*)  for f in "$HOME"/{.bashrc{.local,_{os,3rdparty,*}},.aliases{,.local}}; do
          [ -s "$f" ] || continue
          grep -qE '\.swp$|\.bak$|~$' - -- <<< "$f" && continue

          source "$f" || { log.error "RC=$? during $f, aborting."; pause; return 1; }
        done

        eval "`dircolors -b - < <( cat .dir{,_}colors{,.local} 2>/dev/null )`" || true
        : ${EDITOR:=`type -p vim vi nano pico emacs | head -n 1`}
        : ${PAGER:='less -RF'}
        export EDITOR PAGER

		shopt -s globstar dotglob

        # Get immediate notification of background job termination
        set -o notify

        # Disable [CTRL-D] to exit the shell
        set -o ignoreeof checkjobs

        # When changing directory small typos can be ignored by bash
        # for example, cd /vr/lgo/apaache would find /var/log/apache
        shopt -s cdspell autocd

        # History Options
        shopt -s histappend histreedit no_empty_cmd_completion

#DEPRECATED when bash-completion package is installed *properly* !!
# (opt) populate ${BASH_COMPLETION_USER_FILE=~/.bash_completion} with directives
#
#        for f in {{,/usr/local}/etc/,"$HOME"/.}bash_completion{.sh,.d/*}; do
#          [ -s "$f" ] || continue
#          source "$f" || log.error "RC=$? during $f"
#        done

        # use VI mode on command-line (else emacs)
        #ref: http://www.catonmat.net/download/bash-vi-editing-mode-cheat-sheet.txt
        #set -o vi
        ;;
  *c*)  SSH_AGENT=
esac
#---------------

HISTCONTROL="erasedups ignorespace"
HISTFILESIZE=100
HISTSIZE=500
HISTTIMEFORMAT="%H:%M "
# Ignore some controlling instructions
HISTIGNORE="[ \t]*:[bf]g:exit:ls:ll:d[uf]:pwd:history:nslookup:ping:screen"

#WARN! nullglob=on, failglob=off has DANGEROUS side-effects!
shopt -s failglob
shopt -u nullglob


# vim: expandtab:ts=4:sw=4
