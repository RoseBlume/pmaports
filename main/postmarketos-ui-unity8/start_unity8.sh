if test -z "${XDG_RUNTIME_DIR}"; then
	export XDG_RUNTIME_DIR=/tmp/$(id -u)-runtime-dir
	if ! test -d "${XDG_RUNTIME_DIR}"; then
		mkdir "${XDG_RUNTIME_DIR}"
		chmod 0700 "${XDG_RUNTIME_DIR}"
	fi

	if [ $(tty) = "/dev/tty1" ]; then
#		udevadm trigger
#		udevadm settle

		# Wizard is broken
		mkdir -p $HOME/.config/ubuntu-system-settings
		touch $HOME/.config/ubuntu-system-settings/wizard-has-run

		export LD_LIBRARY_PATH=/usr/lib/qt5/plugins/platforms
		export MIR_SERVER_CURSOR=null
		export QT_QPA_PLATFORM=mirserver
		export G_MESSAGES_DEBUG=all

#		sleep 2

		ck-launch-session unity8 2>&1 | logger -t "$(whoami):unity8"
	fi
fi
