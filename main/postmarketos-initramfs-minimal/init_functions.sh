#!/bin/sh
# This file will be in /init_functions.sh inside the initramfs.
ROOT_PARTITION_UNLOCKED=0
ROOT_PARTITION_RESIZED=0
PMOS_BOOT=""
PMOS_ROOT=""

# Redirect stdout and stderr to logfile
setup_log() {
	local log_to_console=""

	grep -q pmos.debug-shell /proc/cmdline && log_to_console="true"

	echo "### postmarketOS initramfs ###"

	if [ -z "$log_to_console" ]; then
		echo "Add pmos.debug-shell to your kernel command line"
		echo "to enable initramfs logging to console (e.g. for serial)."
	fi

	# Start redirect
	exec >/pmOS_init.log 2>&1
	echo "### postmarketOS initramfs ###"

	# Pipe logs to console if pmos.debug-shell is set
	if [ -n "$log_to_console" ]; then
		tail -f /pmOS_init.log > /dev/console &
	fi

	# Pipe logs to pmsg if pmos.debug-shell is set and /dev/pmsg0 is available
	if [ -n "$log_to_console" ] && [ -e "/dev/pmsg0" ]; then
		tail -f /pmOS_init.log > /dev/pmsg0 &
	fi
}

mount_proc_sys_dev() {
	# mdev
	mount -t proc -o nodev,noexec,nosuid proc /proc || echo "Couldn't mount /proc"
	mount -t sysfs -o nodev,noexec,nosuid sysfs /sys || echo "Couldn't mount /sys"
	mount -t devtmpfs -o mode=0755,nosuid dev /dev || echo "Couldn't mount /dev"
	mount -t tmpfs -o nosuid,nodev,mode=0755 run /run || echo "Couldn't mount /run"

	mkdir /config
	mount -t configfs -o nodev,noexec,nosuid configfs /config

	# /dev/pts (needed for telnet)
	mkdir -p /dev/pts
	mount -t devpts devpts /dev/pts
}

setup_firmware_path() {
	# Add the postmarketOS-specific path to the firmware search paths.
	# This should be sufficient on kernel 3.10+, before that we need
	# the kernel calling udev (and in our case /usr/lib/firmwareload.sh)
	# to load the firmware for the kernel.
	echo "Configuring kernel firmware image search path"
	SYS=/sys/module/firmware_class/parameters/path
	if ! [ -e "$SYS" ]; then
		echo "Kernel does not support setting the firmware image search path. Skipping."
		return
	fi
	# shellcheck disable=SC3037
	echo -n /lib/firmware/postmarketos >$SYS
}

# shellcheck disable=SC3043
load_modules() {
	local file="$1"
	local modules="$2"
	[ -f "$file" ] && modules="$modules $(grep -v ^\# "$file")"
	# shellcheck disable=SC2086
	modprobe -a $modules
}

setup_mdev() {
	# Start mdev daemon
	mdev -d
}

setup_udev() {
	# Use udev to coldplug all devices so that they can be used via libinput (e.g.
	# by unl0kr). This is the same series of steps performed by the udev,
	# udev-trigger and udev-settle RC services. See also:
	# - https://git.alpinelinux.org/aports/tree/main/eudev/setup-udev
	# - https://git.alpinelinux.org/aports/tree/main/udev-init-scripts/APKBUILD
	if command -v udevd > /dev/null && command -v udevadm > /dev/null; then
		udevd -d
		udevadm trigger --type=devices --action=add
		udevadm settle
	fi
}

get_uptime_seconds() {
	# Get the current system uptime in seconds - ignore the two decimal places.
	awk -F '.' '{print $1}' /proc/uptime
}

setup_dynamic_partitions() {
	command -v make-dynpart-mappings > /dev/null || return
	attempt_start=$(get_uptime_seconds)
	wait_seconds=10
	slot_number=0
	for super_partition in $1; do
		# Wait for mdev
		echo "Waiting for super partition $super_partition..."
		while [ ! -b "$super_partition" ]; do
			if [ "$(get_uptime_seconds)" -ge $(( attempt_start + wait_seconds )) ]; then
				echo "ERROR: Super partition $super_partition failed to show up!"
				return;
			fi
			sleep 0.1
		done
		make-dynpart-mappings "$super_partition" "$slot_number"
		slot_number=$(( slot_number + 1 ))
	done
}

