# SolidRun's RZ/V2N based build scripts

## Introduction

Main intention of this repository is to produce a reference system for RZ/V2N based products.
Automatic binary releases are available on our website [RZ/Buildroot](https://images.solid-run.com/RZ/Buildroot/v2.0.1) & [RZ/Debian](https://images.solid-run.com/RZ/Debian/v2.0.1) for download.

The build script provides ready to use **Debian/Buildroot** images that can be deployed on micro SD and eMMC.

## Source code versions

This branch (`rzv2n-dev`) includes RZ/V2N support with the following source versions:

**RZ/V2N Sources:**

- [Linux v6.1 (rz-6.1-cip43)](https://github.com/SolidRun/linux-stable/tree/rz-6.1-cip43)
- [U-Boot v2024.07 (v2024.07-rzv2n_1.2.0)](https://github.com/SolidRun/u-boot/tree/v2024.07-rzv2n_1.2.0)
- [Trusted Firmware-A (rzv2n_1.2.0)](https://github.com/SolidRun/arm-trusted-firmware/tree/rzv2n_1.2.0)
- [RZ/V2N Flash Writer (rz_v2n)](https://github.com/SolidRun/rzg2_flash_writer/tree/rz_v2n)
- [Yocto meta layer (scarthgap_rzv2n_dev)](https://github.com/SolidRun/meta-solidrun-arm-rzg2lc/tree/scarthgap_rzv2n_dev)

**Other sources:**

- [Buildroot 2025.08.x](https://github.com/buildroot/buildroot/tree/2025.08.x)
- [Debian bookworm](https://deb.debian.org/debian)

## Compiling Image from Source

### Download Sources

Clone this repo at the `rzv2n-dev` branch (the `--recurse-submodules` flag pulls in the pinned U-Boot, ATF and Linux sources):

    git clone --recurse-submodules https://github.com/SolidRun/build_rzg2lc.git -b rzv2n-dev
    cd build_rzg2lc

### Prepare Build Host

#### Build with Docker

Install docker or a compatible container runtime (e.g. podman).

Then generate the reference build system:

    docker build -t rzv2n_build docker
    # optional with an apt proxy, e.g. apt-cacher-ng
    # docker build --build-arg APTPROXY=http://127.0.0.1:3142 -t rzv2n_build docker

#### Build with Host Tools

Note: this is not regulary tested due to the wide range of distros and versions.

- Debian based OS

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

- Fedora

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

### Configuration Options

- `MACHINE`: Select target HW
  - `rzv2n-solidrun` (RZ/V2N SoM based boards)
- `DISTRO`: Choose Linux distribution for rootfs
  - `buildroot` (default)
  - `debian`
- `DEBIAN_RELEASE`
  - `bookworm` (default)
- `USE_CCACHE`: Build with ccache enabled
  - `true` (default)
  - `false`
- `ROOTFS_FREE_SIZE`: Extra free space in generated rootfs
  - `100M` (default)
- `COMPRESSION_FORMAT`: Compression format for the generated images
  - no compression if unset (default)
  - `gzip`, `xz` or `zstd`
- `CROSS_TOOLCHAIN`: Toolchain to use (default: download arm-gnu-toolchain-13.3)
  - `aarch64-linux-gnu-` (use build host native aarch64 toolchain)
  - when unset default is download arm-gnu-toolchain-13.3

These options are passed as environment variables, e.g.:

    MACHINE=rzv2n-solidrun DISTRO=debian ./runme.sh

In docker options are passed through the `-e` command-line flags, e.g.:

    docker run --rm -i -t -v "$PWD":/work -e MACHINE=rzv2n-solidrun -e DISTRO=debian rzv2n_build -u $(id -u) -g $(id -g)

Podman needs the `-u` and `-g` argumetns set to `0` avoiding unexpected file permissions, e.g.:

    docker run --rm k-i -t -v "$PWD":/work -e MACHINE=rzv2n-solidrun -e DISTRO=debian rzv2n_build -u 0 -g 0

### Start Build

Invoke `runme.sh` script with chosen options (see examples above).

On success results are generated at `images/` directory, e.g.:

```
images
├── flashwriter
│   └── Flash_Writer_SCIF_RZV2N_SR_SOM_8GB_LPDDR4X.mot
├── rzv2n-solidrun
│   ├── bl2.bin
│   ├── bl2_bp.bin
│   ├── bootparams.bin
│   ├── dtbs
│   │   ├── r9a09g056n48-hummingboard-iiot.dtb
│   │   ├── r9a09g056n48-rzv2n-evk.dtb
│   │   ├── r9a09g056n48-solidsense-aiot.dtb
│   │   ├── rzv2n-hummingboard-iiot-rs485-a.dtbo
│   │   ├── rzv2n-hummingboard-iiot-rs485-b.dtbo
│   │   ├── rzv2n-hummingboard-iiot-panel-dsi-WJ70N3TYJHMNG0.dtbo
│   │   ├── rzv2n-hummingboard-iiot-csi-camera-imx678.dtbo
│   │   ├── rzv2n-solidsense-aiot-csi-camera-imx678-j8.dtbo
│   │   ├── rzv2n-solidsense-aiot-csi-camera-imx678-j17.dtbo
│   │   ├── rzv2n-solidsense-aiot-addon-flash-card.dtbo
│   │   ├── rzv2n-solidsense-aiot-addon-flash-card-cam-j8.dtbo
│   │   └── rzv2n-solidsense-aiot-addon-flash-card-cam-j17.dtbo
│   ├── fip.bin
│   └── Image.gz
├── rzv2n-solidrun-mmc-bootloader-c2939dc.img
├── rzv2n-solidrun-sd-buildroot-c2939dc.img
└── rzv2n-solidrun-sd-buildroot-c2939dc.img.bmap
```

### Deploy to microSD

To get started the latest binary release under the link above can be used for creating a bootable microSD card:
Plug in a micro SD into your machine and run the following, where sdX is the location of the SD card got probed into your machine -

```
umount /media/<relevant directory>
sudo bmaptool copy images/rzv2n-solidrun-sd-<distro>-<hash>.img /dev/sdX
```

## Device Tree Overlays

Each board boots a base device tree, and optional hardware (displays, cameras,
add-on cards, RS485) is enabled with device tree overlays (`.dtbo`). The kernel
build copies the base DTBs and all overlays to `/dtb/renesas/` on the FAT boot
partition.

Overlays are applied at boot time by U-Boot's `extlinux`/`sysboot` loader, which
is built with overlay support (`CONFIG_OF_LIBFDT_OVERLAY=y`). To enable overlays,
edit the boot entry in `/extlinux/extlinux.conf` on the boot partition: replace
the default `fdtdir /dtb` with an explicit `fdt` (the base device tree) plus an
`fdtoverlays` line listing one or more overlays (paths are absolute within the
boot partition; multiple overlays are space-separated and applied in order).

### Base device trees

| Board | Base device tree |
|-------|------------------|
| HummingBoard IIoT (RZ/V2N) | `r9a09g056n48-hummingboard-iiot.dtb` |
| SolidSense AIOT (RZ/V2N)   | `r9a09g056n48-solidsense-aiot.dtb`   |
| Renesas RZ/V2N EVK         | `r9a09g056n48-rzv2n-evk.dtb`         |

### Available overlays

| Overlay | Applies on | Description |
|---------|-----------|-------------|
| `rzv2n-hummingboard-iiot-rs485-a.dtbo` | HummingBoard IIoT | RS485 port A |
| `rzv2n-hummingboard-iiot-rs485-b.dtbo` | HummingBoard IIoT | RS485 port B |
| `rzv2n-hummingboard-iiot-panel-dsi-WJ70N3TYJHMNG0.dtbo` | HummingBoard IIoT | MIPI-DSI Winstar WJ70N3TYJHMNG0 display panel |
| `rzv2n-hummingboard-iiot-csi-camera-imx678.dtbo` | HummingBoard IIoT | MIPI-CSI Sony IMX678 camera |
| `rzv2n-solidsense-aiot-csi-camera-imx678-j8.dtbo` | SolidSense AIOT | IMX678 camera on J8 (no Flash Card) |
| `rzv2n-solidsense-aiot-csi-camera-imx678-j17.dtbo` | SolidSense AIOT | IMX678 camera on J17 (no Flash Card) |
| `rzv2n-solidsense-aiot-addon-flash-card.dtbo` | SolidSense AIOT | Flash Card (J6) only, no camera |
| `rzv2n-solidsense-aiot-addon-flash-card-cam-j8.dtbo` | SolidSense AIOT | Flash Card (J6) + IMX678 camera on J8 |
| `rzv2n-solidsense-aiot-addon-flash-card-cam-j17.dtbo` | SolidSense AIOT | Flash Card (J6) + IMX678 camera on J17 |

For the SolidSense AIOT, the Flash Card and camera overlays are mutually
exclusive configurations - pick a single overlay matching your setup. When a
Flash Card is fitted together with a camera, use the combined
`...-addon-flash-card-cam-jX.dtbo` overlay (it links the Flash Card IR
illuminator to that camera); do not stack the standalone Flash Card and camera
overlays.

### Example 1 - HummingBoard IIoT with DSI display and IMX678 camera

These are independent overlays (display on the DSI connector, camera on the CSI
connector), so they stack:

```
label primary
	menu label mmc boot
	linux /Image.gz
	fdt /dtb/renesas/r9a09g056n48-hummingboard-iiot.dtb
	fdtoverlays /dtb/renesas/rzv2n-hummingboard-iiot-panel-dsi-WJ70N3TYJHMNG0.dtbo /dtb/renesas/rzv2n-hummingboard-iiot-csi-camera-imx678.dtbo
	APPEND root=PARTUUID=<partuuid> rw rootwait
```

### Example 2 - SolidSense AIOT with Flash Card and IMX678 camera (J8)

Flash Card + camera is a single combined overlay:

```
label primary
	menu label mmc boot
	linux /Image.gz
	fdt /dtb/renesas/r9a09g056n48-solidsense-aiot.dtb
	fdtoverlays /dtb/renesas/rzv2n-solidsense-aiot-addon-flash-card-cam-j8.dtbo
	APPEND root=PARTUUID=<partuuid> rw rootwait
```

## First Steps

### Login

- **username:** root
- **password:** root

### Boot from SD and flash eMMC
If you use **HummingBoard** Carrier board:
- set the dip switch to boot from SD (In order to configure the boot media, please refer to [HummingBoard RZ/G2L Boot Select]( https://solidrun.atlassian.net/wiki/spaces/developer/pages/411861143).)
- install same above image on USB-DISK (for mounting the Root-FS)
- connect the USB-DISK
```
sudo bmaptool copy images/rzv2n-solidrun-sd-buildroot-<hash>.img /dev/sdX
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
cp build/linux-stable/arch/arm64/boot/dts/renesas/r9a09g056n48-solidsense-aiot.dtb /path/to/boot/dir/

# Copy Kernel
cp build/linux-stable/arch/arm64/boot/Image /path/to/boot/dir/
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
tftpboot r9a09g056n48-solidsense-aiot.dtb
```

* boot

```
boot
```

## Image layout

RZ/V2N boot images are assembled with binman (see [configs/image/binman-boot-image-rzv2n.dts](configs/image/binman-boot-image-rzv2n.dts)).
Unlike the RZ/G2L family, RZ/V2N does not embed DTS overlays in the boot image.

SD card layout:
| Offset    | Content          |
|-----------|------------------|
| 0x200     | bootparams.bin   |
| 0x1000    | bl2.bin          |
| 0x60000   | fip.bin          |
| 0x1E0000  | u-boot env       |
| 8MB       | fat32 boot part  |
| ...       | ext4 rootfs part |

eMMC boot partition layout:
| Offset    | Content        |
|-----------|----------------|
| 0x200     | bootparams.bin |
| ...       | bl2.bin        |
| 0x60000   | fip.bin        |
| 0x1E0000  | u-boot env     |
