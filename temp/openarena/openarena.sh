#!/bin/sh
cd /usr/share/games/openarena
ARCH=$(uname -m)
./openarena.$ARCH "$@"
