#!/bin/sh -e
# Description: Lint testcases
# https://postmarktos.org/pmb-ci

if [ "$(id -u)" = 0 ]; then
	set -x
	apk -q add \
		py-flake8
	exec su "${TESTUSER:-build}" -c "sh -e $0"
fi

flake8 --ignore E501,F401,E722,W504,W605
