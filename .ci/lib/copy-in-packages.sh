#!/bin/sh -ex
# Copies packages from previous build artifacts into the
# local binary repo

ARCH="$1"

if [ -z "$ARCH" ]; then
	echo "Usage: $0 <arch>"
	exit 1
fi

mkdir -p /home/pmos/.local/var/pmbootstrap/packages/edge/"$ARCH"
cp packages/edge/"$ARCH"/*.apk /home/pmos/.local/var/pmbootstrap/packages/edge/"$ARCH"
chown -R 12345:12345 /home/pmos/.local/var/pmbootstrap/packages/edge/"$ARCH"
sudo -u pmos -- pmbootstrap index
