#!/bin/sh

echo "PMOS DEBUG: kernel panic in 15s" > /dev/kmsg
sleep 15s

# Reboot immediately on panic
echo -1 > /proc/sys/kernel/panic

# Panic immediately when a hung task is detected
echo 1 > /proc/sys/kernel/hung_task_panic

# Print all tasks info on panic
echo 0 > /proc/sys/kernel/panic_print

echo "PMOS DEBUG: kernel panic now" > /dev/kmsg
echo c > /proc/sysrq-trigger

