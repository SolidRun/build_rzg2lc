#!/bin/bash

set -o pipefail

###############################################################################
# General configurations
###############################################################################

UBOOT_COMMIT_HASH=83b2ea37f4b2dd52accce8491af86cbb280f6774
: ${BOOTLOADER_MENU:=false}
: ${SHALLOW:=false}
: ${MACHINE:=rzg2lc-solidrun}
REPO_PREFIX=`git log -1 --pretty=format:%h`

TFA_DIR_DEFAULT='rzg_trusted-firmware-a'
UBOOT_DIR_DEFAULT='renesas-u-boot-cip'
KERNEL_DIR_DEFAULT='rz_linux-cip'

# Distribution for rootfs
# - buildroot
# - debian
: ${DISTRO:=buildroot}

## Buildroot Options
: ${BUILDROOT_VERSION:=2022.02.4}
: ${BUILDROOT_DEFCONFIG:=rzg2lc-solidrun_defconfig}
: ${BR2_PRIMARY_SITE:=} # custom buildroot mirror

## Debian Options
: ${DEBIAN_VERSION:=bullseye}
: ${DEBIAN_ROOTFS_SIZE:=936M}

# Kernel Modules:
: ${INCLUDE_KERNEL_MODULES:=true}

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

for i in $TOOLS; do
	TOOL_PATH=`which $i`
	if [ "x$TOOL_PATH" == "x" ]; then
		echo "Tool $i is not installed"
		echo "If running under apt based package management you can run -"
		echo "sudo apt install $TOOLS_PACKAGES"
		exit -1
	fi
