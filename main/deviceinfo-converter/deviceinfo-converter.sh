device_codename=$(grep deviceinfo_codename /usr/share/deviceinfo/deviceinfo | cut -d\" -f2)
export DEVICEINFO_DEVICE_NAME=$device_codename