mount_subpartitions() {
	try_parts="/dev/disk/by-partlabel/userdata /dev/disk/by-partlabel/system* /dev/mapper/system*"
	android_parts=""
	for x in $try_parts; do
		[ -e "$x" ] && android_parts="$android_parts $x"
	done

	attempt_start=$(get_uptime_seconds)
	wait_seconds=10
	echo "Trying to mount subpartitions for $wait_seconds seconds..."
	while [ -z "$(find_boot_partition)" ]; do
		partitions="$android_parts $(grep -v "loop\|ram" < /proc/diskstats |\
			sed 's/\(\s\+[0-9]\+\)\+\s\+//;s/ .*//;s/^/\/dev\//')"
		for partition in $partitions; do
			case "$(kpartx -l "$partition" 2>/dev/null | wc -l)" in
				2)
					echo "Mount subpartitions of $partition"
					kpartx -afs "$partition"
					# Ensure that this was the *correct* subpartition
					# Some devices have mmc partitions that appear to have
					# subpartitions, but aren't our subpartition.
					if [ -n "$(find_boot_partition)" ]; then
						break
					fi
					kpartx -d "$partition"
					continue
					;;
				*)
					continue
					;;
			esac
		done
		if [ "$(get_uptime_seconds)" -ge $(( attempt_start + wait_seconds )) ]; then
			echo "ERROR: failed to mount subpartitions!"
			return;
		fi
		sleep 0.1;
	done
}

# Rewrite /dev/dm-X paths to /dev/mapper/...
pretty_dm_path() {
	dm="$1"
	n="${dm#/dev/dm-}"

	# If the substitution didn't do anything, then we're done
	[ "$n" = "$dm" ] && echo "$dm" && return

	# Get the name of the device mapper device
	name="/dev/mapper/$(cat "/sys/class/block/dm-${n}/dm/name")"
	echo "$name"
}

