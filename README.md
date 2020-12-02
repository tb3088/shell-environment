# Introduction
This is intended to be checked out into your HOME directory. Typically that is not empty so
a simple `git clone` will not work. The following sequence is best way forward.

1. git init
1. git remote add origin [URL]
1. git fetch; git checkout master
1. git submodule update --init --recursive

## Integration
Dropbox and environment-specific hooks (eg. Windows/Cygwin) can be helpful.
```bash
ln -s "$USERPROFILE" .USERPROFILE
ln -s .USERPROFILE/Dropbox
ln -s Dropbox/Work_Projects/XXX .WPHOME
ln -s .WPHOME/.aws
ln -s .WPHOME/.ssh
ln -s .WPHOME/.*.local .
ln -s .WPHOME/.gitconfig

mkdir "$LOCALAPPDATA/workspace"
ln -s "$LOCALAPPDATA/workspace"
```

## Environment Variables
`GIT_PROMPT=1` adds current repo state. `AWS_*` are displayed if set.

# Suggested Packages and Dependencies
* Bash Autocomplete
* Vim
* Python3, Pip
* [AWS Cli](https://docs.aws.amazon.com/cli/latest/userguide/installing.html)
* [AMI tools](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/set-up-ami-tools.html)
* [Elastic Beanstalk CLI](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/eb-cli3-install.html)

# Windows Subsystem for Linux
/etc/wsl.conf
```
[automount]
enabled = true
options = "metadata,umask=22,fmask=11"

[interop]
enabled = false
appendWindowsPath = false
```
