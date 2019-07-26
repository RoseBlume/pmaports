#!/bin/sh

# Enable display
echo 0 > /sys/class/graphics/fb0/blank
echo 1 > /sys/class/leds/lm3532\:\:backlight/brightness
