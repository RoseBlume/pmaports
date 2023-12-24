#!/bin/sh

unset LDFLAGS
# shellcheck disable=SC2154
# _carch and pkgrel are defined in APKBUILD
make ARCH="$_carch" CC="${CC:-gcc}" \
	KBUILD_BUILD_VERSION="$((pkgrel + 1 ))-postmarketOS"
