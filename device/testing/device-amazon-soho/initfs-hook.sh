#!/bin/sh

echo 0 > /sys/devices/platform/omapdss/overlay0/enabled
echo 1 > /sys/devices/platform/omapdss/overlay0/enabled


#echo f0 > /sys/devices/omapdss/display0/gamma_ctrl # was 0
#echo 1 > /sys/devices/omapdss/display0/pwm_frame_ctrl # was 0
#echo 41 > /sys/devices/omapdss/display0/pwm_step_ctrl # was 0

#echo 1248 > /sys/devices/platform/omapdss/overlay0/screen_width # was 800
#echo 1..255 > /sys/devices/platform/omapdss/overlay0/x_decim # was 1..16
#echo 1..255 > /sys/devices/platform/omapdss/overlay0/y_decim # was 1..16
#echo 1 > /sys/devices/platform/omapdss/overlay1/enabled # was 0
#echo 800,1280 > /sys/devices/platform/omapdss/overlay1/input_size # was 0,0
#echo 800,1280 > /sys/devices/platform/omapdss/overlay1/output_size # was 0,0
#echo 1 > /sys/devices/platform/omapdss/overlay1/pre_mult_alpha # was 0
#echo 800 > /sys/devices/platform/omapdss/overlay1/screen_width # was 0
#echo 1..255 > /sys/devices/platform/omapdss/overlay1/x_decim # was 1..16
#echo 1..255 > /sys/devices/platform/omapdss/overlay1/y_decim # was 1..16
#echo 1 > /sys/devices/platform/omapdss/overlay1/zorder # was 3
#echo 1 > /sys/devices/platform/omapdss/overlay2/enabled # was 0
#echo 800,36 > /sys/devices/platform/omapdss/overlay2/input_size # was 0,0
#echo 800,36 > /sys/devices/platform/omapdss/overlay2/output_size # was 0,0
#echo 1 > /sys/devices/platform/omapdss/overlay2/pre_mult_alpha # was 0
#echo 800 > /sys/devices/platform/omapdss/overlay2/screen_width # was 0
#echo 1..255 > /sys/devices/platform/omapdss/overlay2/x_decim # was 1..16
#echo 1..255 > /sys/devices/platform/omapdss/overlay2/y_decim # was 1..16
#echo 1 > /sys/devices/platform/omapdss/overlay3/enabled # was 0
#echo 800,72 > /sys/devices/platform/omapdss/overlay3/input_size # was 0,0
#echo 800,72 > /sys/devices/platform/omapdss/overlay3/output_size # was 0,0
#echo 0,1208 > /sys/devices/platform/omapdss/overlay3/position # was 0,0
#echo 1 > /sys/devices/platform/omapdss/overlay3/pre_mult_alpha # was 0
#echo 800 > /sys/devices/platform/omapdss/overlay3/screen_width # was 0
#echo 1..255 > /sys/devices/platform/omapdss/overlay3/x_decim # was 1..16
#echo 1..255 > /sys/devices/platform/omapdss/overlay3/y_decim # was 1..16
#echo 3 > /sys/devices/platform/omapdss/overlay3/zorder # was 1
#echo > /sys/devices/platform/omapfb/graphics/fb0/mode # was U:800x1280p-56


#echo 1 > /sys/devices/platform/musb-omap2430/musb-hdrc/gadget/suspended # was 0
#echo high-speed > /sys/devices/platform/musb-omap2430/musb-hdrc/udc/musb-hdrc/current_speed # was empty
#echo 1 > /sys/devices/platform/musb-omap2430/musb-hdrc/udc/musb-hdrc/is_dualspeed # was empty
#echo high-speed > /sys/devices/platform/musb-omap2430/musb-hdrc/udc/musb-hdrc/maximum_speed # was empty

#echo 5000 > /sys/devices/platform/omap-rproc.1/rproc/remoteproc0/power/autosuspend_delay_ms # was empty

#echo 604 > /sys/devices/platform/omap_i2c.1/i2c-1/1-0049/twl6030_gpadc/in0_channel # was 4
#echo 1981 > /sys/devices/platform/omap_i2c.1/i2c-1/1-0049/twl6030_gpadc/in0_raw_code # was 1978
#echo 607 > /sys/devices/platform/omap_i2c.1/i2c-1/1-0049/twl6030_gpadc/in0_value # was 605
#echo 6 > /sys/devices/platform/omap_i2c.1/i2c-1/1-0049/twl6030_gpadc/in3_value # was 7

#echo -580686392 > /sys/devices/platform/omap_i2c.2/i2c-2/2-002c/backlight/bowser/bl_power # was -580643320

#echo 1 > /sys/devices/platform/omap_i2c.4/i2c-4/4-0068/iio:device0/buffer/enable # was 0
#echo 480 > /sys/devices/platform/omap_i2c.4/i2c-4/4-0068/iio:device0/buffer/length # was 0
#echo 1 > /sys/devices/platform/omap_i2c.4/i2c-4/4-0068/iio:device0/power_state # was 0
#echo 14 > /sys/devices/platform/omap_i2c.4/i2c-4/4-0068/iio:device0/sampling_frequency # was 50

#echo 02:7c:33:4c:4a:45 > /sys/devices/virtual/android_usb/android0/f_rndis/ethaddr # was 76:78:ec:7b:cb:b0
