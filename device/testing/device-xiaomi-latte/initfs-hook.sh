#!/bin/sh

# set usb properties(pulled from twrp_latte.img)
# @see example from device-samsung-i9070
echo 0 > /sys/class/android_usb/android0/enable
echo Xiaomi > /sys/class/android_usb/android0/iManufacturer
echo MI PAD 2 > /sys/class/android_usb/android0/iProduct
echo 8087 > /sys/class/android_usb/android0/idVendor
echo 09ef > /sys/class/android_usb/android0/idProduct
echo 1 > /sys/class/android_usb/android0/enable

