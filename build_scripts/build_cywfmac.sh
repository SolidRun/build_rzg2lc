#!/bin/bash

source "${ROOTDIR}/build_scripts/build_common.sh"

cywfmac_do_compile() {
  cd "${SRC_DIR_CYWFMAC}"
  CROSS_COMPILE=${CROSS_TOOLCHAIN} ARCH=arm64 make -j ${MAKE_JOBS} KLIB_BUILD="${BUILDDIR_TMP_KERNEL}" defconfig-brcmfmac
  CROSS_COMPILE=${CROSS_TOOLCHAIN} ARCH=arm64 make -j ${MAKE_JOBS} KLIB_BUILD="${BUILDDIR_TMP_KERNEL}" modules
}

cywfmac_do_install() {
  local kernelrel=$(cat ${OUTPUT_DIR_KERNEL}/kernelrelease)
  cd "${SRC_DIR_CYWFMAC}"
  find . -type f -name "*.ko" -exec install -v -m644 -D {} "${OUTPUT_DIR_KERNEL}/modules/lib/modules/${kernelrel}/updates/{}" \;
  depmod -b "${OUTPUT_DIR_KERNEL}/modules" -F "${BUILDDIR_TMP_KERNEL}/System.map" ${kernelrel}
}

cywfmac_clean() {
  cd "${SRC_DIR_CYWFMAC}"
  CROSS_COMPILE=${CROSS_TOOLCHAIN} ARCH=arm64 make -j ${MAKE_JOBS} KLIB_BUILD="${BUILDDIR_TMP_KERNEL}" clean
}



cywfmac_build() {
	echo "================================="
	echo "Generating cyw-fmac ...."
	echo "================================="
  # Skip cyw-fmac for RZ/V2N - incompatible with kernel 6.1-cip43
  if [[ "$MACHINE" == "rzv2n-solidrun" ]]; then
    echo "Skipping cyw-fmac for RZ/V2N (kernel API incompatible)"
    return
  fi
  cywfmac_do_compile
  cywfmac_do_install
}
