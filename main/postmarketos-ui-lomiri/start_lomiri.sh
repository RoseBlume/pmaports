#!/bin/bash

export LD_LIBRARY_PATH=/usr/lib/qt5/plugins/platforms
export MIR_SERVER_CURSOR=null
export QT_QPA_PLATFORM=mirserver
#export G_MESSAGES_DEBUG=all
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export MIR_MESA_KMS_DISABLE_MODESET_PROBE=1 # probably only needed in QEMU
export MIR_SERVER_ENABLE_MIRCLIENT=1

lomiri
