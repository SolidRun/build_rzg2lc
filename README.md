# build_rz
# SolidRun's RZ/G2LC, RZ/G2 and RZ/V2 based build scripts

## Introduction

Main intention of this repository is to produce a reference system for RZ/G2 and RZ/V2 based products.
Automatic binary releases are available on our website [RZ_Images](https://images.solid-run.com/RZG2LC/rzg2lc_build) for download.

The build script can support two Linux distrebutions **Debian/Buildroot**.

## Source code versions

- [U-boot 2021.10](https://github.com/renesas-rz/renesas-u-boot-cip/commits/v2021.10/rz)
- [Linux kernel 5.10](https://github.com/SolidRun/u-boot/tree/v2021.10/rz-sr-cip41)
- [Buildroot 2024.02.7](https://github.com/buildroot/buildroot/tree/2024.02.7)
- [Debian bookworm](https://deb.debian.org/debian)

## Get Started

### Install developement dependencies
For Debian/Ubuntu
```
apt install git bc bison build-essential coccinelle ccache \
  device-tree-compiler dfu-util efitools flex gdisk graphviz imagemagick \
  liblz4-tool libgnutls28-dev libguestfs-tools libncurses-dev \
  libpython3-dev libsdl2-dev libssl-dev lz4 lzma lzma-alone openssl \
  pkg-config python3 python3-asteval python3-coverage python3-filelock \
  python3-pkg-resources python3-pycryptodome python3-pyelftools \
  python3-pytest python3-pytest-xdist python3-sphinxcontrib.apidoc \
  python3-sphinx-rtd-theme python3-subunit python3-testtools python3-tqdm \
  python3-virtualenv python3-libfdt swig uuid-dev u-boot-tools dosfstools \
  qemu-system-arm e2tools bmap-tools patch fakeroot debootstrap unzip rsync
```
For Fedora
```
dnf install git bc bison gcc gcc-c++ coccinelle ccache \
  dtc dfu-util flex gdisk graphviz ImageMagick  \
  lz4 lzma xz openssl-devel openssl-devel-engine \
  pkgconfig python3 python3-asteval patch fakeroot debootstrap \
  python3-coverage python3-filelock python3-pkg-resources python3-pyelftools \
  python3-pytest python3-pytest-xdist python3-sphinxcontrib-apidoc \
  python3-sphinx_rtd_theme python3-subunit python3-testtools \
  python3-virtualenv swig uuid-devel uboot-tools e2fsprogs dosfstools \
  qemu-system-aarch64 e2tools bmap-tools python3-libfdt python3-tqdm \
  perl-open perl-English perl-ExtUtils-MakeMaker perl-Thread-Queue \
  perl-FindBin perl-IPC-Cmd unzip rsync
```

### Clone repo and it's submodules
```
git clone --recurse-submodules https://github.com/SolidRun/build_rzg2lc.git
cd build_rzg2lc
```

### Build image
```
MACHINE=rzg2lc-solidrun DISTRO=buildroot ./runme.sh build
```
Available options:
```
Usage: MACHINE=[machine] DISTRO=[distro] ./runme.sh [build|clean] [target]
Targets: uboot atf kernel bootimage rswlan buildroot flashwriter image
Examples:
  ./runme.sh               # Build all targets
  ./runme.sh build uboot   # Build uboot only
  ./runme.sh clean kernel  # Clean kernel only
  ./runme.sh --help        # Show this help message
Available machines:
rzg2lc-solidrun (default), rzg2l-solidrun, rzv2l-solidrun
Available distros:
buildroot (default), debian
Available env vars:
MACHINE=rzg2l-solidrun - Machine name (default: rzg2lc-solidrun)
DISTRO=debian - Distro to build (default: buildroot)
CROSS_TOOLCHAIN=aarch64-linux-gnu- - Toolchain to use (default: download arm-gnu-toolchain-13.3)
ROOTFS_FREE_SIZE=1G - Extra rootfs free size (default: 100M)
COMPRESSION_FORMAT=zstd - if specified, image will be commpressed (zstd, xz, gzip)
```
Resulted images will be located in images/ directory

### Deploy to microSD

To get started the latest binary release under the link above can be used for creating a bootable microSD card:
Plug in a micro SD into your machine and run the following, where sdX is the location of the SD card got probed into your machine -

```
umount /media/<relevant directory>
sudo bmaptool copy images/rzg2lc*-solidrun-sd-<distro>-<hash>.img /dev/sdX
```

### Login
- **username:** root
- **password:** root


### Build with Docker
A docker image providing a consistent build environment can be used as below:

1. build container image (first time only)
   ```
   docker build -t rzg2lc_build docker
   # optional with an apt proxy, e.g. apt-cacher-ng
   # docker build --build-arg APTPROXY=http://127.0.0.1:3142 -t rzg2lc_build docker
   ```

2. invoke build script in working directory
   ```
    docker run --rm -it -v "$PWD":/work --user $(id -u):$(id -g) rzg2lc_build
    MACHINE=rzg2lc-solidrun DISTRO=buildroot ./runme.sh
   ```


---
### Boot from SD and flash eMMC
If you use **HummingBoard** Carrier board:
- set the dip switch to boot from SD (In order to configure the boot media, please refer to [HummingBoard RZ/G2L Boot Select]( https://solidrun.atlassian.net/wiki/spaces/developer/pages/411861143).)
- install same above image on USB-DISK (for mounting the Root-FS)
- connect the USB-DISK
```
sudo bmaptool copy images/rzxxxx_solidrun_buildroot-sd-xxxxxxx.img /dev/sdX
```
- stop it in U-Boot and run the commands below:
```
setenv bootargs 'rw rootwait earlycon root=/dev/sda2'
```
- enable/select eMMC to have access in Linux
```
setenv sdio_select emmc
```
- run the U-Boot command below to boot
```
run usb_boot
```
**Note:** After that step, the board will boot using the rootfs placed on the second USB drive partition.
- follow the instructions in [here](https://solidrun.atlassian.net/wiki/spaces/developer/pages/476741633/HummingBoard+RZ+family+Boot+options#Flashing-bootloaders-and-rootfs-from-Linux) to flash the eMMC.
- set the dip switch to boot from eMMC (In order to configure the boot media, please refer to [HummingBoard RZ/G2L Boot Select]( https://solidrun.atlassian.net/wiki/spaces/developer/pages/411861143).)

#### Flashing Bootloader from uSD to eMMC Boot0

Below is the **U-Boot command sequence** to **read** the bootloader from a **generated image on external media** and **write** it to **eMMC boot0**.  

This example reads from a **boot uSDHC card**, but it can be easily adapted to **read from a USB stick** by modifying the first `mmc read` command accordingly.

### **U-Boot Command Sequence**
```sh
mmc read 0x4c200000 0 0x2000 # Read bootloader image from uSD (adjust source address)
run sdio_toggle # SDIO Toggle to switch between uSD and eMMC
mmc dev 0 1  # Select eMMC device
mmc erase 0 0x2000 # Erase the bootloader region in eMMC boot0 (optional)
mmc write 0x4c200200 0x1 0x1 # Write bootloader to eMMC boot0 ->
mmc write 0x4c201000 0x2 0x78
mmc write 0x4c210000 0x100 0x1f00
```
**📌 Note:** Modify the mmc read command if sourcing the bootloader from USB instead of uSD ```usb read 0x4c200000 0 0x2000```.

---

### Booting from Network

In order to boot over ethernet, you'll need a TFTP server to serve the required files.

#### Setting a TFTP server (From a different Linux machine in the same network)

* Install tftpd, xinetd and tftp.

```
sudo apt-get install tftpd xinetd tftp
```

* Create the directory you'll use to store the booting files.

```
mkdir /path/to/boot/dir
chmod -R 777 /path/to/boot/dir
sudo chown -R nobody /path/to/boot/dir
```

* Create /etc/xinetd.d/tftp, and write in the file:

```
service tftp
{
protocol        = udp
port            = 69
socket_type     = dgram
wait            = yes
user            = nobody
server          = /usr/sbin/in.tftpd
server_args     = /path/to/boot/dir
disable         = no
}
```

> Edit /path/to/boot/dir according to your directory

* Restart service

```
sudo service xinetd restart
```

* Copy booting files into your directory

```
# Copy device tree
cp build/rz_linux-cip/arch/arm64/boot/dts/renesas/rzg2lc-hummingboard.dtb /path/to/boot/dir/

# Copy Kernel
cp build/rz_linux-cip/arch/arm64/boot/Image /path/to/boot/dir/
```

* Allow TFTP in your firewall (ufw for example)

```
sudo ufw allow tftp
```

#### Retrieving files over ethetnet.
This part assumes that you have a tftp server in the same network.

* Stop board in u-boot.

* Get IP address using dhcp command (ignore the error, we are using this command to get an IP address for a DHCP server)

```
=> dhcp
link up on port 1, speed 1000, full duplex
BOOTP broadcast 1
BOOTP broadcast 2
BOOTP broadcast 3
DHCP client bound to address <Some IP address> (X ms)
*** ERROR: `serverip' not set
Cannot autoload with TFTPGET
```

* Set the tftp server IP address.

```
setenv serverip <the.server.ip.addr>
```

* Load Linux kernel into RAM

```
setenv loadaddr ${kerenl_addr}
tftpboot Image
```

* Load DeviceTree into RAM.

```
setenv loadaddr ${dtb_addr}
tftpboot rzg2lc-hummingboard.dtb
```

* boot

```
boot
```

## Image layout
SD card layout:
| Offset  | Content          |
|---------|------------------|
| 0x200   | bootparams.bin   |
| 0x1000  | bl2.bin          |
| 0x10000 | fip.bin          |
| 0x30000 | DTS overlays     |
| 0x3c000 | u-boot env       |
| 8MB     | fat32 boot part  |
| ...     | ext4 rootfs part |

eMMC boot partition layout:
| Offset  | Content        |
|---------|----------------|
| 0x200   | bootparams.bin |
| ...     | bl2.bin        |
| 0x20000 | fip.bin        |
| 0x30000 | DTS overlays   |
| 0x3c000 | u-boot env     |
