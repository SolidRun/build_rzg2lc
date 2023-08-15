# build_rzg2l
# SolidRun's RZ/G2L & RZ/G2LC based build scripts

## Introduction

Main intention of this repository is to produce a reference system for RZ/G2L & RZ/G2LC based products.
Automatic binary releases are available on our website [RZ/G2LC](https://images.solid-run.com/RZG2LC) & [RZ/G2L](https://images.solid-run.com/RZG2L) for download.

The build script can support two Linux distrebutions **Debian/Buildroot**.

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
- connect the USB-DISJ t the lower USB interface
- stop it in U-Boot and run the commands below:
```
setenv bootargs 'root=/dev/sda2 rootwait'; mmc dev 0; fatload mmc 0:1 0x48080000 Image; fatload mmc 0:1 0x48000000 rzg2lc-hummingboard.dtb;
```
- set the dip switch S3 to enable the eMMC -> **S3** = {1-5:N/C, **6:off**}
- run the U-Boot command below to boot
```
booti 0x48080000 - 0x48000000
```
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

## Source code versions

- [U-boot 2021.10](https://github.com/renesas-rz/renesas-u-boot-cip/commits/v2021.10/rz)
- [Linux kernel 5.10](https://github.com/renesas-rz/rz_linux-cip/commits/rz-5.10-cip22-rt9)
- [Buildroot 2022.02.4](https://github.com/buildroot/buildroot/tree/2022.02.4)
- [Debian bullseye](https://deb.debian.org/debian)

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
   - true (default)
   - false
#### Example
   generating buildroot image for RZ/G2L Based platform 
   ```
   MACHINE=rzg2l-solidrun ./runme.sh
   ```
   generating debian image for RZ/G2L Based platform 
   ```
   MACHINE=rzg2l-solidrun DISTRO=debian ./runme.sh
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
- ```DISTOR=debian ./runme.sh```
- ```DISTOR=buildroot ./runme.sh```
  
**Note:** This can only work on Debian-based host, and has been tested only on Ubuntu 20.04.

## Build-Time Configuration Options

several options influencing the build are supported by the runme script, and can be specified as environment variables for a native build, or by using the `-e` option with docker:

- BUILDROOT_VERSION: Download and compile a specific release of buildroot
- BR2_PRIMARY_SITE: Use specific (local) buildroot mirror
