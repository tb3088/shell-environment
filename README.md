# Introduction
This is intended to be checked out into your HOME directory. Typically that is not empty so
a simple `git clone` will not work. The following sequence is best way forward.

1. git init
1. git remote add origin [REPO](https://github.com/tb3088/shell-environment.git)
1. git fetch; git checkout master
1. git submodule update --init --recursive

Cygwin 'git' may complain about some of the submodules so add `ignore = all` to .gitmodules as needed.

## Integration
Dropbox and environment-specific hooks (eg. Windows/Cygwin) can be helpful.

### Tie in Windows to Cygwin
```
#/etc/fstab
C:/Users /home none binary 0 0
```

### Tie in Window to WSL
```
ln -s /mnt/c/Users/$USER .USERPROFILE
ln -s .USERPROFILE/Dropbox
```
### HOMEDIR sym-links
Git-Bash (MINGW) and Cygwin need `SeCreateSymbolicLink` rights to create NTFS-native links
(`winsymlinks:native[strict]`). Launch `gpedit.msc` and navigate to
`Computer Configuration -> Windows Settings -> Security Settings -> Local Policies -> User Rights Assignment`
However it is better to use the simple directive, or not set anything and leverage the new
WSL-compatible reparse-points.  [reference](https://cygwin.com/faq/faq.html#faq.api.symlinks)

```bash
# .bashrc_os.XXX
CYGWIN|MSYS='winsymlinks[:lnk]'
```

```
ln -s Dropbox/Work_Projects/XXX .WPHOME
ln -s .WPHOME/.gitidentity
mkdir "$LOCALAPPDATA/workspace"	    # Cygwin
ln -s "$LOCALAPPDATA/workspace"	    # WSL: .USERPROFILE/AppData/Local/workspace

ln -s .WPHOME/.*.local .
ln -s .WPHOME/.aws
ln -s .WPHOME/.ssh
```

## Environment Variables
`GIT_PROMPT=1` shows current repo state. `AWS_*` are automatically displayed.

# Suggested Packages and Dependencies
* Bash Autocomplete
* Vim
* Python3, Pip
* [AWS Cli](https://docs.aws.amazon.com/cli/latest/userguide/installing.html)
* [AMI tools](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/set-up-ami-tools.html)
* [Elastic Beanstalk CLI](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/eb-cli3-install.html)

# Windows Subsystem for Linux
Integration with Windows OS can be trickly and can have unfortunate side-effects like 
preferring DOS/WIN commands over Linux. The `mask` directives rationalize how directory
listings appear as WSL interprets NTFS security markings.

/etc/wsl.conf
```
[automount]
enabled=true
options="metadata,umask=22,fmask=11"

[interop]
enabled=false
appendWindowsPath=false

[boot]
command=chmod a+w,o+t /run;/etc/rc.local;/etc/init.d/<service>; ...
```
may need `wsl --shutdown` to activate changes
