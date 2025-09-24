# Introduction
This file is intended to be checked out into your HOME directory. Typically that is not empty
so a simple `git clone` will not work. The following sequence is best way forward:

1. git init
1. git remote add origin [REPO](https://github.com/tb3088/shell-environment.git)
1. git fetch; git checkout master
1. git submodule update --init --recursive

Cygwin 'git' may complain about some of the submodules so add `ignore = all` to .gitmodules as needed.

## Integrations
Dropbox and environment-specific hooks (eg. Windows/Cygwin) can be helpful.
Suggest using `mklink` on certain shared paths helps to ensure maximum compatability.

### Tie Windows into Cygwin
While within Cygwin `/home` is intuitive, but feeding a path element to CMD.exe
(without calling `cygpath [-w|m]` which always fully qualifies) needs a symlink to avoid silly errors.
```
#file: /etc/fstab

none    /tmp    usertemp binary,posix=0 0 0
C:/Users /home  none    binary          0 0
```
let Windows tools understand /cygdrive/ via CMD.exe
```shell
mklink /D home C:\Users

mkdir C:\cygdrive; cd C:\cygdrive
mklink /D c C:\
```

### Tie in Window to WSL
```bash
ln -s /mnt/c/Users/$USER .USERPROFILE
ln -s .USERPROFILE/Dropbox
```

### HOMEDIR sym-links
*Git-Bash (MINGW) doesn't support symlinks at all!*

While it's tempting to not set the `CYGWIN=` environment variable, and thereby leverage the new WSL-compatible reparse-points, Win10+ doesn't properly render or follow them. This is particularly annoying with Windows/DOS-native binaries (eg. AWS CLI, Python|Ruby|Go|Puppet runtimes) or Explorer. My environment overrides the `ln` command with a function of the same name to transparently invoke `mklink` when in Cygwin.  [reference](https://cygwin.com/faq/faq.html#faq.api.symlinks)

```bash
# file:.bashrc_os.cygwin|msys
CYGWIN|MSYS='winsymlinks:nativestrict'
```

```shell
mklink /D home [C:]\Users

mklink /D .WPHOME Dropbox/Work_Projects/XXX
mklink .gitidentity .WPHOME/.gitidentity
mklink /D .aws .WPHOME/.aws
mklink /D .ssh .WPHOME/.ssh
mkdir -p "$LOCALAPPDATA/workspace"
mklink /D workspace AppData/Local/workspace"	# WSL: .USERPROFILE/...

ln -st . .WPHOME/.*.local
```

*(Deprecated)* It used to be that symlinks required advanced Windows rights. Thankfully, M$ finally got a clue. Otherwise, launch `gpedit.msc` and navigate to
`Computer Configuration -> Windows Settings -> Security Settings -> Local Policies -> User Rights Assignment`

## Environment Variables
`GIT_PROMPT=1` turns on a status bar showing current repo state, while `AWS_*` variables are automatically displayed on another line.

## Suggested Packages and Dependencies
* Bash Autocomplete
* Vim
* Python3, Pip3
* pip3 install [--user] wheel, yamllint, demjson3 (nee jsonlint)
* [AWS Cli](https://docs.aws.amazon.com/cli/latest/userguide/installing.html)
* [AMI tools](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/set-up-ami-tools.html)
* [Elastic Beanstalk CLI](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/eb-cli3-install.html)

# Windows Subsystem for Linux
Integration with Windows OS can be trickly and can have unfortunate side-effects like preferring DOS/WIN commands over Linux. The `mask` directives rationalize how directory listings appear as WSL interprets NTFS security markings.

```
# file:/etc/wsl.conf

[automount]
enabled=true
options="metadata,umask=027"

[interop]
enabled=false
appendWindowsPath=false

[boot]
command=chmod a+w,o+t /run;/etc/rc.local;/etc/init.d/<service>; ...
```
It takes >8 seconds after exiting all WSL instances for the daemon to reload. Use `wsl --shutdown` to force the issue.
