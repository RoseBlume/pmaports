#!/bin/sh

set -x

apk add git

echo "----------"
git remote add upstream https://gitlab.com/z3ntu/pmaports
echo "----------"
git fetch upstream
echo "----------"
