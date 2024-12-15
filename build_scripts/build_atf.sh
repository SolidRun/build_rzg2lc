#!/bin/bash
source "${ROOTDIR}/build_scripts/build_common.sh"

TFA_BUILD_TYPE="release"
# TFA_BUILD_TYPE="debug"

TFA_UBOOT_BIN="${OUTPUT_DIR_UBOOT}/u-boot.bin"

atf_do_configure() {
  set_ccache atf
  mkdir -p "${BUILDDIR_TMP_TFA}"
  mkdir -p "${OUTPUT_DIR_TFA}"
}

atf_do_compile() {
  cd "${SRC_DIR_TFA}"
  local debug=0
  if [ $TFA_BUILD_TYPE = "debug" ]; then
    debug=1
  fi
  CROSS_COMPILE=${CROSS_TOOLCHAIN} BUILD_BASE=${BUILDDIR_TMP_TFA} make -j "${MAKE_JOBS}" bl2 bl31 fip \
  PLAT="${TFA_PLATFORM}" BOARD="${TFA_BOARD}" BL33=${TFA_UBOOT_BIN} FIP_ALIGN=16 \
  RZG_DRAM_ECC_FULL=0 DEBUG=$debug
}

atf_create_bootparams() {
  gcc "${BUILDSCRIPT_DIR}/bootparams/bootparameter.c" -o "${BUILDDIR_TMP_TFA}/bootparameter"
  chmod +x "${BUILDDIR_TMP_TFA}/bootparameter"
  ${BUILDDIR_TMP_TFA}/bootparameter ${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}/bl2.bin ${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}/bootparams.bin
  cat ${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}/bootparams.bin ${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}/bl2.bin > ${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}/bl2_bp.bin
}

atf_do_install() {
  cp "${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}/bl2.bin" "${OUTPUT_DIR_TFA}"
  cp "${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}/fip.bin" "${OUTPUT_DIR_TFA}"
  cp "${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}/bootparams.bin" "${OUTPUT_DIR_TFA}"
  cp "${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}/bl2_bp.bin" "${OUTPUT_DIR_TFA}"
}

atf_do_deploy() {
  mkdir -p ${DEPLOY_DIR}/${MACHINE}
  cp "${OUTPUT_DIR_TFA}"/* ${DEPLOY_DIR}/${MACHINE}
}

atf_clean() {
  rm -rf "${BUILDDIR_TMP_TFA}"/*
  rm -rf -p "${OUTPUT_DIR_TFA}"/*
}

atf_build() {
  echo "================================="
	echo "Generating TF-A...."
	echo "================================="
  atf_do_configure
  atf_do_compile
  atf_create_bootparams
  atf_do_install
  atf_do_deploy
}
