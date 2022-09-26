#!/bin/bash
set -e

###############################################################################
# General configurations
###############################################################################
BUILDROOT_VERSION=2020.02.1

ROOTDIR=`pwd`
#\rm -rf $ROOTDIR/images/tmp
mkdir -p build images/tmp/boot
PARALLEL=$(getconf _NPROCESSORS_ONLN) # Amount of parallel jobs for the builds
TOOLS="tar git make 7z dd mkfs.ext4 parted mkdosfs mcopy dtc iasl mkimage e2cp truncate qemu-system-aarch64 cpio rsync bc bison flex python unzip pandoc meson ninja depmod"
TOOLS_PACKAGES="build-essential git dosfstools e2fsprogs parted sudo mtools p7zip p7zip-full device-tree-compiler acpica-tools u-boot-tools e2tools qemu-system-arm libssl-dev cpio rsync bc bison flex python unzip pandoc meson ninja-build kmod"

export PATH=$ROOTDIR/build/toolchain/gcc-arm-11.2-2022.02-x86_64-aarch64-none-elf/bin:$PATH
export CROSS_COMPILE=aarch64-none-elf-
export ARCH=arm64

echo "Checking all required tools are installed"

set +e
for i in $TOOLS; do
	TOOL_PATH=`which $i`
	if [ "x$TOOL_PATH" == "x" ]; then
		echo "Tool $i is not installed"
		echo "If running under apt based package management you can run -"
		echo "sudo apt install $TOOLS_PACKAGES"
		exit -1
	fi
done
set -e

# Check if git is configured
GIT_CONF=`git config user.name || true`
if [ "x$GIT_CONF" == "x" ]; then
	echo "git is not configured! using fake email and username ..."
	export GIT_AUTHOR_NAME="SolidRun rzg2l_build Script"
	export GIT_AUTHOR_EMAIL="support@solid-run.com"
	export GIT_COMMITTER_NAME="${GIT_AUTHOR_NAME}"
	export GIT_COMMITTER_EMAIL="${GIT_AUTHOR_EMAIL}"
fi

if [[ ! -d $ROOTDIR/build/toolchain ]]; then
	mkdir -p $ROOTDIR/build/toolchain
	cd $ROOTDIR/build/toolchain
	wget https://developer.arm.com/-/media/Files/downloads/gnu/11.2-2022.02/binrel/gcc-arm-11.2-2022.02-x86_64-aarch64-none-elf.tar.xz
	tar -xvf gcc-arm-11.2-2022.02-x86_64-aarch64-none-elf.tar.xz
fi

cd $ROOTDIR
###############################################################################
# Source code clonig
###############################################################################
BOOT_LOADER_DDIR='./sd_boot'
if ! [[ -d build/$BOOT_LOADER_DDIR ]]; then
  echo "Source code clonig..."
  # ================ Clone Sources =========== #

  # ================ Clone ATF =========== #
  mkdir -p build/$BOOT_LOADER_DDIR
  cd build/$BOOT_LOADER_DDIR
  git clone -b v2.6/rz https://github.com/renesas-rz/rzg_trusted-firmware-a
  cd rzg_trusted-firmware-a
  wget https://raw.githubusercontent.com/seebe/rzg_stuff/master/tfa_patches/0001-SD-boot-support.patch
  patch -p1 < 0001-SD-boot-support.patch
  cd ..

  # ================ Clone U-Boot =========== #
  git clone -b v2021.10/rz https://github.com/renesas-rz/renesas-u-boot-cip

  # ================ Install help scripts ====== #
  cp $ROOTDIR/build_scripts/*.sh $ROOTDIR/build/$BOOT_LOADER_DDIR
  chmod +x $ROOTDIR/build/${BOOT_LOADER_DDIR}/*.sh

fi

### For debug
cp $ROOTDIR/build_scripts/*.sh $ROOTDIR/build/$BOOT_LOADER_DDIR
chmod +x $ROOTDIR/build/${BOOT_LOADER_DDIR}/*.sh
####

###############################################################################
# Building boot loader
###############################################################################
echo "Building boot loader..."
cd $ROOTDIR/build/$BOOT_LOADER_DDIR
# Select toolchain that you have:
./build.sh s
# build u-boot:
./build.sh u
# build ATF
./build.sh t
# copy bin files
cp -i output_rzg2lc*/* $ROOTDIR/images/tmp/



# make the SD-Image
: '
cd output_smarc-rzg2l/
sudo dd if=bootparams-smarc-rzg2l.bin of=/dev/sda seek=1 count=1
sudo dd if=bl2-smarc-rzg2l.bin of=/dev/sda seek=8
sudo dd if=fip-smarc-rzg2l.bin of=/dev/sda seek=128
sync
'
