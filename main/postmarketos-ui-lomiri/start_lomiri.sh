#!/bin/sh

export MIR_SERVER_CURSOR=null
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export MIR_SERVER_ENABLE_MIRCLIENT=1

export QT_IM_MODULE=maliit
export MALIIT_FORCE_DBUS_CONNECTION=1
export UITK_ICON_THEME=suru # ?

#export QT_SCALE_FACTOR=2 # pinephone

# Device-specific adjustments
device_codename="$(grep deviceinfo_codename /etc/deviceinfo | cut -d\" -f2)"
if [ "$device_codename" = "qemu-amd64" ]; then
	export MIR_MESA_KMS_DISABLE_MODESET_PROBE=1
elif [ "$device_codename" = "pine64-pinephone" ]; then
	export MIR_MESA_KMS_USE_DRM_DEVICE=card1
fi

#export G_MESSAGES_DEBUG=all

superd &

lomiri
