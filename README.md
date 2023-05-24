# build_rzg2lc
# SolidRun's RZ/G2LC based build scripts

## Introduction

Main intention of this repository is to produce a reference system for RZ/G2LC based products.
Automatic binary releases are available on [our website](https://images.solid-run.com/RZG2LC/rzg2lc_build) for download.

## Get Started

### Deploy to microSD

To get started the latest binary release under the link above can be used for creating a bootable microSD card:
Plug in a micro SD into your machine and run the following, where sdX is the location of the SD card got probed into your machine -

```
umount /media/<relevant directory>
sudo dd if=images/rzg2lc*-<hash>.img of=/dev/sdX
```

### Login
**username:** root
**password:** root

---
### Boot from SD and flash eMMC
If you use **HummingBoard** Carrier board:
- set the dip switch to boot from SD (In order to configure the boot media, please refer to [HummingBoard RZ/G2LC Boot Select]( https://solidrun.atlassian.net/wiki/spaces/developer/pages/411861143).)
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


## Source code versions

- [U-boot 2021.10](https://github.com/renesas-rz/renesas-u-boot-cip/commits/v2021.10/rz)
- [Linux kernel 5.10](https://github.com/renesas-rz/rz_linux-cip/commits/rz-5.10-cip22-rt9)
- [Buildroot 2022.02.4](https://github.com/buildroot/buildroot/tree/2022.02.4)


## Build with Docker
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
   ```

### rootless Podman

Due to the way podman performs user-id mapping, the root user inside the container (uid=0, gid=0) will be mapped to the user running podman (e.g. 1000:100).
Therefore in order for the build directory to be owned by current user, `-u 0 -g 0` have to be passed to *docker run*.

## Build with host tools

Simply running `./runme.sh`, it will check for required tools, clone and build images and place results in images/ directory.
