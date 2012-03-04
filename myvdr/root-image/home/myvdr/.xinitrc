#!/bin/sh
#
# ~/.xinitrc
#
# Executed by startx (run your window manager from here)

# exec gnome-session
# exec startkde
# exec startxfce4
# ...or the Window Manager of your choice

export DISPLAY=:0

setxkbmap de
xrdb ${HOME}/.Xdefaults

screen -d -m -c ${HOME}/.screenrc-xinit
exec ck-launch-session compiz --replace --sm-disable --ignore-desktop-hints ccp
#exec ck-launch-session xfwm4 --replace --compositor=on
