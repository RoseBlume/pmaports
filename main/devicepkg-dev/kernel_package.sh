#!/bin/sh

# shellcheck disable=SC2154
# pkgdir is defined in APKBUILD
mkdir -p "$pkgdir"/boot

case "$_carch" in
	arm|arm64) _make_install="zinstall modules_install dtbs_install";;
	riscv64) _make_install="install modules_install dtbs_install";;
	*) _make_install="install";;
esac

# shellcheck disable=SC2086,SC2154
# pkgdir is defined in APKBUILD
make $_make_install \
	ARCH="$_carch" \
	INSTALL_PATH="$pkgdir"/boot \
	INSTALL_MOD_PATH="$pkgdir" \
	INSTALL_MOD_STRIP=1 \
	INSTALL_DTBS_PATH="$pkgdir"/boot/dtbs
rm -f "$pkgdir"/lib/modules/*/build "$pkgdir"/lib/modules/*/source

# shellcheck disable=SC2154
# builddir, pkgdir, _flavor are defined in APKBUILD
install -D "$builddir"/include/config/kernel.release \
	"$pkgdir"/usr/share/kernel/"$_flavor"/kernel.release
