#!/bin/sh -e
# Description: Make sure all DTBs are installed in the right place
# https://postmarktos.org/pmb-ci

if grep -r 'INSTALL_DTBS_PATH="$pkgdir"/usr/share/dtb' */*/linux-*/APKBUILD; then
	echo 'Please do not install dtbs to /usr/share/dtb!'
	echo 'Unless you have a good reason not to, please put them in /boot/dtbs'
	exit 1
fi
