#!/bin/sh

for i in "$@"; do
	# get last element in path
	flavor=${i##*/}
	if ! [ -f "$i"/kernel.release ]; then
		# kernel was uninstalled
		rm -f $( readlink -f /boot/initramfs-$flavor ) \
			/boot/initramfs-$flavor /boot/vmlinuz-$flavor \
			/boot/$flavor /boot/$flavor.gz /$flavor /$flavor.gz
		continue
	fi
	abi_release=$(cat "$i"/kernel.release)
	initfs=initramfs-$flavor
	mkinitfs -o /boot/$initfs $abi_release
done

# cleanup unused initramfs
for i in /boot/initramfs-[0-9]*; do
	[ -f $i ] || continue
	if ! [ -f /boot/vmlinuz-${i#/boot/initramfs-} ]; then
		rm "$i"
	fi
done

sync
exit 0
