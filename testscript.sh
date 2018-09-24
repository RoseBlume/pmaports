#!/bin/sh

set -x

apk add git

echo "----------"
git remote add upstream https://gitlab.com/postmarketOS/pmaports
echo "----------"
git fetch upstream
echo "----------"
