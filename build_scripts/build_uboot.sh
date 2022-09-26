#!/bin/bash

#---------------------------------------------------------------------------
# Please read the README.md file first for proper setup
#---------------------------------------------------------------------------

# PLEASE CHOOSE YOU BOARD
#MACHINE=smarc-rzg2lc   # Renesas SMARC RZ/G2LC
#MACHINE=rzg2lc-solidrun   # solidrun RZ/G2LC platform

# Read in functions from build_common.sh
if [ ! -e build_common.sh ] ; then
  echo -e "\n ERROR: File \"build_common.sh\" not found\n."
  exit
else
  source build_common.sh
fi

# Read our settings (board.ini) or whatever file SETTINGS_FILE was set to
read_setting

# Define the defconfigs for Renesas boards
if [ "$MACHINE" == "rzg2lc-solidrun" ] ; then DEFCONFIG=rzg2lc-solidrun_defconfig ; fi
if [ "$MACHINE" == "smarc-rzg2lc" ] ; then DEFCONFIG=smarc-rzg2lc_defconfig ; fi

# Set the output directory (because I like all my build files separate from the source code)
OUT=.out

# Check for MACHINE setting
if [ "$MACHINE" == "" ] ; then
  echo ""
  echo "ERROR: Please set MACHINE in settings file ($SETTINGS_FILE)"
  echo ""
  exit
fi

do_toolchain_menu() {
  select_toolchain "UBOOT_TOOLCHAIN_SETUP_NAME" "UBOOT_TOOLCHAIN_SETUP"
}

# Use common toolchain if specific toolchain not set
if [ "$UBOOT_TOOLCHAIN_SETUP_NAME" == "" ] ; then
  if [ "$COMMON_TOOLCHAIN_SETUP_NAME" != "" ] ; then
    UBOOT_TOOLCHAIN_SETUP_NAME=$COMMON_TOOLCHAIN_SETUP_NAME
    UBOOT_TOOLCHAIN_SETUP=$COMMON_TOOLCHAIN_SETUP
  else
    whiptail --msgbox "Please select a Toolchain" 0 0 0
    do_toolchain_menu
    save_setting UBOOT_TOOLCHAIN_SETUP_NAME "\"$UBOOT_TOOLCHAIN_SETUP_NAME\""
    save_setting UBOOT_TOOLCHAIN_SETUP "\"$UBOOT_TOOLCHAIN_SETUP\""
  fi
fi

# NOTE: You will get many warnings such as
#    "warning: ISO C does not support the ‘_Float32’ type"
#    "warning: ISO C does not support the ‘_Float64’ type"
# because '_GNU_SOURCE' is defined.
#   tools/Makefile:# Define _GNU_SOURCE to obtain the getline prototype from stdio.h
# When '_GNU_SOURCE' is defined, '__USE_GNU' gets defined in "features.h" and "regex.h"
# When '__USE_GNU' is defined, __GLIBC_USE_IEC_60559_TYPES_EXT gets defined to 1 in "libc-header-start.h"
# When '__GLIBC_USE_IEC_60559_TYPES_EXT' is defined, _Float32 is used in "stdlib.h"


#PATH=/opt/linaro/gcc-linaro-7.5.0-2019.12-x86_64_aarch64-linux-gnu/bin:$PATH
#export CROSS_COMPILE="aarch64-linux-gnu-"
#export ARCH=arm64

# Check for Yocto SDK setup
#if [ "$TARGET_PREFIX" == "" ] && [ "$CROSS_COMPILE" == "" ] ; then
#  echo "Yocto SDK environment not set up"
#  echo "source /opt/poky/2.4.3/environment-setup-aarch64-poky-linux"
#  exit
#fi

echo "$UBOOT_TOOLCHAIN_SETUP"
eval $UBOOT_TOOLCHAIN_SETUP

# As for GCC 4.9, you can get a colorized output
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# Find out how many CPU processor cores we have on this machine
# so we can build faster by using multithreaded builds
NPROC=2
if [ "$(which nproc)" != "" ] ; then  # make sure nproc is installed
  NPROC=$(nproc)
fi
BUILD_THREADS=$(expr $NPROC + $NPROC)

# Let the Makefile handle setting up the CFLAGS and LDFLAGS as it is a standalone application
unset CFLAGS
unset CPPFLAGS
unset LDFLAGS
unset AS
unset LD

# Having these set (by the Yocto SDK)  will break "menuconfig"
unset PKG_CONFIG_PATH
unset HOST_EXTRACFLAGS

# Add '-s' for silent Build
MAKE="make -j$BUILD_THREADS O=$OUT"

# While the Yocto SDK setup script (environment-setup-aarch64-poky-linux) sets CC, and includes
# the --sysroot parameter, we have to explictly put CC= on the make command line because of how
# the u-boot Makefile was written and looks for thigns like libgcc.a
if [ "$TARGET_PREFIX" != "" ] ; then
	# Yocto SDK Toolchain build
	MAKE="make CC=\""$CC"\" -j$BUILD_THREADS O=$OUT"
fi

echo "cd $UBOOT_DIR"
cd $UBOOT_DIR

# If this is the first time building, we need to configure first
if [ ! -e "$OUT/.config" ] ; then

  if [ "$DEFCONFIG" == "" ] ; then
    echo ""
    echo "ERROR: Please set DEFCONFIG in settings file ($SETTINGS_FILE)"
    echo ""
    exit
  fi

  echo $MAKE $DEFCONFIG
  eval $MAKE $DEFCONFIG
fi

CMD="$MAKE $1 $2 $3"
echo $CMD
eval $CMD

# Note:
# u-boot.bin is u-boot-dtb.bin (u-boot.bin + u-boot.dtb) renamed to u-boot.bin
# u-boot.srec is just u-boot (no dtb).
# u-boot-elf.srec is u-boot + dtb

# copy to output directory
if [ -e $OUT/u-boot.bin ] && [ "$OUT_DIR" != "" ] ; then

  echo -e "\nCopying files to output directory"
  mkdir -p ../$OUT_DIR
  cp -v $OUT/u-boot.bin ../$OUT_DIR
  cp -v $OUT/u-boot.srec ../$OUT_DIR

  # Use the same filenames as the Yocto output
  #cp -v $OUT/u-boot.bin ../$OUT_DIR/u-boot-${MACHINE}.bin
  #cp -v $OUT/u-boot.srec ../$OUT_DIR//u-boot-${MACHINE}.srec
fi


# The "TFA_FIP" value comes from the settings for the Trusted Firmware-A build
if [ -e u-boot.bin ] && [ "$TFA_FIP" == "1" ] ; then
  echo -e "\n\n"
  echo -e "\t*****************************************************************"
  echo -e "\t Please rebuild Trusted Firmware-A to package u-boot with BL31 "
  echo -e "\t*****************************************************************\n"
fi
