#!/bin/sh

# This script gets executed in the linux rootfs on the steamlink itself

echo "Resetting crashcounter"
fts-set steamlink.crashcounter 0

echo "Mounting stuff"
cd /mnt/disk
mkdir proc sys dev
mount -t proc proc /mnt/disk/proc
mount -o rbind /sys /mnt/disk/sys
mount -o rbind /dev /mnt/disk/dev

echo "Inserting kexec module into valve kernel"
insmod /mnt/disk/kexec_load.ko

chroot /mnt/disk /kexec -h

echo "Loading pmos kernel"
flavor="valve-steamlink"
chroot /mnt/disk /kexec \
	-l /vmlinuz-${flavor} \
	--initrd /initramfs-${flavor} \
	--dtb /dtb-${flavor}.dtb \
	--command-line "init=/init.sh rw console=tty0 console=ttyS0,115200 no_console_suspend panic=10 consoleblank=0 loglevel=1 PMOS_NO_OUTPUT_REDIRECT"

echo "Rebooting into pmos"
chroot /mnt/disk /kexec -e

echo "If you're reading this then something went wrong"