find_root_partition() {
	[ -n "$PMOS_ROOT" ] && echo "$PMOS_ROOT" && return

	# The partition layout is one of the following:
	# a) boot, root partitions on sdcard
	# b) boot, root partition on the "system" partition (which has its
	#    own partition header! so we have partitions on partitions!)
	#
	# mount_subpartitions() must get executed before calling
	# find_root_partition(), so partitions from b) also get found.

	# Short circuit all autodetection logic if pmos_root= or
	# pmos_root_uuid= is supplied on the kernel cmdline
	# shellcheck disable=SC2013
	if [ "$ROOT_PARTITION_UNLOCKED" = 0 ]; then
		for x in $(cat /proc/cmdline); do
			if ! [ "$x" = "${x#pmos_root_uuid=}" ]; then
				path="$(blkid --uuid "${x#pmos_root_uuid=}")"
				if [ -n "$path" ]; then
					PMOS_ROOT="$path"
					break
				fi
			fi
		done

		if [ -z "$PMOS_ROOT" ]; then
			for x in $(cat /proc/cmdline); do
				if ! [ "$x" = "${x#pmos_root=}" ]; then
					path="${x#pmos_root=}"
					if [ -e "$path" ]; then
						PMOS_ROOT="$path"
						break
					fi
				fi
			done
		fi

		# On-device installer: before postmarketOS is installed,
		# we want to use the installer partition as root. It is the
		# partition behind pmos_root. pmos_root will either point to
		# reserved space, or to an unfinished installation.
		# p1: boot
		# p2: (reserved space) <--- pmos_root
		# p3: pmOS_install
		# Details: https://postmarketos.org/on-device-installer
		if [ -n "$PMOS_ROOT" ]; then
			next="$(echo "$PMOS_ROOT" | sed 's/2$/3/')"

			# If the next partition is labeled pmOS_install (and
			# not pmOS_deleteme), then postmarketOS is not
			# installed yet.
			if blkid | grep "$next" | grep -q pmOS_install; then
				PMOS_ROOT="$next"
			fi
		fi
	fi

	if [ -z "$PMOS_ROOT" ]; then
		for id in pmOS_install pmOS_root; do
			PMOS_ROOT="$(blkid --label "$id")"
			[ -n "$PMOS_ROOT" ] && break
		done
	fi

	# Search for luks partition.
	# Note: This should always be after the filesystem search, since this
	# function may be called after the luks partition is unlocked and we don't
	# want to keep returning the luks partition if a valid root filesystem
	# exists
	if [ -z "$PMOS_ROOT" ]; then
		PMOS_ROOT="$(blkid | grep "crypto_LUKS" | cut -d ":" -f 1 | head -n 1)"
	fi

	PMOS_ROOT=$(pretty_dm_path "$PMOS_ROOT")
	echo "$PMOS_ROOT"
}

find_boot_partition() {
	[ -n "$PMOS_BOOT" ] && echo "$PMOS_BOOT" && return

	# Before doing anything else check if we are using a stowaway
	if grep -q "pmos.stowaway" /proc/cmdline; then
		mount_root_partition
		PMOS_BOOT="/sysroot/boot"
		mount --bind /sysroot/boot /boot

		echo "$PMOS_BOOT"
		return
	fi

	# Then check for pmos_boot_uuid on the cmdline
	# this should be set on all new installs.
	# shellcheck disable=SC2013
	for x in $(cat /proc/cmdline); do
		if ! [ "$x" = "${x#pmos_boot_uuid=}" ]; then
			# Check if there is a partition with a matching UUID
			path="$(blkid --uuid "${x#pmos_boot_uuid=}")"
			if [ -n "$path" ]; then
				PMOS_BOOT="$path"
				break
			else
				# Don't fall back to anything if the given UUID wasn't
				# found
				return
			fi
		fi
	done

	if [ -z "$PMOS_BOOT" ]; then
		# shellcheck disable=SC2013
		for x in $(cat /proc/cmdline); do
			if ! [ "$x" = "${x#pmos_boot=}" ]; then
				# If the boot partition is specified explicitly
				# then we need to check if it's a valid path, and
				# fall back if not...
				path="${x#pmos_boot=}"
				if [ -e "$path" ]; then
					PMOS_BOOT="$path"
					break
				else
					# Don't fall back to anything if the given path doesn't
					# exist
					return
				fi
			fi
		done
	fi

	# Finally fall back to searching by label
	if [ -z "$PMOS_BOOT" ]; then
		# * "pmOS_i_boot" installer boot partition (fits 11 chars for fat32)
		# * "pmOS_inst_boot" old installer boot partition (backwards compat)
		# * "pmOS_boot" boot partition after installation
		for p in pmOS_i_boot pmOS_inst_boot pmOS_boot; do
			PMOS_BOOT="$(blkid --label "$p")"
			[ -n "$PMOS_BOOT" ] && break
		done
	fi

	PMOS_BOOT=$(pretty_dm_path "$PMOS_BOOT")
	echo "$PMOS_BOOT"
}

get_partition_type() {
	partition="$1"
	blkid "$partition" | sed 's/^.*TYPE="\([a-zA-z0-9_]*\)".*$/\1/'
}

# $1: partition
check_filesystem() {
	local partition=""
	local status=""
	local type=""

	partition="$1"
	type="$(get_partition_type "$partition")"
	case "$type" in
		btrfs)
			echo "Check 'btrfs' root filesystem ($partition)"
			if ! btrfs check --readonly "$partition" ; then
				status="fail"
			fi
			;;
		ext*)
			echo "Auto-repair and check 'ext' filesystem ($partition)"
			e2fsck -p "$partition"
			if [ $? -ge 4 ]; then
				status="fail"
			fi
			;;
		f2fs)
			echo "Auto-repair and check 'f2fs' filesystem ($partition)"
			fsck.f2fs -p "$partition"
			status=$?
			if [ $? -gt 4 ]; then
				status="fail"
			fi
			;;
		vfat)
			echo "Auto-repair and check 'vfat' filesystem ($partition)"
			fsck.vfat -p "$partition"
			if [ $? -gt 4 ]; then
				status="fail"
			fi

			;;
		*)	echo "WARNING: fsck not supported for '$type' filesystem ($partition)." ;;
	esac

	if [ "$status" = "fail" ]; then
		show_splash "WARNING: filesystem needs manual repair (fsck) ($partition)\\nhttps://postmarketos.org/troubleshooting\\n\\nResuming to boot after 5 seconds..."
		sleep 5
	fi

	show_splash "Loading..."
}

# $1: path
# $2: set to "rw" for read-write
# Mount the boot partition. It gets mounted twice, first at /boot (ro), then at
# /sysroot/boot (rw), after root has been mounted at /sysroot, so we can
# switch_root to /sysroot and have the boot partition properly mounted.
mount_boot_partition() {
	partition="$(find_boot_partition)"
	local mount_opts="-o nodev,nosuid,noexec"

	# We dont need to do this when using stowaways
	if grep -q "pmos.stowaway" /proc/cmdline; then
		return
	fi

	if [ "$2" = "rw" ]; then
		check_filesystem "$partition"
		echo "Mount boot partition ($partition) to $1 (read-write)"
	else
		mount_opts="$mount_opts,ro"
		echo "Mount boot partition ($partition) to $1 (read-only)"
	fi

	type="$(get_partition_type "$partition")"
	case "$type" in
		ext*)
			echo "Detected ext filesystem"
			modprobe ext4
			# ext2 might be handled by the ext2 or ext4 kernel module
			# so let mount detect that automatically by omitting -t
			;;
		vfat)
			echo "Detected vfat filesystem"
			modprobe vfat
			mount_opts="-t vfat $mount_opts,umask=0077,nosymfollow,codepage=437,iocharset=ascii"
			;;
		*)	echo "WARNING: Detected unsupported '$type' filesystem ($partition)." ;;
	esac

	# shellcheck disable=SC2086
	mount $mount_opts "$partition" "$1"
}

