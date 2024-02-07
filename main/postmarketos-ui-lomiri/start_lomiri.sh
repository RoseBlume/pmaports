#!/bin/sh

export MIR_SERVER_CURSOR=null
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1

export QT_IM_MODULE=maliit
export MALIIT_FORCE_DBUS_CONNECTION=1
export UITK_ICON_THEME=suru

dbus-update-activation-environment MALIIT_FORCE_DBUS_CONNECTION=1

# Device-specific adjustments
. /usr/share/misc/source_deviceinfo
if [ "$deviceinfo_codename" = "qemu-amd64" ]; then
	export MIR_MESA_KMS_DISABLE_MODESET_PROBE=1
elif [ "$deviceinfo_codename" = "pine64-pinephone" ]; then
	export MIR_MESA_KMS_USE_DRM_DEVICE=card1
fi

superd &

lomiri
