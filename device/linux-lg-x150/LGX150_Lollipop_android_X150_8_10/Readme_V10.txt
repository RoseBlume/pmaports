1. Android build
  - Download original android source code ( LolliPop 5.0 ) from http://source.android.com
  - Untar opensource packages of file_name.tar.gz into downloaded android source directory
	a) tar -xzvf LGX150_L_android2.tar.gz
  - And, merge the source into the android source code( LolliPop 5.0 )
  - Run following scripts to build android
    a) source ./build/envsetup.sh
    b) lunch
    c) make update-api
    d) make -j4
  - When you compile the android source code, you have to add google original prebuilt source(toolchain) into the android directory.
  - After build, you can find output at out/target/product/
  
2. Kernel Build  
  - Uncompress using following command at the android directory
      tar -xzvf LGX150_L_kernel.tar.gz
  - When you compile the kernel source code, you have to add google original prebuilt source(toolchain) into the android directory.
    Please add GCC to your envionment variables
       a) export PATH=$PWD/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.8/bin:$PATH
       b) export PATH=$PWD/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin:$PATH
  - Run following script to build kernel
    a) cd kernel-3.10
    b) mkdir out
    c) make TARGET_ARCH=arm O=out v10_defconfig
    d) make TARGET_ARCH=arm O=out -j4
  - After build, you can find the build image(zImage) at out/arch/arm/boot
