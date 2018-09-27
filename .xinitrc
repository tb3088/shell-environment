# make life easy for WSL. otherwise symlink WSL' ~/.Xauthority to Cygwin's
xhost +localhost

xrdb -merge ~/.Xresources
xterm -geometry 80x25-30+0 -name login &

declare -a list=()
for wm in {open,flux}box {fv,t}wm; do
  which $wm &>/dev/null && list+=($wm)
done

# unfortunately 'xinit' is not Interactive
#
#PS3='Pick a Window Manager: '
#select wm in "${list[@]}"; do
#  [ -n "$REPLY" ] || REPLY="${list[0]}"
#  exec $REPLY
#done

exec ${WM:-$list}
