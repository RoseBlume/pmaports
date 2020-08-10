#!/bin/sh
# set framebuffer resolution
echo 16 > /sys/class/graphics/fb0/bits_per_pixel
