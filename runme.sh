#!/bin/bash

set -e
set -o pipefail

###############################################################################
# General configurations
###############################################################################
BUILDROOT_VERSION=2022.02.4
UBOOT_COMMIT_HASH=83b2ea37f4b2dd52accce8491af86cbb280f6774
: ${BOOTLOADER_MENU:=false}
: ${SHALLOW:=false}
: ${MACHINE:=rzg2lc-solidrun}
REPO_PREFIX=`git log -1 --pretty=format:%h`

TFA_DIR_DEFAULT='rzg_trusted-firmware-a'
UBOOT_DIR_DEFAULT='renesas-u-boot-cip'
KERNEL_DIR_DEFAULT='rz_linux-cip'

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

#QORIQ_COMPONENTS="${TFA_DIR_DEFAULT} ${UBOOT_DIR_DEFAULT} ${KERNEL_DIR_DEFAULT} buildroot"
QORIQ_COMPONENTS="renesas-u-boot-cip rzg_trusted-firmware-a rz_linux-cip buildroot"
UBOOT_REPO='https://github.com/renesas-rz/renesas-u-boot-cip -b v2021.10/rz'
#ATF_REPO='https://github.com/renesas-rz/rzg_trusted-firmware-a -b v2.7/rz'
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

	# Apply patches...
	cd $i
	for patch in "${ROOTDIR}/patches/${i}"/*; do
		echo "Applying $patch ..."
		test -e .git && git am "$patch"
		test -e .git || patch -p1 < $patch

		if [ $? -ne 0 ]; then
			echo "Error: Failed to apply $patch!"
			exit 1
		fi
	done

	fi
done


###############################################################################
# Building bootloader
###############################################################################
echo "================================="
echo "*** Generating Bootloader...."
echo "================================="
cd $ROOTDIR/build/
if [ "x$BOOTLOADER_MENU" == "xtrue" ]; then
	# ================ Install build scripts ====== #
	cp $ROOTDIR/build_scripts/*.sh $ROOTDIR/build/
	chmod +x $ROOTDIR/build/*.sh
	\rm -rf output_*
	# Clean U-Boot Code
	# cd $ROOTDIR/build/renesas-u-boot-cip && make mrproper && make -j$(nproc) O=.out && cd -
	cd $ROOTDIR/build/*u-boot* && make mrproper && cd -
	# Select toolchain that you have:
	./build.sh s
	# build u-boot:
	./build.sh u
	# build ATF
	./build.sh t
	# copy output files
	\cp -r output_*/* $ROOTDIR/images/tmp/
else
	UBOOT_DEFCONFIG=rzg2lc-solidrun_defconfig
	OUTPUT_BOOTLOADER_DIR=$ROOTDIR/build/output_${MACHINE}
	\rm -rf ${OUTPUT_BOOTLOADER_DIR}
	mkdir -p ${OUTPUT_BOOTLOADER_DIR}
	echo "================================="
	echo "Generating U-Boot...."
	echo "================================="
	# Generate U-Boot (u-boot.bin)
	cd $ROOTDIR/build/${UBOOT_DIR_DEFAULT}
	make $UBOOT_DEFCONFIG
	make mrproper && make -j$(nproc) O=.out
	# Generate ATF (BL2 & FIP & BOOTPARMS)
	echo "================================="
	echo "Generating ATF...."
	echo "================================="
	cd $ROOTDIR/build/${TFA_DIR_DEFAULT}
	# create the fip file by combining the bl31.bin and u-boot.bin (copy the u-boot.bin in the ATF root folder)
	# cp $ROOTDIR/build/${UBOOT_DIR_DEFAULT}/.out/u-boot.bin $ROOTDIR/build/${TFA_DIR_DEFAULT}
	U_BOOT_BIN=$(find $ROOTDIR/build/${UBOOT_DIR_DEFAULT} -iname u-boot.bin)
	cp $U_BOOT_BIN $ROOTDIR/build/${TFA_DIR_DEFAULT}/
	PLATFORM=g2l
	BOARD=sr_rzg2lc_1g
	make -j32 bl2 bl31 PLAT=${PLATFORM} BOARD=${BOARD} RZG_DRAM_ECC_FULL=0 LOG_LEVEL=20 MBEDTLS_DIR=../mbedtls
	# Binaries (bl2.bin and bl31.bin) are located in the build/g2l/release|debug folder.
	cp create_bl2_with_bootparam.sh build/${PLATFORM}/release/
	cd build/${PLATFORM}/release
	chmod +x create_bl2_with_bootparam.sh
	# We have to combine bl2.bin with boot parameters, we can use this simple bash script to do that:
	./create_bl2_with_bootparam.sh
	cd $ROOTDIR/build/${TFA_DIR_DEFAULT}
	# Make the fip creation tool:
	cd tools/fiptool && make -j$(nproc) plat=${PLATFORM} && cd -
	tools/fiptool/fiptool create --align 16 --soc-fw build/${PLATFORM}/release/bl31.bin --nt-fw u-boot.bin fip.bin
	# Copy output files BL2|FIP|BOOTPARMS to ${OUTPUT_BOOTLOADER_DIR}
	cp fip.bin ${OUTPUT_BOOTLOADER_DIR}/fip-${MACHINE}.bin
	cp build/${PLATFORM}/release/bl2.bin ${OUTPUT_BOOTLOADER_DIR}/bl2-${MACHINE}.bin
	cp build/${PLATFORM}/release/bootparams.bin ${OUTPUT_BOOTLOADER_DIR}/bootparams-${MACHINE}.bin
	echo "bootloader binaries are here ${OUTPUT_BOOTLOADER_DIR}... "
	ls -la ${OUTPUT_BOOTLOADER_DIR}/
