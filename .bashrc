# To pick up the latest recommended .bashrc content,
# look in /etc/defaults/etc/skel/.bashrc

source /etc/bash.bashrc

# only CYGWIN system files omit PATH to self unless '--login' (/etc/profile)
if [[ "${OSTYPE}" =~ [cC]ygwin|[mM]sys ]]; then
  [[ "$PATH" == */usr/bin* ]] || PATH=/usr/local/bin:/usr/bin:$PATH
fi

export LANG=$(locale -uU)        # 'en_US.utf8'

# Disable core files
ulimit -S -c 0

${ABORT:+set -eE}
${CONTINUE:+set +e}

for dir in "$HOME"/{,.local/}bin; do
  [ -d "$dir" ] && PATH="${dir}:$PATH"
done

shopt -u sourcepath
shopt -s nullglob

#FIXME deliberate typo to exclude logging
#TODO short-cut when invoked by screen? use SHLVL>1 or check BASH_SOURCE[1]?
case $- in
  *i*)  for f in "$HOME"/{.functions{,.local,_loging},.bashrc{.local,_{os,3rdparty,*}},.aliases{,.local}}; do
          [ -s "$f" ] || continue
          # bypass backup file suffixes
          grep -qE '\.(swp|bak)|~)$' - -- <<< "$f" && continue
          source "$f" || { >&2 echo -e "ERROR\tRC=$? during $f"; break; }
        done

        # only supports a single file arg, so combine with `cat`
        eval "$( dircolors -b - < <( cat "$HOME"/.dir{,_}colors{,.local} 2>/dev/null ))" || true
        : ${EDITOR:=`type -p vim vi nano pico emacs | head -n 1`}
        : ${PAGER:='less -RF'}
        export EDITOR PAGER

        # ref: https://www.gnu.org/software/bash/manual/html_node/The-Shopt-Builtin.html
        shopt -s globstar dotglob

        #WARN nullglob=on, failglob=off has DANGEROUS side-effects!
        shopt -s failglob

        # Get immediate notification of background job termination
        set -o notify

        # Disable [CTRL-D] to exit the shell
        set -o ignoreeof checkjobs

        # When changing directory small typos can be ignored by bash
        # for example, cd /vr/lgo/apaache would find /var/log/apache
        shopt -s cdspell autocd

        # History Options
        shopt -s histappend histreedit no_empty_cmd_completion

#        NOTE unnecessary when bash-completion package is installed *properly* !!
#        for f in {{,/usr/local}/etc/,"$HOME"/.}bash_completion{.sh,.d/*}; do
#          [ -s "$f" ] || continue
#          source "$f" || log.error "RC=$? during $f"
#        done

        # use VI mode on command-line (else emacs)
        #ref: http://www.catonmat.net/download/bash-vi-editing-mode-cheat-sheet.txt
        #set -o vi

        cd "$HOME"
        ;;

# still have to invoke as `bash -c "source ~/.bashrc; ..."`
  *c*)  source ~/.functions
esac

HISTCONTROL="erasedups ignorespace"
HISTFILESIZE=100
HISTSIZE=500
HISTTIMEFORMAT="%H:%M "
# Ignore some controlling instructions
HISTIGNORE="[ \t]*:[bf]g:exit:ls:ll:d[uf]:pwd:history:nslookup:ping:screen"


# vim: expandtab:ts=4:sw=4
