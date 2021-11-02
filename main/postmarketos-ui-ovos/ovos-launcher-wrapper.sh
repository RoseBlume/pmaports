#!/bin/sh

export QT_QPA_PLATFORM=eglfs
export QT_QPA_EGLFS_KMS_ATOMIC=1
export QT_QPA_PLATFORMTHEME=qt5ct
export QT_FILE_SELECTORS=ovos
export QT_FONT_DPI=120
export XDG_CURRENT_DESKTOP=kde

/usr/bin/mycroft-embedded-shell --maximize
