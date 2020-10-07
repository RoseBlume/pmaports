#!/bin/sh

# Fix black screen
echo 1 > /sys/class/graphics/fb0/blank
echo 0 > /sys/class/graphics/fb0/blank
echo "U:720x1480p-59" > /sys/class/graphics/fb0/mode
echo 0 0 > /sys/class/graphics/fb0/pan
echo 720,2960 > /sys/class/graphics/fb0/virtual_size
echo "panel_power_on = 1" > /sys/class/graphics/fb0/show_blank_event
echo 255 > /sys/devices/soc/1a00000.qcom,mdss_mdp/1a00000.qcom,mdss_mdp\:qcom,mdss_fb_primary/leds/lcd-backlight/brightness
