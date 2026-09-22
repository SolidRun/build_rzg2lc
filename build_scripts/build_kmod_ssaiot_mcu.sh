#!/bin/bash

source "${ROOTDIR}/build_scripts/build_common.sh"

kmod_ssaiot_mcu_do_compile() {
	cd "${SRC_DIR_KMOD_SSAIOT_MCU}"
	make -j ${MAKE_JOBS} ARCH=arm64 CROSS_COMPILE=${CROSS_TOOLCHAIN} KERNEL_SRC="${BUILDDIR_TMP_KERNEL}" clean
	make -j ${MAKE_JOBS} ARCH=arm64 CROSS_COMPILE=${CROSS_TOOLCHAIN} KERNEL_SRC="${BUILDDIR_TMP_KERNEL}"
}

kmod_ssaiot_mcu_do_install() {
  local kernelrel=$(cat ${OUTPUT_DIR_KERNEL}/kernelrelease)
  cd "${SRC_DIR_KMOD_SSAIOT_MCU}"
  find . -type f -name "*.ko" -exec install -v -m644 -D {} "${OUTPUT_DIR_KERNEL}/modules/lib/modules/${kernelrel}/extra/{}" \;
  depmod -b "${OUTPUT_DIR_KERNEL}/modules" -F "${BUILDDIR_TMP_KERNEL}/System.map" ${kernelrel}
}

kmod_ssaiot_mcu_build() {
	echo "========================================="
	echo "Generating kernel-module-ss-aiot-mcu ...."
	echo "========================================="
	kmod_ssaiot_mcu_do_compile
	kmod_ssaiot_mcu_do_install
}
