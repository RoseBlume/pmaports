#!/bin/sh

set -x

apk add git

echo "----------"
pwd
echo "----------"
git config --list
echo "----------"
git status
echo "----------"
git remote -v
echo "----------"
git remote add upstream https://gitlab.com/postmarketOS/pmaports
echo "----------"
git fetch upstream
echo "----------"
git rev-parse upstream/master
git rev-parse HEAD
echo "----------"
