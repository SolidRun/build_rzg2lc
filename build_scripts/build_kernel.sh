#!/bin/bash

source "${ROOTDIR}/build_scripts/build_common.sh"

KERNEL_DEFCONFIG="rz-solidrun_defconfig"
KERNEL_DEFCONFIG_PATH="${ROOTDIR}/configs/linux"

kernel_do_configure() {
  set_ccache kernel
  mkdir -p "${BUILDDIR_TMP_KERNEL}"
  mkdir -p "${OUTPUT_DIR_KERNEL}"
  cp "${KERNEL_DEFCONFIG_PATH}/${KERNEL_DEFCONFIG}" "${SRC_DIR_KERNEL}/arch/arm64/configs"
}

kernel_do_compile() {
  cd "${SRC_DIR_KERNEL}"
  CROSS_COMPILE=${CROSS_TOOLCHAIN} ARCH=arm64 make O="${BUILDDIR_TMP_KERNEL}" "${KERNEL_DEFCONFIG}"
  local CHECK_DTBS=(
    renesas/rzg2lc-hummingboard-ripple.dtb
  )
  : $(CROSS_COMPILE=${CROSS_TOOLCHAIN} ARCH=arm64 make O="${BUILDDIR_TMP_KERNEL}" -j "${MAKE_JOBS}" dt_binding_check || true)
  CROSS_COMPILE=${CROSS_TOOLCHAIN} ARCH=arm64 make O="${BUILDDIR_TMP_KERNEL}" -j "${MAKE_JOBS}" CHECK_DTBS=y ${CHECK_DTBS[@]}
  CROSS_COMPILE=${CROSS_TOOLCHAIN} ARCH=arm64 DTC_FLAGS="-@" make O="${BUILDDIR_TMP_KERNEL}" -j "${MAKE_JOBS}" Image Image.gz dtbs modules
}

kernel_do_install() {
  mkdir -p "${OUTPUT_DIR_KERNEL}/dtbs"
  cp "${BUILDDIR_TMP_KERNEL}/arch/arm64/boot/Image" "${OUTPUT_DIR_KERNEL}"
  cp "${BUILDDIR_TMP_KERNEL}/arch/arm64/boot/Image.gz" "${OUTPUT_DIR_KERNEL}"
  cp ${BUILDDIR_TMP_KERNEL}/arch/arm64/boot/dts/renesas/rz*hummingboard*.dtb "${OUTPUT_DIR_KERNEL}/dtbs"
  cp ${BUILDDIR_TMP_KERNEL}/arch/arm64/boot/dts/renesas/rz*overlay*.dtbo "${OUTPUT_DIR_KERNEL}/dtbs"

  cd ${OUTPUT_DIR_KERNEL}
  ln -sf ${OUTPUT_DIR_KERNEL}/dtbs/${KERNEL_OVERLAYS_PREFIX}-solidrun-sd-overlay.dtbo sd-overlay.dtbo
  ln -sf ${OUTPUT_DIR_KERNEL}/dtbs/${KERNEL_OVERLAYS_PREFIX}-solidrun-mmc-overlay.dtbo mmc-overlay.dtbo
  rm -rf ${OUTPUT_DIR_KERNEL}/modules
  mkdir -p ${OUTPUT_DIR_KERNEL}/modules
  cd "${SRC_DIR_KERNEL}"
  CROSS_COMPILE=${CROSS_TOOLCHAIN} ARCH=arm64 make O="${BUILDDIR_TMP_KERNEL}" -j "${MAKE_JOBS}" INSTALL_MOD_PATH="${OUTPUT_DIR_KERNEL}/modules" modules_install
  KRELEASE=$(make --silent O="${BUILDDIR_TMP_KERNEL}" kernelrelease)
  echo "${KRELEASE}" > ${OUTPUT_DIR_KERNEL}/kernelrelease
}

kernel_do_deploy() {
  mkdir -p ${DEPLOY_DIR}/${MACHINE}
  cp "${OUTPUT_DIR_KERNEL}/Image.gz" "${DEPLOY_DIR}/${MACHINE}"
  cp -r "${OUTPUT_DIR_KERNEL}/dtbs" "${DEPLOY_DIR}/${MACHINE}"
}

kernel_clean() {
  rm -rf "${OUTPUT_DIR_KERNEL}"/*
  cd ${SRC_DIR_KERNEL}
  CROSS_COMPILE=${CROSS_TOOLCHAIN} ARCH=arm64 make O="${BUILDDIR_TMP_KERNEL}" -j "${MAKE_JOBS}" mrproper
}

kernel_build() {
  echo "================================="
  echo "Generating Kernel...."
  echo "================================="
  kernel_do_configure
  kernel_do_compile
  kernel_do_install
  kernel_do_deploy
}
