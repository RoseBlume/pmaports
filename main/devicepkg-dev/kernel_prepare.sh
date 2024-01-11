#!/bin/bash

kernel_configs=""

# $1: file path
apply_jinja_template() {
	filepath="$1"
	filename="$(basename "$filepath")"
	# builddir is defined in APKBUILD
	# shellcheck disable=SC2154
	makefile="$builddir"/Makefile
	kernel_version="$(grep "^VERSION" "$makefile" | sed -e "s/VERSION = //")"
	kernel_patchlevel="$(grep "^PATCHLEVEL" "$makefile" | sed -e "s/PATCHLEVEL = //")"
	# shellcheck disable=SC2154
	jinja2 --strict \
		-D kernel_version="$kernel_version" \
		-D kernel_patchlevel="$kernel_patchlevel" \
		-D arch="$_carch" \
		"$filepath" > "$builddir"/kernel/configs/"${filename%.j2}"
}

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

# if full config is supplied instead of defconfig, copy it.
copy_full_config() {
	# shellcheck disable=SC2154
	# _config and srcdir are defined in APKBUILD
	if [ -n "$_config" ]; then
		cp "$srcdir/$_config" .config
	fi
}

# if we need only to copy a full config (.e.g. if we want to edit
# it), then we can pass ONLY_COPY=1 to env and the code will end up
# here. This is needed for "pmbootstrap kconfig edit" command when
# using full configs
if [ "$ONLY_COPY" = "1" ]; then
	copy_full_config
	return
fi

# srcdir is defined in APKBUILD
# shellcheck disable=SC2154
fragments_from_package="$(find "$srcdir" -maxdepth 1 -name "*.config" -o -name "*.config.j2")"

if [ -n "$fragments_from_package" ]; then
	for config in $fragments_from_package;
	do
		kernel_configs="$kernel_configs $(basename "$config")"
	done
fi

# mainline is default config fragment
kernel_configs="$kernel_configs mainline.config.j2"

# shellcheck disable=SC2154
# _pmos_uefi is defined in APKBUILD
if [ "$_pmos_uefi" = "true" ]; then
	kernel_configs="$kernel_configs uefi.config.j2"
fi

# copy fragments
# shellcheck disable=SC2154
# builddir is defined in APKBUILD
for config in $kernel_configs; do
	_paths="/usr/share/devicepkg-dev/config-fragments/$config $srcdir/$config"
	for file in $_paths; do
		if [ -f "$file" ]; then
			if [[ "$file" == *.config ]]; then
				cp "$file" "$builddir"/kernel/configs
			elif [[ "$file" == *.config.j2 ]]; then
				apply_jinja_template "$file"
			fi
		fi
	done
done

# copy full config when using it instead of defconfig
# empty _pmos_defconfig won't be a problem
copy_full_config

# apply all the configs, _pmos_defconfig is defined in device package
# shellcheck disable=SC2086,SC2154
# _carch and _pmos_defconfig are defined in APKBUILD
make ARCH="$_carch" $_pmos_defconfig ${kernel_configs//.j2/}

# validate all configs. this will go through all of them, and will
# print all errors. However, it will end the script only after going
# through all configs, because we want to see all problems that
# happen during applying the configs
#
# EXIT_CODE will be set to 1 in validate_config function if there is
# at least one misconfiguration, so we will be able to end up with an
# error on condition of this variable.
EXIT_CODE=0
for config in ${kernel_configs//.j2/};
do
	validate_config "$config"
done

if [ "$EXIT_CODE" -ne 0 ]; then
	exit "$EXIT_CODE"
fi
