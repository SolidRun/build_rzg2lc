#!/bin/bash

source "${ROOTDIR}/build_scripts/build_common.sh"

rswlan_do_compile() {
  cd "${SRC_DIR_RSWLAN}"
  CROSS_COMPILE=${CROSS_TOOLCHAIN} ARCH=arm64 make -j ${MAKE_JOBS} KDIR="${BUILDDIR_TMP_KERNEL}" CONFIG_MODULE_TYPE=spi
}

rswlan_do_install() {
  local kernelrel=$(cat ${OUTPUT_DIR_KERNEL}/kernelrelease)
  install -v -m644 -D ${SRC_DIR_RSWLAN}/rswlan.ko "${OUTPUT_DIR_KERNEL}/modules/lib/modules/${kernelrel}/extra/rswlan.ko"
  depmod -b "${OUTPUT_DIR_KERNEL}/modules" -F "${BUILDDIR_TMP_KERNEL}/System.map" ${kernelrel}
}

rswlan_clean() {
  cd "${SRC_DIR_RSWLAN}"
  CROSS_COMPILE=${CROSS_TOOLCHAIN} ARCH=arm64 make -j ${MAKE_JOBS} KDIR="${BUILDDIR_TMP_KERNEL}" clean
}



rswlan_build() {
	echo "================================="
	echo "Generating RSWLAN...."
	echo "================================="
  rswlan_do_compile
  rswlan_do_install
}