fi

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
echo "================================="
echo "*** Building Linux kernel..."
echo "================================="
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
echo "================================="
echo "*** Building Buildroot FS..."
echo "================================="
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

exit 0

### Building U-Boot & ATF
# Output files -> bootparams*.bin ; bl2-*.bin ; fip*.bin
'''
# U-Boot https://renesas.info/wiki/RZ-G/RZ-G2_BSP_Porting_uboot
cd $ROOTDIR/build/renesas-u-boot-cip && make mrproper && make -j$(nproc) O=.out && cd -
cp ./.out/u-boot.bin $ROOTDIR/build/rzg_trusted*

# ATF https://renesas.info/wiki/RZ-G/RZ-G2_BSP_Porting_ATF#Building_and_Debugging
cd $ROOTDIR/build/rzg_trusted*
# make -j$(nproc) PLAT=g2l BOARD=custom all
#make -j$(nproc) PLAT=g2l BOARD=smarc_2 all

make -j32 bl2 bl31 PLAT=g2l BOARD=sr_rzg2lc_1g RZG_DRAM_ECC_FULL=0 LOG_LEVEL=20 MBEDTLS_DIR=../mbedtls

## => Output bl2.bin
# Binaries (bl2.bin and bl31.bin) are located in the build/g2l/release|debug folder.
PLATFORM=g2l
cd build/${PLATFORM}/release
# We have to combine bl2.bin with boot parameters, we can use this simple bash script to do that:
cat <<EOF > create_bl2_with_bootparam.sh
#!/bin/bash
echo -e "\n[Creating bootparams.bin]"
SIZE=$(stat -L --printf="%s" bl2.bin)
SIZE_ALIGNED=$(expr $SIZE + 3)
SIZE_ALIGNED2=$((SIZE_ALIGNED & 0xFFFFFFFC))
SIZE_HEX=$(printf '%08x\n' $SIZE_ALIGNED2)
echo "  bl2.bin size=$SIZE, Aligned size=$SIZE_ALIGNED2 (0x${SIZE_HEX})"
STRING=$(echo \\x${SIZE_HEX:6:2}\\x${SIZE_HEX:4:2}\\x${SIZE_HEX:2:2}\\x${SIZE_HEX:0:2})
printf "$STRING" > bootparams.bin
for i in `seq 1 506`e ; do printf '\xff' >> bootparams.bin ; done
printf '\x55\xaa' >> bootparams.bin
# Combine bootparams.bin and bl2.bin into single binary
# Only if a new version of bl2.bin is created
if [ "bl2.bin" -nt "bl2_bp.bin" ] || ! [ -e "bl2_bp.bin" ] ; then
	echo -e "\n[Adding bootparams.bin to bl2.bin]"
	cat bootparams.bin bl2.bin > bl2_bp.bin
fi
EOF
chmod +x create_bl2_with_bootparam.sh
./create_bl2_with_bootparam.sh
cd -

# Make the fip creation tool:
cd tools/fiptool && make -j$(nproc) plat=g2l && cd -

# create the fip file by combining the bl31.bin and u-boot.bin (copy the u-boot.bin in the ATF root folder)
#cp $ROOTDIR/build/*u-boot*/u-boot.bin $ROOTDIR/build/rzg_trusted*/
U_BOOT_BIN=$(find $ROOTDIR/build/renesas-u-boot-cip -iname u-boot.bin)
cp $U_BOOT_BIN $ROOTDIR/build/rzg_trusted*/
tools/fiptool/fiptool create --align 16 --soc-fw build/g2l/release/bl31.bin --nt-fw u-boot.bin fip.bin

cp fip.bin build/g2l/release/bl2.bin build/g2l/release/bootparams.bin ../bootloader_files/

cd $ROOTDIR/bootloader_files/
## Outputs -> fip.bin & bl2_bp.bin & bootparams.bin
DEVICE=/dev/sda
sudo dd if=bootparams.bin of=$DEVICE bs=512 seek=1 count=1 conv=notrunc
sudo dd if=bl2.bin of=$DEVICE bs=512 seek=8 conv=notrunc
sudo dd if=fip.bin of=$DEVICE bs=512 seek=128 conv=notrunc

# bl2_bp.bin and fip.bin are the files that have to be programmed using Flash Writer.
# Actually .srec may be more handy, they can be converted by using the following commands:
${CROSS_COMPILE}objcopy -I binary -O srec --adjust-vma=0x00011E00 --srec-forceS3 bl2_bp.bin bl2_bp.srec
${CROSS_COMPILE}objcopy -I binary -O srec --adjust-vma=0x00000000 --srec-forceS3 fip.bin fip.srec

# Notes
# BL2: required to be located in eMMC boot partition 1
# FIP: stored in eMMC boot partition 1 along with BL2
# By default on Renesas evaluation boards, u-boot is set up to use boot partition 2
'''
