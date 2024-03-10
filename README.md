# build_rz
# SolidRun's RZ/G2 and RZ/V2 based build scripts

## Introduction

Main intention of this repository is to produce a reference system for RZ/G2 and RZ/V2 based products.
Automatic binary releases are available on our website [RZ_Images](https://images.solid-run.com/RZG2LC/rzg2lc_build) for download.

The build script can support two Linux distrebutions **Debian/Buildroot**.

## Source code versions

- [U-boot 2021.10](https://github.com/renesas-rz/renesas-u-boot-cip/commits/v2021.10/rz)
- [Linux kernel 5.10](https://github.com/renesas-rz/rz_linux-cip/commits/rz-5.10-cip36)
- [Buildroot 2022.02.4](https://github.com/buildroot/buildroot/tree/2022.02.4)
- [Debian bullseye](https://deb.debian.org/debian)

## Get Started

### Deploy to microSD

To get started the latest binary release under the link above can be used for creating a bootable microSD card:
Plug in a micro SD into your machine and run the following, where sdX is the location of the SD card got probed into your machine -

```
umount /media/<relevant directory>
sudo dd if=images/rzg2l*-<hash>.img of=/dev/sdX
```

### Login
- **username:** root
- **password:** root

---
### Boot from SD and flash eMMC
If you use **HummingBoard** Carrier board:
- set the dip switch to boot from SD (In order to configure the boot media, please refer to [HummingBoard RZ/G2L Boot Select]( https://solidrun.atlassian.net/wiki/spaces/developer/pages/411861143).)
- install same above image on USB-DISK (for mounting the Root-FS)
- connect the USB-DISK
```
sudo dd if=images/rzxxxx_solidrun_buildroot-sd-xxxxxxx.img of=/dev/sdX bs=1M
```
- stop it in U-Boot and run the commands below:
```
setenv bootargs 'rw rootwait earlycon root=/dev/sda2'
usb start
load usb 0:1 $kernel_addr_r boot/Image
load usb 0:1 $fdt_addr_r boot/rzxxx-hummingboard.dtb
```
**Note:** make sure to choose the correct dtb file according to your device.
- enable/select eMMC to have access in Linux
```
setenv sdio_select emmc
```
- run the U-Boot command below to boot
```
booti $kernel_addr_r - $fdt_addr_r
```
**Note:** After that step, the board will boot using the rootfs placed on the second USB drive partition.
- follow the instructions in [here](https://solidrun.atlassian.net/wiki/spaces/developer/pages/476741633/HummingBoard+RZ+family+Boot+options#Flashing-bootloaders-and-rootfs-from-Linux) to flash the eMMC.
- set the dip switch to boot from eMMC (In order to configure the boot media, please refer to [HummingBoard RZ/G2L Boot Select]( https://solidrun.atlassian.net/wiki/spaces/developer/pages/411861143).)
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

## Compiling Image from Source

### Configuration Options

The build script supports several customisation options that can be applied through environment variables:

- INCLUDE_KERNEL_MODULES: include kernel modules in rootfs
   - true (default)
   - false
- DISTRO: Choose Linux distribution for rootfs
  - buildroot (default)
  - debian
- BUILDROOT_VERSION
  - 2020.02.4 (default)
- MACHINE: Choose specific cmachine name
  - rzg2lc-solidrun (default)
  - rzg2l-solidrun
- BUILDROOT_DEFCONFIG: Choose specific config file name from `config/` folder
  - rzg2lc-solidrun_defconfig (default)
  - rzg2l-solidrun_defconfig
- BR2_PRIMARY_SITE: Use specific (local) buildroot mirror
- DEBIAN_VERSION
  - bullseye (default)
- DEBIAN_ROOTFS_SIZE
  - 936M (default)
- RAMFS: Choose RAMFS or normal FS
   - true
   - false (default)
#### Example
   generating buildroot image for RZ/G2L Based platform 
   ```
   MACHINE=rzg2l-solidrun ./runme.sh
   ```
   generating debian image for RZ/G2L Based platform 
   ```
   MACHINE=rzg2l-solidrun DISTRO=debian ./runme.sh
   ```
   generating buildroot image for RZ/G2LC Based platform with RAMFS
   ```
   MACHINE=rzg2lc-solidrun RAMFS=true ./runme.sh
   ```

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
   docker run --rm -i -t -v "$PWD":/work rzg2lc_build -u $(id -u) -g $(id -g)
   # optional with local buildroot mirror
   # docker run --rm -i -t -v "$PWD":/work -e BR2_PRIMARY_SITE=http://127.0.0.1/buildroot rzg2lc_build -u $(id -u) -g $(id -g)
   ```

#### rootless Podman

Due to the way podman performs user-id mapping, the root user inside the container (uid=0, gid=0) will be mapped to the user running podman (e.g. 1000:100).
Therefore in order for the build directory to be owned by current user, `-u 0 -g 0` have to be passed to *docker run*.

### Build with host tools (on Host OS)

Simply running `./runme.sh`, it will check for required tools, clone and build images and place results in images/ directory.
- ```MACHINE=rzg2l-solidrun DISTRO=debian ./runme.sh```
- ```MACHINE=rzg2lc-solidrun DISTRO=buildroot ./runme.sh```
  
**Note:** This can only work on Debian-based host, and has been tested only on Ubuntu 20.04.

## Build-Time Configuration Options

several options influencing the build are supported by the runme script, and can be specified as environment variables for a native build, or by using the `-e` option with docker:

- BUILDROOT_VERSION: Download and compile a specific release of buildroot
- BR2_PRIMARY_SITE: Use specific (local) buildroot mirror
