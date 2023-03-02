# build_rzg2lc
# SolidRun's RZ/G2LC based build scripts

## Introduction
Main intention of this repository is to build a buildroot based build environment for RZ/G2LC based products.

The build script provides ready to use images that can be deployed on a micro SD|eMMC card.

## Source code versions

- [U-boot 2021.10](https://github.com/renesas-rz/renesas-u-boot-cip/commits/v2021.10/rz)
- [Linux kernel 5.10](https://github.com/renesas-rz/rz_linux-cip/commits/rz-5.10-cip22-rt9)
- [Buildroot 2022.02.4](https://github.com/buildroot/buildroot/tree/2022.02.4)

## Building Image

The build script will check for required tools, clone and build images and place results in images/ directory.

### Native Build
Simply:

```
./runme.sh
```

## Deploying
In order to create a bootable SD card, plug in a micro SD into your machine and run the following, where sdX is the location of the SD card got probed into your machine -

```
umount /media/<relevant directory>
sudo dd if=images/rzg2lc*-<hash>.img of=/dev/sdX
```

## Login
**username:** root
**password:** root

---
## Boot from SD and flash eMMC
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

### Docker build (TBD)

* Build the Docker image (<b>Just once</b>):

```
docker build --build-arg user=$(whoami) --build-arg userid=$(id -u) -t rzg2lc docker/
```

To check if the image exists in you machine, you can use the following command:

```
docker images | grep rzg2lc
```

* Run the build script:
```
docker run --rm -it -v "$PWD":/rzg_build/ rzg2lc:latest ./runme.sh
```
**Note:** run the above commands from build_rzg2lc directory

To Delete all containers:
```
docker rm -f $(docker ps -a -q)
```
