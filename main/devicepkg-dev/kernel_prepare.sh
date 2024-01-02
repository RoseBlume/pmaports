#!/bin/sh

kernel_configs=""

# $1: config fragment name
add_config() {
	_config="$1"

	# update kernel_configs variable with a new fragment
	kernel_configs="$kernel_configs $_config.config"

	# look for architecture-speficic fragment in the format <name>-<carch>.config
	# shellcheck disable=SC2154
	# _carch is defined in APKBUILD
	_arch_config="$_config-$_carch.config"
	if [ -f "/usr/share/devicepkg-dev/config-fragments/$_arch_config" ]; then
		kernel_configs="$kernel_configs $_arch_config"
	fi
}

# mainline is default config fragment
add_config "mainline"

# shellcheck disable=SC2154
# _pmos_uefi is defined in APKBUILD
if [ "$_pmos_uefi" = "true" ]; then
	add_config "uefi"
fi

# copy fragments
# shellcheck disable=SC2154
# builddir is defined in APKBUILD
for config in $kernel_configs;
do
	cp /usr/share/devicepkg-dev/config-fragments/"$config" "$builddir"/kernel/configs
done

# apply all the configs, _pmos_defconfig is defined in device package
# shellcheck disable=SC2086,SC2154
# _carch and _pmos_defconfig are defined in APKBUILD
make ARCH="$_carch" $_pmos_defconfig $kernel_configs