# $1: initramfs-extra path
extract_initramfs_extra() {
	initramfs_extra="$1"
	if [ ! -e "$initramfs_extra" ]; then
		echo "ERROR: initramfs-extra not found!"
		show_splash "ERROR: initramfs-extra not found\\nhttps://postmarketos.org/troubleshooting"
		fail_halt_boot
	fi
	echo "Extract $initramfs_extra"
	# uncompressed:
	# cpio -di < "$initramfs_extra"
	gzip -d -c "$initramfs_extra" | cpio -iu
}

wait_boot_partition() {
	while [ -z "$(find_boot_partition)" ]; do
		show_splash "ERROR: boot partition not found, retrying...\\nhttps://postmarketos.org/troubleshooting"
		echo "Could not find the boot partition."
		echo "If your install is on a removable disk, maybe you need to insert it?"
		echo "Trying again..."
		sleep 1
	done
}

wait_root_partition() {
	while [ -z "$(find_root_partition)" ]; do
		show_splash "ERROR: root partition not found, retrying...\\nhttps://postmarketos.org/troubleshooting"
		echo "Could not find the rootfs."
		echo "If your install is on a removable disk, maybe you need to insert it?"
		echo "Trying again..."
		sleep 1
	done
}

delete_old_install_partition() {
	# The on-device installer leaves a "pmOS_deleteme" (p3) partition after
	# successful installation, located after "pmOS_root" (p2). Delete it,
	# so we can use the space.
	partition="$(find_root_partition | sed 's/2$/3/')"
	if ! blkid "$partition" | grep -q pmOS_deleteme; then
		return
	fi

	device="$(echo "$partition" | sed -E 's/p?3$//')"
	echo "First boot after running on-device installer - deleting old" \
		"install partition: $partition"
	parted -s "$device" rm 3
}

# $1: path to device
has_unallocated_space() {
	# Check if there is unallocated space at the end of the device
	parted -s "$1" print free | tail -n2 | \
		head -n1 | grep -qi "free space"
}

resize_root_partition() {
	partition=$(find_root_partition)

	# Do not resize the installer partition
	if [ "$(blkid --label pmOS_install)" = "$partition" ]; then
		echo "Resize root partition: skipped (on-device installer)"
		return
	fi

	# Only resize the partition if it's inside the device-mapper, which means
	# that the partition is stored as a subpartition inside another one.
	# In this case we want to resize it to use all the unused space of the
	# external partition.
	if [ -z "${partition##"/dev/mapper/"*}" ] || [ -z "${partition##"/dev/dm-"*}" ]; then
		# Get physical device
		partition_dev=$(dmsetup deps -o blkdevname "$partition" | \
			awk -F "[()]" '{print "/dev/"$2}')
		if has_unallocated_space "$partition_dev"; then
			echo "Resize root partition ($partition)"
			# unmount subpartition, resize and remount it
			kpartx -d "$partition"
			parted -f -s "$partition_dev" resizepart 2 100%
			kpartx -afs "$partition_dev"
			ROOT_PARTITION_RESIZED=1
		else
			echo "Not resizing root partition ($partition): no free space left"
		fi

	# Resize the root partition (non-subpartitions). Usually we do not want
	# this, except for QEMU devices and non-android devices (e.g.
	# PinePhone). For them, it is fine to use the whole storage device and
	# so we pass PMOS_FORCE_PARTITION_RESIZE as kernel parameter.
	elif grep -q PMOS_FORCE_PARTITION_RESIZE /proc/cmdline; then
		partition_dev="$(echo "$partition" | sed -E 's/p?2$//')"
		if has_unallocated_space "$partition_dev"; then
			echo "Resize root partition ($partition)"
			parted -f -s "$partition_dev" resizepart 2 100%
			partprobe
			ROOT_PARTITION_RESIZED=1
		else
			echo "Not resizing root partition ($partition): no free space left"
		fi

	# Resize the root partition (non-subpartitions) on Chrome OS devices.
	# Match $deviceinfo_cgpt_kpart not being empty instead of cmdline
	# because it does not make sense here as all these devices use the same
	# partitioning methods. This also resizes third partition instead of
	# second, because these devices have an additional kernel partition
	# at the start.
	elif [ -n "$deviceinfo_cgpt_kpart" ]; then
		partition_dev="$(echo "$partition" | sed -E 's/p?3$//')"
		if has_unallocated_space "$partition_dev"; then
			echo "Resize root partition ($partition)"
			parted -f -s "$partition_dev" resizepart 3 100%
			partprobe
			ROOT_PARTITION_RESIZED=1
		else
			echo "Not resizing root partition ($partition): no free space left"
		fi

	else
		echo "Unable to resize root partition: failed to find qualifying partition"
	fi
}

