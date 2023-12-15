#!/bin/sh -e
# Copyright 2024 Caleb Connolly
# SPDX-License-Identifier: GPL-3.0-or-later
# Description: check pkgver/pkgrel bumps, amount of changed pkgs etc
# Options: native
# Use 'native' because it requires git commit history.
# https://postmarketos.org/pmb-ci

if [ "$(id -u)" = 0 ]; then
	set -x
	apk -q add python3 git
	# Keep environment variables
	exec su -p "${TESTUSER:-build}" -c "sh -e $0"
fi

.ci/lib/generate_test_pipeline.py
