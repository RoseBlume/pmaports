#!/bin/bash

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

# srcdir is defined in APKBUILD
# shellcheck disable=SC2154
fragments_from_package="$(find "$srcdir" -maxdepth 1 -name "*.config")"

if [ -n "$fragments_from_package" ]; then
	for config in $fragments_from_package;
	do
		kernel_configs="$kernel_configs $(basename "$config")"
	done
fi

# $1: config fragment name
validate_config() {
	_fragment="$1"
	# builddir is defined at APKBUILD
	# shellcheck disable=SC2154
	_fragment_file="$builddir"/kernel/configs/"$_fragment"
	# shellcheck disable=SC2154
	_config_file="$builddir"/.config

	# validate =y and =m values
	while IFS= read -r line; do
		if ! grep -q "$line" "$_config_file"; then
			echo "ERROR: $line must be set! Please fix $_fragment fragment!"
			EXIT_CODE=1
		fi
	done < <(grep -Eo "^CONFIG.*=[ym]" "$_fragment_file")

	# validate =n values
	while IFS= read -r line; do
		if ! grep -q "# ${line%=n} is not set" "$_config_file"; then
			echo "ERROR: ${line%=n} must NOT be set! Please fix $_fragment fragment!"
			EXIT_CODE=1
		fi
	done < <(grep -Eo "^CONFIG.*=n" "$_fragment_file")

	# validate ="something" values
	while IFS= read -r line; do
		if ! grep -q "$line" "$_config_file"; then
			echo "ERROR: ${line%=*} must be set to ${line#*=}! Please fix $_fragment fragment!"
			EXIT_CODE=1
		fi
	done < <(grep -Eo "^CONFIG.*=\".*\"" "$_fragment_file")
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
for config in $kernel_configs; do
	_paths="/usr/share/devicepkg-dev/config-fragments/$config $srcdir/$config"
	for file in $_paths; do
		[ -f "$file" ] && cp "$file" "$builddir"/kernel/configs
	done
done

# apply all the configs, _pmos_defconfig is defined in device package
# shellcheck disable=SC2086,SC2154
# _carch and _pmos_defconfig are defined in APKBUILD
make ARCH="$_carch" $_pmos_defconfig $kernel_configs

# validate all configs. this will go through all of them, and will
# print all errors. However, it will end the script only after going
# through all configs, because we want to see all problems that
# happen during applying the configs
#
# EXIT_CODE will be set to 1 in validate_config function if there is
# at least one misconfiguration, so we will be able to end up with an
# error on condition of this variable.
EXIT_CODE=0
for config in $kernel_configs;
do
	validate_config "$config"
done

if [ "$EXIT_CODE" -ne 0 ]; then
	exit "$EXIT_CODE"
fi
