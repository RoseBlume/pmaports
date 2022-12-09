#!/bin/sh
# this instructs gnome-session to load user-specified autostart apps from a
# different directory than the default (/etc/xdg/autostart). Apps that are
# required by gnome-session (e.g. things like gsd-sound, etc) are still started
# even when this is set. By pointing it here, it'll start superd, which can
# then start/supervise everything not requried by gnome-session.
export GNOME_SESSION_AUTOSTART_DIR="/usr/share/superd/"
