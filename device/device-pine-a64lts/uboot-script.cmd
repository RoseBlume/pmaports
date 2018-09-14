setenv bootargs init=/init.sh rw console=tty0 console=ttyS0,115200 no_console_suspend earlycon=uart,mmio32,0x01c28000 panic=10 consoleblank=0 loglevel=1 PMOS_NO_OUTPUT_REDIRECT

printenv

echo Loading DTB
load mmc ${mmc_bootdev}:1 ${fdt_addr_r} dtb-pine-a64lts.dtb

echo Loading Initramfs
load mmc ${mmc_bootdev}:1 ${ramdisk_addr_r} uInitrd-pine-a64lts

echo Loading Kernel
load mmc ${mmc_bootdev}:1 ${kernel_addr_r} vmlinuz-pine-a64lts-dtb

echo Resizing FDT
fdt addr ${fdt_addr_r}
fdt resize

echo Booting kernel
booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