unlock_root_partition() {
	command -v cryptsetup >/dev/null || return
	partition="$(find_root_partition)"
	if cryptsetup isLuks "$partition"; then
		# Make sure the splash doesn't interfere
		hide_splash
		tried=0
		until cryptsetup status root | grep -qwi active; do
			fde-unlock "$partition" "$tried"
			tried=$((tried + 1))
		done
		ROOT_PARTITION_UNLOCKED=1
		# Show again the loading splashscreen
		show_splash "Loading..."
	fi
}

resize_root_filesystem() {
	if [ "$ROOT_PARTITION_RESIZED" = 1 ]; then
		show_splash "Resizing filesystem during initial boot..."
		partition="$(find_root_partition)"
		touch /etc/mtab # see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=673323
		type="$(get_partition_type "$partition")"
		case "$type" in
			ext4)
				echo "Resize 'ext4' root filesystem ($partition)"
				modprobe ext4
				resize2fs -f "$partition"
				;;
			f2fs)
				echo "Resize 'f2fs' root filesystem ($partition)"
				modprobe f2fs
				resize.f2fs "$partition"
				;;
			btrfs)
				echo "Resize 'btrfs' root filesystem ($partition)"
				modprobe btrfs
				resize_root_filesystem_tmp_btrfs="$(mktemp -d)"
				mount -t btrfs "$partition" "$resize_root_filesystem_tmp_btrfs"
				btrfs filesystem resize max "$resize_root_filesystem_tmp_btrfs"
				umount "$resize_root_filesystem_tmp_btrfs"
				unset resize_root_filesystem_tmp_btrfs
				;;
			*)	echo "WARNING: Can not resize '$type' filesystem ($partition)." ;;
		esac
		show_splash "Loading..."
	fi
}

mount_root_partition() {
	# Don't mount root if it is already mounted
	if mountpoint -q /sysroot; then
		return
	fi

	partition="$(find_root_partition)"
	rootfsopts=""

	check_filesystem "$partition"

	# shellcheck disable=SC2013
	for x in $(cat /proc/cmdline); do
		[ "$x" = "${x#pmos_rootfsopts=}" ] && continue
		# Prepend a comma because this will be appended to "rw" below
		rootfsopts=",${x#pmos_rootfsopts=}"
	done

	echo "Mount root partition ($partition) to /sysroot (read-write) with options ${rootfsopts#,}"
	type="$(get_partition_type "$partition")"
	echo "Detected $type filesystem"

	if ! { [ "$type" = "ext4" ] || [ "$type" = "f2fs" ] || [ "$type" = "btrfs" ]; } then
		echo "ERROR: Detected unsupported '$type' filesystem ($partition)."
		show_splash "ERROR: unsupported '$type' filesystem ($partition)\\nhttps://postmarketos.org/troubleshooting"
		fail_halt_boot
	fi

	if ! modprobe "$type"; then
		echo "INFO: unable to load module '$type' - maybe it's built in"
	fi

	if [ "$type" = "btrfs" ]; then
		btrfs device scan
	fi
	
	if ! mount -t "$type" -o rw"$rootfsopts" "$partition" /sysroot; then
		echo "ERROR: unable to mount root partition!"
		show_splash "ERROR: unable to mount root partition\\nhttps://postmarketos.org/troubleshooting"
		fail_halt_boot
	fi

	if [ -e /sysroot/.stowaways/pmos/etc/os-release ]; then
		umount /sysroot

		mkdir /stowaway
		mount -t "$type" -o rw"$rootfsopts" "$partition" /stowaway
		mount --bind /stowaway/.stowaways/pmos/ /sysroot
	fi

	if ! [ -e /sysroot/etc/os-release ]; then
		echo "ERROR: root partition appeared to mount but does not contain a root filesystem!"
		show_splash "ERROR: root partition does not contain a root filesystem\\nhttps://postmarketos.org/troubleshooting"
		fail_halt_boot
	fi
}

