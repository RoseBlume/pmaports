#!/bin/ash

FILE=/tmp/checkra1n-0.12.4-beta
SHA256SUM=dac9968939ea6e6bfbdedeb41d7e2579c4711dc2c5083f91dced66ca397dc51d

if ! test -f "$FILE"; then
	wget "https://assets.checkra.in/downloads/linux/cli/x86_64/dac9968939ea6e6bfbdedeb41d7e2579c4711dc2c5083f91dced66ca397dc51d/checkra1n" -O $FILE
fi

echo "$SHA256SUM  $FILE" \
  | sha256sum -c

if [ $? != 0 ]; then
  echo 'checkra1n checksum is not valid'
  exit 1
fi

chmod +x $FILE
$FILE "$@"
