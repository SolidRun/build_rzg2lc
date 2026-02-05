#!/bin/bash

source "${ROOTDIR}/build_scripts/build_common.sh"

u_boot_do_configure() {
  set_ccache uboot
  mkdir -p "${BUILDDIR_TMP_UBOOT}"
  mkdir -p "${OUTPUT_DIR_UBOOT}"
  # Clean source tree to avoid build errors with out-of-tree builds
  cd "${SRC_DIR_UBOOT}"
  make mrproper
}

u_boot_do_compile() {
  cd "${SRC_DIR_UBOOT}"
  CROSS_COMPILE=${CROSS_TOOLCHAIN} ARCH=arm64 make O="${BUILDDIR_TMP_UBOOT}" "${UBOOT_DEFCONFIG}"
  CROSS_COMPILE=${CROSS_TOOLCHAIN} ARCH=arm64 make O="${BUILDDIR_TMP_UBOOT}" savedefconfig
  CROSS_COMPILE=${CROSS_TOOLCHAIN} ARCH=arm64 make O="${BUILDDIR_TMP_UBOOT}" -j ${MAKE_JOBS}
}

u_boot_do_install() {
  cp "${BUILDDIR_TMP_UBOOT}/u-boot.bin" "${OUTPUT_DIR_UBOOT}"
}

uboot_clean() {
  rm -rf "${OUTPUT_DIR_UBOOT}"/*
  cd ${SRC_DIR_UBOOT}
  CROSS_COMPILE=${CROSS_TOOLCHAIN} ARCH=arm64 make O="${BUILDDIR_TMP_UBOOT}" -j ${MAKE_JOBS} mrproper
}


uboot_build() {
	echo "================================="
	echo "Generating U-Boot...."
	echo "================================="
  u_boot_do_configure
  u_boot_do_compile
  u_boot_do_install
}
