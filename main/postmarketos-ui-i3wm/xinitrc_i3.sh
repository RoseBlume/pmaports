#!/bin/sh

# Set XDG_RUNTIME_DIR as per https://wiki.alpinelinux.org/wiki/Wayland
if test -z "${XDG_RUNTIME_DIR}"; then
	XDG_RUNTIME_DIR=/tmp/$(id -u)-runtime-dir
	export XDG_RUNTIME_DIR
	if ! test -d "${XDG_RUNTIME_DIR}"; then
		mkdir "${XDG_RUNTIME_DIR}"
		chmod 0700 "${XDG_RUNTIME_DIR}"
	fi
fi

# Start dbus and export its environment variables
eval "$(dbus-launch --sh-syntax --exit-with-session)"

exec i3
