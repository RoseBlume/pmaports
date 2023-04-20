setenv bootargs 'console=tty1 console=ttyMSM0,115200n8 loglevel=15 clk_ignore_unused'

bootm $prevbl_initrd_start_addr
