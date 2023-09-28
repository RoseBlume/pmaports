#!/bin/sh

set -x
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
[ -f "$XDG_CONFIG_HOME"/i3lockscreen.conf ] && . "$XDG_CONFIG_HOME"/i3lockscreen.conf

# TODO: change default theme?
# TODO: could also source config from /etc for distro defaults
export XSECURELOCK_AUTH_TIMEOUT="${XSECURELOCK_AUTH_TIMEOUT:-10}"
export XSECURELOCK_BLANK_TIMEOUT="${XSECURELOCK_BLANK_TIMEOUT:-0}"
export XSECURELOCK_BLANK_DPMS_STATE="${XSECURELOCK_BLANK_DPMS_STATE:-on}"
export XSECURELOCK_SHOW_HOSTNAME="${XSECURELOCK_SHOW_HOSTNAME:-0}"
export XSECURELOCK_SHOW_USERNAME="${XSECURELOCK_SHOW_USERNAME:-0}"
export XSECURELOCK_SHOW_KEYBOARD_LAYOUT="${XSECURELOCK_SHOW_KEYBOARD_LAYOUT:-0}"
export XSECURELOCK_PASSWORD_PROMPT="${XSECURELOCK_PASSWORD_PROMPT:-kaomoji}"

display=off
if xset q | grep -iq "monitor is on"; then
        display=on
fi

case "$display" in
        off)
                # Re-enable display, just in case...
                xset dpms force on
                xinput enable "TSC2005 touchscreen"
                ;;
        on)
                xinput disable "TSC2005 touchscreen"
                if ! pidof xsecurelock >/dev/null; then
                        xsecurelock
                        # Re-enable touchscreen, just in case...
                        xinput enable "TSC2005 touchscreen"
                fi
                ;;
esac
