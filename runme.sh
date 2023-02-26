#!/bin/bash
set -e

###############################################################################
# General configurations
###############################################################################
BUILDROOT_VERSION=2022.02.4
UBOOT_COMMIT_HASH=83b2ea37f4b2dd52accce8491af86cbb280f6774
: ${SHALLOW:=false}
REPO_PREFIX=`git log -1 --pretty=format:%h`

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

QORIQ_COMPONENTS="renesas-u-boot-cip rzg_trusted-firmware-a rz_linux-cip buildroot"
UBOOT_REPO='https://github.com/renesas-rz/renesas-u-boot-cip -b v2021.10/rz'
ATF_REPO='https://github.com/renesas-rz/rzg_trusted-firmware-a -b v2.6/rz'
LINUX_REPO='https://github.com/renesas-rz/rz_linux-cip -b rz-5.10-cip22-rt9'
BUILDROOT_REPO="https://github.com/buildroot/buildroot.git -b $BUILDROOT_VERSION"

#├── build_dir
#│   ├── renesas-u-boot-cip/        <<<<<<
#│   ├── rzg_trusted-firmware-a/    <<<<<<
#│   ├── rz_linux-cip/              <<<<<<
#│   ├── buildroot/                 <<<<<<
#│   ├── build.sh
#│   ├── build_xxxx.sh
#│   ├── build_xxxx.sh

if [ "x$SHALLOW" == "xtrue" ]; then
	SHALLOW_FLAG="--depth 1000"
fi

