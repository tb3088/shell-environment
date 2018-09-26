# make life easy for WSL. otherwise symlink WSL' ~/.Xauthority to Cygwin's
xhost +localhost

xterm -geometry -30+0 -name login -rv &

for wm in openbox fvwm twm; do
  which $wm &>/dev/null && exec $wm
done

