#!/bin/sh -e
# Description: Run editconfig-checker (file formatting)
# https://postmarktos.org/pmb-ci

if [ "$(id -u)" = 0 ]; then
	set -x
	apk -q add \
		editorconfig-checker
	exec su "${TESTUSER:-build}" -c "sh -e $0"
fi

ec
