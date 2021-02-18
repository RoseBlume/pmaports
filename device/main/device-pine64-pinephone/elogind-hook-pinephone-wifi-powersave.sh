#!/bin/sh
wlan_device="wlan0"
bat_dev="/sys/class/power_supply/axp20x-battery"

case $1/$2 in
	pre/*)
		# enable wifi power save to reduce power in suspend
		iw dev "$wlan_device" set power_save on
		sleep 1
		;;
	post/*)
		# briefly disable power save when resuming to allow for faster
		# reconnect
		iw dev "$wlan_device" set power_save off
		# re-enable power save when on battery
		if [ "Discharging" = "$(cat "$bat_dev"/status)" ]; then
			sleep 30
			iw dev "$wlan_device" set power_save on
		fi
		;;
esac