# $1: path to the hooks dir
run_hooks() {
	scriptsdir="$1"

	if ! [ -d "$scriptsdir" ]; then
		return
	fi

	for hook in "$scriptsdir"/*.sh; do
		echo "Running initramfs hook: $hook"
		sh "$hook"
	done
}

setup_usb_network_android() {
	# Only run, when we have the android usb driver
	SYS=/sys/class/android_usb/android0
	if ! [ -e "$SYS" ]; then
		echo "  /sys/class/android_usb does not exist, skipping android_usb"
		return
	fi

	echo "  Setting up an USB gadget through android_usb"

	usb_idVendor="$(echo "${deviceinfo_usb_idVendor:-0x18D1}" | sed "s/0x//g")"	# default: Google Inc.
	usb_idProduct="$(echo "${deviceinfo_usb_idProduct:-0xD001}" | sed "s/0x//g")"	# default: Nexus 4 (fastboot)

	# Do the setup
	echo "0" >"$SYS/enable"
	echo "$usb_idVendor" >"$SYS/idVendor"
	echo "$usb_idProduct" >"$SYS/idProduct"
	echo "rndis" >"$SYS/functions"
	echo "1" >"$SYS/enable"
}


setup_usb_configfs_udc() {
	# Check if there's an USB Device Controller
	local _udc_dev="${deviceinfo_usb_network_udc:-}"
	if [ -z "$_udc_dev" ]; then
		_udc_dev=$(ls /sys/class/udc)
		if [ -z "$_udc_dev" ]; then
			echo "  No USB Device Controller available"
			return
		fi
	fi

	# Remove any existing UDC to avoid "write error: Resource busy" when setting UDC again
	echo "" > /config/usb_gadget/g1/UDC || echo "  Couldn't write to clear UDC"
	# Link the gadget instance to an USB Device Controller. This activates the gadget.
	# See also: https://gitlab.com/postmarketOS/pmbootstrap/issues/338
	echo "$_udc_dev" > /config/usb_gadget/g1/UDC || echo "  Couldn't write new UDC"
}

# $1: if set, skip writing to the UDC
setup_usb_network_configfs() {
	# See: https://www.kernel.org/doc/Documentation/usb/gadget_configfs.txt
	CONFIGFS=/config/usb_gadget
	local skip_udc="$1"

	if ! [ -e "$CONFIGFS" ]; then
		echo "  /config/usb_gadget does not exist, skipping configfs usb gadget"
		return
	fi

	# Default values for USB-related deviceinfo variables
	usb_idVendor="${deviceinfo_usb_idVendor:-0x18D1}"   # default: Google Inc.
	usb_idProduct="${deviceinfo_usb_idProduct:-0xD001}" # default: Nexus 4 (fastboot)
	usb_serialnumber="${deviceinfo_usb_serialnumber:-postmarketOS}"
	usb_network_function="${deviceinfo_usb_network_function:-ncm.usb0}"
	usb_network_function_fallback="rndis.usb0"

	echo "  Setting up an USB gadget through configfs"
	# Create an usb gadet configuration
	mkdir $CONFIGFS/g1 || echo "  Couldn't create $CONFIGFS/g1"
	echo "$usb_idVendor"  > "$CONFIGFS/g1/idVendor"
	echo "$usb_idProduct" > "$CONFIGFS/g1/idProduct"

	# Create english (0x409) strings
	mkdir $CONFIGFS/g1/strings/0x409 || echo "  Couldn't create $CONFIGFS/g1/strings/0x409"

	# shellcheck disable=SC2154
	echo "$deviceinfo_manufacturer" > "$CONFIGFS/g1/strings/0x409/manufacturer"
	echo "$usb_serialnumber"        > "$CONFIGFS/g1/strings/0x409/serialnumber"
	# shellcheck disable=SC2154
	echo "$deviceinfo_name"         > "$CONFIGFS/g1/strings/0x409/product"

	# Create network function.
	if ! mkdir $CONFIGFS/g1/functions/"$usb_network_function"; then
		echo "  Couldn't create $CONFIGFS/g1/functions/$usb_network_function"
		# Try the fallback function next
		if mkdir $CONFIGFS/g1/functions/"$usb_network_function_fallback"; then
			usb_network_function="$usb_network_function_fallback"
		else
			echo "  Couldn't create $CONFIGFS/g1/functions/$usb_network_function_fallback"
		fi
	fi

	# Create configuration instance for the gadget
	mkdir $CONFIGFS/g1/configs/c.1 \
		|| echo "  Couldn't create $CONFIGFS/g1/configs/c.1"
	mkdir $CONFIGFS/g1/configs/c.1/strings/0x409 \
		|| echo "  Couldn't create $CONFIGFS/g1/configs/c.1/strings/0x409"
	echo "USB network" > $CONFIGFS/g1/configs/c.1/strings/0x409/configuration \
		|| echo "  Couldn't write configration name"

	# Link the network instance to the configuration
	ln -s $CONFIGFS/g1/functions/"$usb_network_function" $CONFIGFS/g1/configs/c.1 \
		|| echo "  Couldn't symlink $usb_network_function"

	# If an argument was supplied then skip writing to the UDC (only used for mass storage
	# log recovery)
	if [ -z "$skip_udc" ]; then
		setup_usb_configfs_udc
	fi
}

setup_usb_network() {
	# Only run once
	_marker="/tmp/_setup_usb_network"
	[ -e "$_marker" ] && return
	touch "$_marker"
	echo "Setup usb network"
	# Run all usb network setup functions (add more below!)
	setup_usb_network_android
	setup_usb_network_configfs
}

start_unudhcpd() {
	# Only run once
	[ "$(pidof unudhcpd)" ] && return

	# Skip if disabled
	# shellcheck disable=SC2154
	if [ "$deviceinfo_disable_dhcpd" = "true" ]; then
		echo "NOTE: start of dhcpd is disabled (deviceinfo_disable_dhcpd)"
		return
	fi

	local host_ip="${unudhcpd_host_ip:-172.16.42.1}"
	local client_ip="${unudhcpd_client_ip:-172.16.42.2}"
	echo "Starting unudhcpd with server ip $host_ip, client ip: $client_ip"

	# Get usb interface
	usb_network_function="${deviceinfo_usb_network_function:-ncm.usb0}"
	usb_network_function_fallback="rndis.usb0"
	if [ -n "$(cat /config/usb_gadget/g1/UDC)" ]; then
		INTERFACE="$(
			cat "/config/usb_gadget/g1/functions/$usb_network_function/ifname" 2>/dev/null ||
			cat "/config/usb_gadget/g1/functions/$usb_network_function_fallback/ifname" 2>/dev/null ||
			echo ''
		)"
	else
		INTERFACE=""
	fi
	if [ -n "$INTERFACE" ]; then
		ifconfig "$INTERFACE" "$host_ip"
	elif ifconfig rndis0 "$host_ip" 2>/dev/null; then
		INTERFACE=rndis0
	elif ifconfig usb0 "$host_ip" 2>/dev/null; then
		INTERFACE=usb0
	elif ifconfig eth0 "$host_ip" 2>/dev/null; then
		INTERFACE=eth0
	fi

	if [ -z "$INTERFACE" ]; then
		echo "  Could not find an interface to run a dhcp server on"
		echo "  Interfaces:"
		ip link
		return
	fi

	echo "  Using interface $INTERFACE"
	echo "  Starting the DHCP daemon"
	(
		unudhcpd -i "$INTERFACE" -s "$host_ip" -c "$client_ip"
	) &
}

# $1: Message to show
show_splash() {
	# Skip for non-framebuffer devices
	# shellcheck disable=SC2154
	if [ "$deviceinfo_no_framebuffer" = "true" ]; then
		echo "NOTE: Skipping framebuffer splashscreen (deviceinfo_no_framebuffer)"
		return
	fi

	# Disable splash
	if grep -q PMOS_NOSPLASH /proc/cmdline; then
		return
	fi

	hide_splash

	# shellcheck disable=SC2154,SC2059
	/usr/bin/pbsplash -s /usr/share/pbsplash/pmos-logo-text.svg \
		-b "$VERSION | Linux $(uname -r) | $deviceinfo_codename" \
		-m "$(printf "$1")" >/dev/null &
}

hide_splash() {
	killall pbsplash 2>/dev/null

	while pgrep pbsplash >/dev/null; do
		sleep 0.01
	done
}

set_framebuffer_mode() {
	[ -e "/sys/class/graphics/fb0/modes" ] || return
	[ -z "$(cat /sys/class/graphics/fb0/mode)" ] || return

	_mode="$(cat /sys/class/graphics/fb0/modes)"
	echo "Setting framebuffer mode to: $_mode"
	echo "$_mode" > /sys/class/graphics/fb0/mode
}

setup_framebuffer() {
	# Skip for non-framebuffer devices
	# shellcheck disable=SC2154
	if [ "$deviceinfo_no_framebuffer" = "true" ]; then
		echo "NOTE: Skipping framebuffer setup (deviceinfo_no_framebuffer)"
		return
	fi

	# Wait for /dev/fb0
	for _ in $(seq 1 100); do
		[ -e "/dev/fb0" ] && break
		sleep 0.1
	done
	if ! [ -e "/dev/fb0" ]; then
		echo "ERROR: /dev/fb0 did not appear after waiting 10 seconds!"
		echo "If your device does not have a framebuffer, disable this with:"
		echo "no_framebuffer=true in <https://postmarketos.org/deviceinfo>"
		return
	fi

	set_framebuffer_mode
}

setup_bootchart2() {
	if grep -q PMOS_BOOTCHART2 /proc/cmdline; then
		if [ -f "/sysroot/sbin/bootchartd" ]; then
			# shellcheck disable=SC2034
			init="/sbin/bootchartd"
			echo "remounting /sysroot as rw for /sbin/bootchartd"
			mount -o remount, rw /sysroot

			# /dev/null may not exist at the first boot after
			# the root filesystem has been created.
			[ -c /sysroot/dev/null ] && return
			echo "creating /sysroot/dev/null for /sbin/bootchartd"
			mknod -m 666 "/sysroot/dev/null" c 1 3
		else
			echo "WARNING: bootchart2 is not installed."
		fi
	fi
}

mkhash() {
	sha256sum "$1" | cut -d " " -f 1
}

# Create a small disk image and copy logs to it so they can be exposed via mass storage
create_logs_disk() {
	local loop_dev="$1"
	local upload_file=""
	echo "Creating logs disk"

	fallocate -l 32M /tmp/logs.img
	# The log device used is assumed to be $loop_dev
	losetup -f /tmp/logs.img
	mkfs.vfat -n "PMOS_LOGS" "$loop_dev"
	mkdir -p /tmp/logs
	mount "$loop_dev" /tmp/logs

	# Copy logs
	cp /pmOS_init.log /tmp/logs/pmOS_init.txt
	dmesg > /tmp/logs/dmesg.txt
	blkid > /tmp/logs/blkid.txt
	cat /proc/cmdline > /tmp/logs/cmdline.txt
	cat /proc/partitions > /tmp/logs/partitions.txt
	# Include FDT if it exists
	[ -e /sys/firmware/fdt ] && cp /sys/firmware/fdt /tmp/logs/fdt.dtb

	# Additional info about the initramfs
	{
		echo "initramfs-version: $INITRAMFS_PKG_VERSION"
		# Take hashes of the initramfs files so we can be sure they weren't modified inadvertantly
		echo "init-hash: $(mkhash /init)"
		echo "init-functions-hash: $(mkhash /init_functions.sh)"
	} >> /tmp/logs/_info

	# Create a tar file with all the logs. We don't include the date because on many devices
	# (especially Qualcomm) the RTC is likely wrong.
	upload_file="${deviceinfo_codename}-${VERSION}-$(uname -r).tar.gz"
	# Done in a subshell to not change the working directory of init
	(cd /tmp/logs || ( echo "Couldn't cd to /tmp/logs"; return ); tar -cv ./* | gzip -6 -c > "/tmp/$upload_file")
	mv "/tmp/$upload_file" /tmp/logs/

	# Create a README with instructions on how to report an issue
	cat > /tmp/logs/README.txt <<-EOF
	Something went wrong and your device did not boot properly. If this was unexpected
	then please open a new issue by visiting

	https://gitlab.com/postmarketOS/pmaports/-/issues/new

	and attach the following file by dragging it onto the page:

	* $upload_file

	You are running postmarketOS $VERSION on kernel $(uname -r).
	EOF

	# Unmount
	umount /tmp/logs
}

# Make logs available via mass storage gadget
export_logs() {
	local loop_dev=""
	usb_mass_storage_function="mass_storage.0"
	active_udc="$(cat /config/usb_gadget/g1/UDC)"

	loop_dev="$(losetup -f)"

	create_logs_disk "$loop_dev"

	echo "Making logs available via mass storage"

	# Set up network gadget if not already done
	if [ -z "$active_udc" ]; then
		setup_usb_network_configfs "skip_udc"
	else
		# Unset UDC
		echo "" > /config/usb_gadget/g1/UDC
	fi

	mkdir "$CONFIGFS"/g1/functions/"$usb_mass_storage_function" || return

	echo "$loop_dev" > "$CONFIGFS"/g1/functions/"$usb_mass_storage_function"/lun.0/file

	ln -s "$CONFIGFS"/g1/functions/"$usb_mass_storage_function" \
		"$CONFIGFS"/g1/configs/c.1 || return

	setup_usb_configfs_udc
}

fail_halt_boot() {
	export_logs
	echo "Looping forever"
	while true; do
		sleep 1
	done
}
