umask 022

for ed in vim vi nano pico emacs; do
  EDITOR=`which $ed 2>/dev/null`
  [ -n "$EDITOR" ] && { export EDITOR; break; }
done

source "$HOME/.functions"

for d in `\ls -d /usr/local/ec2-api-tools* 2>/dev/null`; do
    [ -z "$d" -o -h "$d" ] && continue
    : ${EC2_HOME:="$d"}
    break
done

export GEM_HOME="${LOCALAPPDATA:-$HOME}/.gem"
export PUPPET_BASE="${PROGRAMFILES:-/opt}/puppetlabs/puppet/bin"
export GOROOT="${PROGRAMFILES:-/opt}/go-${GO_VERSION:-1.9.2}"
export GOPATH="${LOCALAPPDATA:-$HOME}/.go}"

case `uname -o` in
    Cygwin)
	export CYGWIN+=" winsymlinks:native"

	#TODO leading period is not default in Windows
	# WARNING! very crude hack. could result in double escaping
	#PATH="${PATH// /\\ }"

	# setting GEM_HOME will alter INSTALLATION DIRECTORY and EXECUTABLE DIRECTORY.
	# However 'USER INSTALLATION DIRECTORY' will *always* be ~/.gem/ruby/<vers>
	# observe via 'gem env'. Therefore to keep Dropbox from syncing contents
	GEM_HOME=`path2unix "${GEM_HOME}"`
	# ln -s $USERPROFILE/.{gem,bundle,berkshelf}

	PUPPET_BASE=`path2unix "${PUPPET_BASE:-$PROGRAMFILES/Puppet Labs/Puppet/bin}"`
	GOROOT=`path2unix "${GOROOT:-$PROGRAMFILES/go-1.9.2}"`
	GOPATH=`path2unix "${GOPATH:-$LOCALAPPDATA/go}"`

	function command_not_found_handle() { cmd.exe /C "$@" ;}

	#function su() { # sorta works - 'uid' dosn't get updated
	#  eval `awk -v who=$1 -F: '$1 == who { printf("env USER=%s HOME=%s %s --login", who, $(NF-1), $NF) }' /etc/passwd` "$@"
	#}
        ;;
    darwin*)
	HOMEBREW_PREFIX=${HOMEBREW_PREFIX:-`brew --prefix`}
	PATH+="${HOMEBREW_PREFIX:+:$HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin}"
	MANPATH="${HOMEBREW_PREFIX:+:$HOMEBREW_PREFIX/opt/coreutils/libexec/gnuman}"
	JAVA_HOME=`/usr/libexec/java_home 2>/dev/null`	# -v '1.8*'`"
        ;;
esac

addPath "-$HOME/bin"
export PATH MANPATH

for v in {JAVA,EC2,GEM}_HOME; do
    [ -n "${!v}" ] && { export $v; addPath "${!v}/bin"; } || unset $v
done

: ${SSH_AGENT=`which ssh-agent 2>/dev/null`}
if [ -z "$SSH_AUTH_SOCK" -a -n "$SSH_AGENT" ]; then
    eval `$SSH_AGENT ${SSH_AGENT_ARGS:-${BASH_VERSION:+-s}}`
    trap "kill $SSH_AGENT_PID" 0
    /usr/bin/ssh-add
    alias ssh='ssh -A'
fi

for f in .bash_profile.local .bashrc; do
    [ -f "$HOME/$f" ] && source "$HOME/$f" || true
done
