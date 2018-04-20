xhost +localhost

xterm -geometry 80x24-30+0 -name login -rv

#exec ${WM:-xfce4-session} || {
#  xterm -geometry 80x24+0+0 -name login -rv &
#  for wm in xfwm4 fvwm twm; do
##    [ -n "`which $wm 2>/dev/null`" ] && break;
#  done
#  exec $wm
#}
