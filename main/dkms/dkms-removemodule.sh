#!/bin/sh
# We want to remove all the old modules added to dkms before removing the sources
NAME="$1"

REG="$NAME"'-[[:digit:]]{1,3}'
for OLDMODULE in $(ls /usr/src | grep -E "$REG"); do
	VERSION="$(echo "$OLDMODULE" | grep -Eo '[0-9\.]{1,3}$')"
	echo "Removing module '$NAME' with version $VERSION"
	dkms remove -m "$NAME" -v $VERSION
done