for i in $QORIQ_COMPONENTS; do
	if [[ ! -d $ROOTDIR/build/$i ]]; then
		echo "$i source code clonig ..."
		cd $ROOTDIR/build
    # ================ Clone U-Boot =========== #
		if [ "x$i" == "xrenesas-u-boot-cip" ]; then
			git clone $SHALLOW_FLAG $UBOOT_REPO
			cd $ROOTDIR/build/renesas-u-boot-cip && git checkout $UBOOT_COMMIT_HASH
			cd $ROOTDIR/build/
		fi
    # ================ Clone ATF ============= #
    if [ "x$i" == "xrzg_trusted-firmware-a" ]; then
      git clone $SHALLOW_FLAG $ATF_REPO
    fi
    # ================ Clone Linux =========== #
    if [ "x$i" == "xrz_linux-cip" ]; then
      git clone $SHALLOW_FLAG $LINUX_REPO
    fi
    # Clone Buildroot
    if [ "x$i" == "xbuildroot" ]; then
      git clone $SHALLOW_FLAG $BUILDROOT_REPO
    fi

    # Applay patches...
		cd $i
    if [ -f $ROOTDIR/patches/${i}/*.patch ]; then
		     git am $ROOTDIR/patches/${i}/*.patch
    fi
	fi
done


###############################################################################
# Building boot loader
###############################################################################
echo "Building boot loader..."
cd $ROOTDIR/build/
# ================ Install build scripts ====== #
cp $ROOTDIR/build_scripts/*.sh $ROOTDIR/build/
chmod +x $ROOTDIR/build/*.sh
\rm -rf output_*
# Clean U-Boot Code
cd $ROOTDIR/build/*u-boot* && make mrproper && cd -
# Select toolchain that you have:
./build.sh s
# build u-boot:
./build.sh u
# build ATF
./build.sh t
# copy output files
\cp -r output_*/* $ROOTDIR/images/tmp/

# make the SD-Image
cd $ROOTDIR/images/
BOOT_IMG=rzg2lc_solidrun-sd-bootloader-${REPO_PREFIX}.img
rm -rf $ROOTDIR/images/${BOOT_IMG}
dd if=/dev/zero of=${BOOT_IMG} bs=1M count=1

# Boot loader
if [ -f tmp/bootparams-rzg2lc-solidrun.bin ] && [ -f tmp/bl2-rzg2lc-solidrun.bin ] && [ -f tmp/fip-rzg2lc-solidrun.bin ]; then
  echo "Find Solidrun boot files..."; sleep 1
  dd if=$ROOTDIR/images/tmp/bootparams-rzg2lc-solidrun.bin of=$BOOT_IMG bs=512 seek=1 count=1 conv=notrunc
  dd if=$ROOTDIR/images/tmp/bl2-rzg2lc-solidrun.bin of=$BOOT_IMG bs=512 seek=8 conv=notrunc
  dd if=$ROOTDIR/images/tmp/fip-rzg2lc-solidrun.bin of=$BOOT_IMG bs=512 seek=128 conv=notrunc
else
  dd if=$ROOTDIR/images/tmp/bootparams-smarc-rzg2lc.bin of=$BOOT_IMG bs=512 seek=1 count=1 conv=notrunc
  dd if=$ROOTDIR/images/tmp/bl2-smarc-rzg2lc.bin of=$BOOT_IMG bs=512 seek=8 conv=notrunc
  dd if=$ROOTDIR/images/tmp/fip-smarc-rzg2lc.bin of=$BOOT_IMG bs=512 seek=128 conv=notrunc
fi
echo "SD booloader image ready -> images/$BOOT_IMG"

#exit 0
###############################################################################
# Building Linux
###############################################################################
echo "*** Building Linux kernel"
cd $ROOTDIR/build/rz_linux-cip
make defconfig
./scripts/kconfig/merge_config.sh .config $ROOTDIR/configs/linux/kernel.extra
make -j$PARALLEL Image dtbs
cp $ROOTDIR/build/rz_linux-cip/arch/arm64/boot/Image $ROOTDIR/images/tmp/
cp $ROOTDIR/build/rz_linux-cip/arch/arm64/boot/dts/renesas/*smarc.dtb $ROOTDIR/images/tmp/
cp $ROOTDIR/build/rz_linux-cip/arch/arm64/boot/dts/renesas/rzg2l*.dtb $ROOTDIR/images/tmp/
# ref -> r9a07g044c2-smarc.dtb-> (r9a07g044c2.dtsi -> r9a07g044.dtsi) &
# (rzg2lc-smarc.dtsi ->
# <dt-bindings/gpio/gpio.h>
# <dt-bindings/pinctrl/rzg2l-pinctrl.h>#include "rzg2lc-smarc-som.dtsi"
# "rzg2lc-smarc-pinfunction.dtsi"
# "rz-smarc-common.dtsi")

###############################################################################
# Building FS Builroot
###############################################################################
echo "*** Building Buildroot FS"
cd $ROOTDIR/build/buildroot
cp $ROOTDIR/configs/buildroot/rzg2lc-solidrun_defconfig $ROOTDIR/build/buildroot/configs
make rzg2lc-solidrun_defconfig
make -j$PARALLEL
cp $ROOTDIR/build/buildroot/output/images/rootfs* $ROOTDIR/images/tmp/

###############################################################################
# Assembling Boot Image
###############################################################################
echo "Assembling Boot Image"
cd $ROOTDIR/images/
IMG=rzg2lc_solidrun-sd-${REPO_PREFIX}.img
rm -rf $ROOTDIR/images/${IMG}
dd if=/dev/zero of=${IMG} bs=1M count=401

# FAT Partion
dd if=/dev/zero of=tmp/part1.fat32 bs=1M count=148
env PATH="$PATH:/sbin:/usr/sbin" mkdosfs tmp/part1.fat32
# mmd -i tmp/part1.fat32 ::/boot
mcopy -i tmp/part1.fat32 $ROOTDIR/images/tmp/Image ::/Image
mcopy -s -i tmp/part1.fat32 $ROOTDIR/images/tmp/*.dtb ::/

# EXT partion
env PATH="$PATH:/sbin:/usr/sbin" parted --script ${IMG} mklabel msdos mkpart primary 2MiB 150MiB mkpart primary 150MiB 400MiB
dd if=tmp/part1.fat32 of=${IMG} bs=1M seek=2 conv=notrunc
dd if=$ROOTDIR/build/buildroot/output/images/rootfs.ext2 of=${IMG} bs=1M seek=150 conv=notrunc
# Boot loader
if [ -f tmp/bootparams-rzg2lc-solidrun.bin ] && [ -f tmp/bl2-rzg2lc-solidrun.bin ] && [ -f tmp/fip-rzg2lc-solidrun.bin ]; then
  echo "Find Solidrun boot files..."; sleep 1
  dd if=$ROOTDIR/images/tmp/bootparams-rzg2lc-solidrun.bin of=$IMG bs=512 seek=1 count=1 conv=notrunc
  dd if=$ROOTDIR/images/tmp/bl2-rzg2lc-solidrun.bin of=$IMG bs=512 seek=8 conv=notrunc
  dd if=$ROOTDIR/images/tmp/fip-rzg2lc-solidrun.bin of=$IMG bs=512 seek=128 conv=notrunc
else
  dd if=$ROOTDIR/images/tmp/bootparams-smarc-rzg2lc.bin of=$IMG bs=512 seek=1 count=1 conv=notrunc
  dd if=$ROOTDIR/images/tmp/bl2-smarc-rzg2lc.bin of=$IMG bs=512 seek=8 conv=notrunc
  dd if=$ROOTDIR/images/tmp/fip-smarc-rzg2lc.bin of=$IMG bs=512 seek=128 conv=notrunc
fi
echo -e "\n\n*** Image is ready - images/${IMG}"
sync