done

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
QORIQ_COMPONENTS="renesas-u-boot-cip rzg_trusted-firmware-a rz_linux-cip buildroot rzg2_flash_writer"
UBOOT_REPO='https://github.com/renesas-rz/renesas-u-boot-cip -b v2021.10/rz'
ATF_REPO='https://github.com/renesas-rz/rzg_trusted-firmware-a -b v2.7/rz'
LINUX_REPO='https://github.com/renesas-rz/rz_linux-cip -b rz-5.10-cip22-rt9'
BUILDROOT_REPO="https://github.com/buildroot/buildroot.git -b $BUILDROOT_VERSION"
FLASH_WRITER_REPO='https://github.com/renesas-rz/rzg2_flash_writer -b rz_g2l'

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
	# Clone Flash writer
    if [ "x$i" == "xrzg2_flash_writer" ]; then
      git clone $SHALLOW_FLAG $FLASH_WRITER_REPO
    fi

		# Apply patches...
		echo "Checking patches for ${i}"
		if [ -d "${ROOTDIR}/patches/${i}" ]; then
			cd ${ROOTDIR}/build/${i}
			for patch in "${ROOTDIR}/patches/${i}"/*.patch; do
				echo "Applying $patch ..."
				test -e .git && git am "$patch"
				test -e .git || patch -p1 < $patch

				if [ $? -ne 0 ]; then
					echo "Error: Failed to apply $patch!"
					exit 1
				fi
			done
		fi

	fi
done

# we don't have status code checks for each step - use "-e" with a trap instead
function error() {
	status=$?
	printf "ERROR: Line %i failed with status %i: %s\n" $BASH_LINENO $status "$BASH_COMMAND" >&2
	exit $status
}
trap error ERR
set -e

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
	make mrproper
	make O=.out $UBOOT_DEFCONFIG
	make -j$(nproc) O=.out
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
	cp build/${PLATFORM}/release/bl2_bp.bin ${OUTPUT_BOOTLOADER_DIR}/bl2_bp-${MACHINE}.bin
	\cp -r ${OUTPUT_BOOTLOADER_DIR}/* $ROOTDIR/images/tmp/
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
LINUX_DEFCONFIG="rzg2lc-solidrun_defconfig"
cd $ROOTDIR/build/rz_linux-cip
cp $ROOTDIR/configs/linux/$LINUX_DEFCONFIG arch/arm64/configs
make $LINUX_DEFCONFIG
make -j$PARALLEL Image dtbs modules
cp $ROOTDIR/build/rz_linux-cip/arch/arm64/boot/Image $ROOTDIR/images/tmp/
cp $ROOTDIR/build/rz_linux-cip/arch/arm64/boot/dts/renesas/*smarc.dtb $ROOTDIR/images/tmp/
cp $ROOTDIR/build/rz_linux-cip/arch/arm64/boot/dts/renesas/rzg2l*.dtb $ROOTDIR/images/tmp/
rm -rf ${ROOTDIR}/images/tmp/modules # remove old modules
make -j${PARALLEL} INSTALL_MOD_PATH="${ROOTDIR}/images/tmp/modules" modules_install
# ref -> r9a07g044c2-smarc.dtb-> (r9a07g044c2.dtsi -> r9a07g044.dtsi) &
# (rzg2lc-smarc.dtsi ->
# <dt-bindings/gpio/gpio.h>
# <dt-bindings/pinctrl/rzg2l-pinctrl.h>#include "rzg2lc-smarc-som.dtsi"
# "rzg2lc-smarc-pinfunction.dtsi"
# "rz-smarc-common.dtsi")

###############################################################################
# Building FS Builroot/Debian
###############################################################################

do_build_buildroot() {
	echo "================================="
	echo "*** Building Buildroot FS..."
	echo "================================="
	cd $ROOTDIR/build/buildroot
	cp $ROOTDIR/configs/buildroot/rzg2lc-solidrun_defconfig $ROOTDIR/build/buildroot/configs
	make ${BUILDROOT_DEFCONFIG}
	make -j$PARALLEL
	cp $ROOTDIR/build/buildroot/output/images/rootfs* $ROOTDIR/images/tmp/
	# Preparing initrd
	mkimage -A arm64 -O linux -T ramdisk -C gzip -d $ROOTDIR/images/tmp/rootfs.cpio.gz $ROOTDIR/images/tmp/initrd.img
}

do_build_debian() {
	echo "================================="
	echo "*** Building Debian FS..."
	echo "================================="
	mkdir -p $ROOTDIR/build/debian
	cd $ROOTDIR/build/debian

	# (re-)generate only if rootfs doesn't exist or runme script has changed
	if [ ! -f rootfs.e2.orig ] || [[ ${ROOTDIR}/${BASH_SOURCE[0]} -nt rootfs.e2.orig ]]; then
		rm -f rootfs.e2.orig

		# bootstrap a first-stage rootfs
		rm -rf stage1
		fakeroot debootstrap --variant=minbase \
			--arch=arm64 --components=main,contrib,non-free \
			--foreign \
			--include=apt-transport-https,busybox,ca-certificates,can-utils,command-not-found,chrony,curl,e2fsprogs,ethtool,fdisk,gpiod,haveged,i2c-tools,ifupdown,iputils-ping,isc-dhcp-client,initramfs-tools,libiio-utils,lm-sensors,locales,nano,net-tools,ntpdate,openssh-server,psmisc,rfkill,sudo,systemd-sysv,tio,usbutils,wget,xterm,xz-utils \
			${DEBIAN_VERSION} \
			stage1 \
			https://deb.debian.org/debian

		# prepare init-script for second stage inside VM
		cat > stage1/stage2.sh << EOF
#!/bin/sh

# run second-stage bootstrap
/debootstrap/debootstrap --second-stage

# mount pseudo-filesystems
mount -vt proc proc /proc
mount -vt sysfs sysfs /sys

# configure dns
cat /proc/net/pnp > /etc/resolv.conf

# set empty root password
passwd -d root

# update command-not-found db
apt-file update
update-command-not-found

# enable optional system services
# none yet ...

# populate fstab
printf "/dev/root / ext4 defaults 0 1\\n" > /etc/fstab

# delete self
rm -f /stage2.sh

# flush disk
sync

# power-off
reboot -f
EOF
		chmod +x stage1/stage2.sh

		# create empty partition image
		dd if=/dev/zero of=rootfs.e2.orig bs=1 count=0 seek=${DEBIAN_ROOTFS_SIZE}

		# create filesystem from first stage
		mkfs.ext2 -L rootfs -E root_owner=0:0 -d stage1 rootfs.e2.orig

		# bootstrap second stage within qemu
		qemu-system-aarch64 \
			-m 1G \
			-M virt \
			-cpu cortex-a57 \
			-smp 1 \
			-netdev user,id=eth0 \
			-device virtio-net-device,netdev=eth0 \
			-drive file=rootfs.e2.orig,if=none,format=raw,id=hd0 \
			-device virtio-blk-device,drive=hd0 \
			-nographic \
			-no-reboot \
			-kernel "${ROOTDIR}/images/tmp/Image" \
			-append "console=ttyAMA0 root=/dev/vda rootfstype=ext2 ip=dhcp rw init=/stage2.sh" \

		:

		# convert to ext4
		tune2fs -O extents,uninit_bg,dir_index,has_journal rootfs.e2.orig
	fi;

	# export final rootfs for next steps
	cp rootfs.e2.orig "${ROOTDIR}/images/tmp/rootfs.ext4"

	# apply overlay (configuration + data files only - can't "chmod +x")
	find "${ROOTDIR}/overlay/${DISTRO}" -type f -printf "%P\n" | e2cp -G 0 -O 0 -s "${ROOTDIR}/overlay/${DISTRO}" -d "${ROOTDIR}/images/tmp/rootfs.ext4:" -a
}

# BUILD selected Distro buildroot/debian
do_build_${DISTRO}

###############################################################################
# Building Flash Writer
###############################################################################
echo "================================="
echo "*** Building Flash Writer"
echo "================================="
cd $ROOTDIR/build/rzg2_flash_writer
FLASH_WRITER_BUILD_ARGS="DEVICE=RZG2LC DDR_TYPE=DDR4 DDR_SIZE=1GB_1PCS SWIZZLE=T3BC FILENAME_ADD=_RZG2LC_HUMMINGBOARD"
make $FLASH_WRITER_BUILD_ARGS -f makefile.linaro
cp ./AArch64_output/Flash_Writer_SCIF_RZG2LC_HUMMINGBOARD_DDR4_1GB_1PCS.mot $ROOTDIR/images

###############################################################################
# Assembling Boot Image
###############################################################################
echo "================================="
echo "Assembling Boot Image"
echo "================================="
cd $ROOTDIR/images/
IMG=rzg2lc_solidrun_${DISTRO}-sd-${REPO_PREFIX}.img
rm -rf $ROOTDIR/images/${IMG}
IMAGE_BOOTPART_SIZE_MB=150 # bootpart size = 150MiB
IMAGE_BOOTPART_SIZE=$((IMAGE_BOOTPART_SIZE_MB*1024*1024)) # Convert megabytes to bytes 
IMAGE_ROOTPART_SIZE=`stat -c "%s" tmp/rootfs.ext4`
IMAGE_ROOTPART_SIZE_MB=$(($IMAGE_ROOTPART_SIZE / (1024 * 1024) )) # Convert bytes to megabytes
IMAGE_SIZE=$((IMAGE_BOOTPART_SIZE+IMAGE_ROOTPART_SIZE+2*1024*1024))  # additional 2M at the end
IMAGE_SIZE_MB=$(echo "$IMAGE_SIZE / (1024 * 1024)" | bc) # Convert bytes to megabytes
dd if=/dev/zero of=${IMG} bs=1M count=${IMAGE_SIZE_MB}

# Make extlinux configuration file
cat > $ROOTDIR/images/tmp/extlinux.conf << EOF
	timeout 30
	default linux
	menu title RZ/G2* boot options
	label primary
	menu label primary kernel
		linux /boot/Image
		fdtdir /boot/
		APPEND console=serial0,115200 console=ttySC0 root=/dev/mmcblk0p2 rw rootwait
EOF

# Boot Partion (FAT Partion)
dd if=/dev/zero of=tmp/part1.fat32 bs=1M count=$((IMAGE_BOOTPART_SIZE_MB-2))
env PATH="$PATH:/sbin:/usr/sbin" mkdosfs tmp/part1.fat32
mmd -i tmp/part1.fat32 ::/extlinux
mmd -i tmp/part1.fat32 ::/boot
mcopy -i tmp/part1.fat32 $ROOTDIR/images/tmp/Image ::/boot/Image
mcopy -s -i tmp/part1.fat32 $ROOTDIR/images/tmp/*.dtb ::/boot/
mcopy -s -i tmp/part1.fat32 $ROOTDIR/images/tmp/initrd.img ::/boot/initrd.img
mcopy -i tmp/part1.fat32 $ROOTDIR/images/tmp/extlinux.conf ::/extlinux/extlinux.conf

# EXT4 Partion
ROOTFS=$ROOTDIR/images/tmp/rootfs.ext4
e2mkdir -G 0 -O 0 ${ROOTFS}:extlinux
#e2cp -G 0 -O 0 $ROOTDIR/images/tmp/extlinux.conf ${ROOTFS}:extlinux/
e2mkdir -G 0 -O 0 ${ROOTFS}:boot
e2cp -G 0 -O 0 $ROOTDIR/images/tmp/Image ${ROOTFS}:/boot/
e2cp -G 0 -O 0 $ROOTDIR/images/tmp/*.dtb ${ROOTFS}:/boot/

if [ "x${INCLUDE_KERNEL_MODULES}" = "xtrue" ]; then
	echo "copying kernel modules ..."
	find "${ROOTDIR}/images/tmp/modules/lib/modules" -type f -not -name "*.ko*" -printf "%P\n" | e2cp -G 0 -O 0 -P 644 -s "${ROOTDIR}/images/tmp/modules/lib/modules" -d "${ROOTDIR}/images/tmp/rootfs.ext4:lib/modules" -a
	find "${ROOTDIR}/images/tmp/modules/lib/modules" -type f -name "*.ko*" -printf "%P\n" | e2cp -G 0 -O 0 -P 644 -s "${ROOTDIR}/images/tmp/modules/lib/modules" -d "${ROOTDIR}/images/tmp/rootfs.ext4:lib/modules" -a -v
	# TODO: create symlink  /lib/modules/ -> /usr/lib/modules/
	# ln -s /usr/lib/modules/ /lib/modules/
fi

# EXT partion
env PATH="$PATH:/sbin:/usr/sbin" parted --script ${IMG} mklabel msdos mkpart primary 2MiB ${IMAGE_BOOTPART_SIZE_MB}MiB mkpart primary ${IMAGE_BOOTPART_SIZE_MB}MiB $((IMAGE_SIZE_MB - 1))MiB
dd if=tmp/part1.fat32 of=${IMG} bs=1M seek=2 conv=notrunc
dd if=${ROOTFS} of=${IMG} bs=1M seek=${IMAGE_BOOTPART_SIZE_MB} conv=notrunc
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
