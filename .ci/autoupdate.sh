#!/bin/sh -e
# Description: update a list of packages
# Options: native slow
# https://postmarketos.org/pmb-ci

if [ "$(id -u)" = 0 ]; then
	set -x
	apk add git openssh-keygen grep curl
	wget "https://gitlab.com/postmarketOS/ci-common/-/raw/master/install_pmbootstrap.sh"
	sh ./install_pmbootstrap.sh
	exec su "${TESTUSER:-pmos}" -c "sh -e $0 $*"
fi

git config --global --add safe.directory "$CI_PROJECT_DIR"
git config --global user.name "postmarketOS CI"
# pmaports
# The email address is the username of the bot (from the GitLab group members page) @noreply.gitlab.com
git config --global user.email "project_8065375_bot_13cf44ca4cd2c938688af6e3d500d9cb@noreply.gitlab.com"

# For testing with pmaports-autoupdate-test repo
# git config --global user.email "project_58002231_bot_be2d4e9e7aba929855726aafe12940d6@noreply.gitlab.com"

# Configure SSH key for signing
mkdir -p ~/.ssh
cp "$PMAPORTS_SSH_KEY" ~/.ssh/pmaports
chmod 600 ~/.ssh/pmaports
# Generate public key from private
ssh-keygen -t ecdsa -f ~/.ssh/pmaports -y > ~/.ssh/pmaports.pub

git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/pmaports.pub

export PYTHONUNBUFFERED=1

PKGS="$1"
if [ -z "$PKGS" ]; then
	echo "Usage: $0 <packages>"
	exit 1
fi
echo "Checking for new versions of packages: $PKGS"

update_linux_next() {
	# Check for the latest -next tag
	local latest
	local pkgver
	local new_pkgver

	# Get the current version
	# shellcheck source=/dev/null
	pkgver=$(. device/testing/linux-next/APKBUILD; echo "$pkgver")

	curl -s "https://gitlab.com/linux-kernel/linux-next/-/tags?format=atom" | grep -oP "(?<=<title>)[^<]+" | tail -n +2 > /tmp/tags

	latest=$(grep -v "v" < /tmp/tags | head -n1)
	if [ -z "$latest" ]; then
		echo "Failed to get the latest -next tag"
		exit 1
	fi
	echo "Latest -next tag: $latest"

	new_pkgver=$(grep "v" < /tmp/tags | head -n1)
	if [ -z "$new_pkgver" ]; then
		echo "Failed to get the latest mainline tag from atom feed, reusing current pkgver"
		new_pkgver="${pkgver%_git*}"
	else
		echo "Latest mainline tag: $new_pkgver"
		# new_pkgver is like 'v6.9-rc1' but we want '6.9'
		new_pkgver=$(echo "$new_pkgver" | sed -e 's/^v//' -e 's/-.*//')
	fi

	new_pkgver="${new_pkgver}_git${latest#*-}"

	if [ "$pkgver" = "$new_pkgver" ]; then
		echo "No new version of linux-next"
		exit 0
	fi

	echo "Updating linux-next from $pkgver to $new_pkgver..."
	sed -i -e "s/pkgver=$pkgver/pkgver=$new_pkgver/" device/testing/linux-next/APKBUILD

	# Update the checksums
	pmbootstrap checksum linux-next

	# Ensure it builds
	pmbootstrap --details-to-stdout build linux-next

	# Commit
	git add device/testing/linux-next/APKBUILD
	git commit -S -m "linux-next: upgrade to $latest"
}

# For testing
#git remote add gitlab https://pmos-ci:"$PMAPORTS_PUSH_TOKEN"@gitlab.com/postmarketOS/pmaports-autoupdate-test.git

git remote add gitlab https://pmos-ci:"$PMAPORTS_PUSH_TOKEN"@gitlab.com/postmarketOS/pmaports.git
git fetch gitlab
git checkout --track gitlab/master

for pkg in $PKGS; do
	case "$pkg" in
		linux-next)
			update_linux_next
			;;
		*)
			echo "Unknown package: $pkg"
			exit 1
			;;
	esac
done

git push
