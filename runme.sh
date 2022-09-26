#!/bin/bash
set -e

###############################################################################
# General configurations
###############################################################################
BUILDROOT_VERSION=2022.02.4
: ${SHALLOW:=false}

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
LINUX_REPO='https://github.com/renesas-rz/rz_linux-cip -b rzg2l-cip54'
BUILDROOT_REPO="https://github.com/buildroot/buildroot.git -b $BUILDROOT_VERSION"

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
# Select toolchain that you have:
./build.sh s
# build u-boot:
./build.sh u
# build ATF
./build.sh t
# copy output files
\cp -r output_*/* $ROOTDIR/images/tmp/

exit 0
# make the SD-Image
: '
cd output_smarc-rzg2l/
sudo dd if=bootparams-smarc-rzg2l.bin of=/dev/sda seek=1 count=1
sudo dd if=bl2-smarc-rzg2l.bin of=/dev/sda seek=8
sudo dd if=fip-smarc-rzg2l.bin of=/dev/sda seek=128
sync
'

###############################################################################
# Building Linux
###############################################################################



###############################################################################
# Building FS Builroot
###############################################################################



###############################################################################
# Assembling Boot Image
###############################################################################
echo "Assembling Boot Image"
cd $ROOTDIR/
IMG=rzg2lc_solidrun-sd-${REPO_PREFIX}.img
rm -rf $ROOTDIR/images/${IMG}

# Boot loader
dd if=$ROOTDIR/images/tmp/bootparams-smarc-rzg2l.bin of=$IMG seek=1 count=1
dd if=$ROOTDIR/images/tmp/bl2-smarc-rzg2l.bin of=$IMG seek=8
dd if=$ROOTDIR/images/tmp/fip-smarc-rzg2l.bin of=$IMG seek=128
echo "$ROOTDIR/images/${IMG} ready...!"
sync
