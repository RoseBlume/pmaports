#!/bin/sh

echo "Remounting /sysroot RW"
mount -o remount,rw /sysroot
echo "Installing kernel modules to sysroot"
cp -af /lib/modules/* /sysroot/lib/modules/
echo "All done!"
mount -o remount,ro /sysroot
