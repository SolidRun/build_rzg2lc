#!/bin/bash

BUILDDIR="${ROOTDIR}/build"
BUILDDIR_TMP="${BUILDDIR}/tmp"
OUTPUT_DIR="${BUILDDIR}/output/${MACHINE}"
DEPLOY_DIR="${ROOTDIR}/images"
CACHE_DIR="${BUILDDIR}/cache"

MAKE_JOBS=$(getconf _NPROCESSORS_ONLN)


# Source trees are pinned to two different firmware/branch sets:
#   - RZ/V2N        -> bare submodules (linux-stable, u-boot, rzg_trusted-firmware-a)
#   - other platforms (g2ul/g2lc/g2l/v2l, VLP-4.0.0) -> *-vlp4 submodules
# Select the matching set based on the target MACHINE.
if [[ "${MACHINE}" == "rzv2n-solidrun" ]]; then
  SRC_DIR_UBOOT="${BUILDDIR}/u-boot"
  SRC_DIR_TFA="${BUILDDIR}/rzg_trusted-firmware-a"
  SRC_DIR_KERNEL="${BUILDDIR}/linux-stable"
  KERNEL_SRC_SET="v2n"
else
  SRC_DIR_UBOOT="${BUILDDIR}/u-boot-vlp4"
  SRC_DIR_TFA="${BUILDDIR}/rzg_trusted-firmware-a-vlp4"
  SRC_DIR_KERNEL="${BUILDDIR}/linux-stable-vlp4"
  KERNEL_SRC_SET="vlp4"
fi

BUILDDIR_TMP_UBOOT="${BUILDDIR_TMP}/u-boot/${MACHINE}"
OUTPUT_DIR_UBOOT="${OUTPUT_DIR}/u-boot"

BUILDDIR_TMP_TFA="${BUILDDIR_TMP}/tfa/${MACHINE}"
OUTPUT_DIR_TFA="${OUTPUT_DIR}/tfa"

# Kernel uses an out-of-tree O= build dir; keep it per source-set so the two
# different kernel trees (v2n vs vlp4) never share object files.
BUILDDIR_TMP_KERNEL="${BUILDDIR_TMP}/kernel-${KERNEL_SRC_SET}"
OUTPUT_DIR_KERNEL="${OUTPUT_DIR}/kernel"

SRC_DIR_CYWFMAC="${BUILDDIR}/cyw-fmac"

SRC_DIR_OPTEE="${BUILDDIR}/optee-os"
OUTPUT_DIR_OPTEE="${OUTPUT_DIR}/optee-os"

SRC_DIR_RSWLAN="${BUILDDIR}/rswlan"
BUILDDIR_TMP_RSWLAN="${BUILDDIR_TMP}/rswlan"
OUTPUT_DIR_RSWLAN="${OUTPUT_DIR}/rswlan"

BUILDDIR_TMP_BOOT_IMAGE="${BUILDDIR_TMP}/boot_image/${MACHINE}"
OUTPUT_DIR_BOOT_IMAGE="${OUTPUT_DIR}/boot_image"

SRC_DIR_BUILDROOT="${BUILDDIR}/buildroot"
BUILDDIR_TMP_BUILDROOT="${BUILDDIR_TMP}/buildroot"
OUTPUT_DIR_BUILDROOT="${OUTPUT_DIR}/buildroot"

BUILDDIR_TMP_DEBIAN="${BUILDDIR_TMP}/debian"
OUTPUT_DIR_DEBIAN="${OUTPUT_DIR}/debian"

BUILDDIR_TMP_IMAGE="${BUILDDIR_TMP}/image/${MACHINE}"
OUTPUT_DIR_IMAGE="${OUTPUT_DIR}/image"

OUTPUT_DIR_FLASHWRITER="${BUILDDIR}/output/flashwriter"

set_ccache() {
    local ccache_dir="${CACHE_DIR}/ccache/$1"
    mkdir -p $ccache_dir
    export CCACHE_DIR=$ccache_dir
}
