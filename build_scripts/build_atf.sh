#!/bin/bash
source "${ROOTDIR}/build_scripts/build_common.sh"

TFA_BUILD_TYPE="release"
# TFA_BUILD_TYPE="debug"
: ${TFA_EXTRA_ARGS:=}

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
  RZG_DRAM_ECC_FULL=0 DEBUG=$debug $TFA_EXTRA_ARGS
}

atf_create_bootparams() {
  gcc "${BUILDSCRIPT_DIR}/bootparams/bootparameter.c" -o "${BUILDDIR_TMP_TFA}/bootparameter"
  chmod +x "${BUILDDIR_TMP_TFA}/bootparameter"
  ${BUILDDIR_TMP_TFA}/bootparameter ${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}/bl2.bin ${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}/bootparams.bin
  cat ${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}/bootparams.bin ${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}/bl2.bin > ${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}/bl2_bp.bin
}

# Generate the Renesas flash-writer boot parameter images and S-records.
# Mirrors the "pkg" target in plat/renesas/rz/soc/<soc>/platform.mk, which the
# out-of-tree CI build (custom BUILD_BASE) never invokes. bptool prepends a
# per-medium boot parameter block to bl2, and objcopy converts to Motorola
# S-record at the address the boot ROM / Flash Writer expects.
atf_create_flashwriter_images() {
  local out="${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}"
  local bptool="${BUILDDIR_TMP_TFA}/bptool"
  local dest_addr bl2_vma fip_vma media

  case "${TFA_PLATFORM}" in
    v2n|v2h)           dest_addr=0x08103000; bl2_vma=0x8101E00; fip_vma=0x0 ;;
    g2ul|g2l|g2lc|v2l) dest_addr=0x00012000; bl2_vma=0x11E00;   fip_vma=0x0 ;;
    *)
      echo "atf: no flash-writer address map for '${TFA_PLATFORM}', skipping S-record generation"
      return 0
      ;;
  esac

  echo "Generating flash-writer images (bl2_bp_{spi,mmc,esd} + fip.srec) for ${TFA_PLATFORM}"
  gcc "${SRC_DIR_TFA}/tools/renesas/rz_boot_param/bptool.c" -o "${bptool}"

  for media in spi mmc esd; do
    "${bptool}" "${out}/bl2.bin" "${out}/bp_${media}.bin" "${dest_addr}" "${media}"
    cat "${out}/bp_${media}.bin" "${out}/bl2.bin" > "${out}/bl2_bp_${media}.bin"
    objcopy -I binary -O srec --adjust-vma="${bl2_vma}" --srec-forceS3 \
      "${out}/bl2_bp_${media}.bin" "${out}/bl2_bp_${media}.srec"
  done

  objcopy -I binary -O srec --adjust-vma="${fip_vma}" --srec-forceS3 \
    "${out}/fip.bin" "${out}/fip.srec"
}

atf_do_install() {
  cp "${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}/bl2.bin" "${OUTPUT_DIR_TFA}"
  cp "${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}/fip.bin" "${OUTPUT_DIR_TFA}"
  cp "${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}/bootparams.bin" "${OUTPUT_DIR_TFA}"
  cp "${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}/bl2_bp.bin" "${OUTPUT_DIR_TFA}"
  # Flash-writer artifacts (present only when a per-medium address map matched)
  cp "${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}"/bl2_bp_*.bin "${OUTPUT_DIR_TFA}" 2>/dev/null || true
  cp "${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}"/bl2_bp_*.srec "${OUTPUT_DIR_TFA}" 2>/dev/null || true
  cp "${BUILDDIR_TMP_TFA}/${TFA_PLATFORM}/${TFA_BUILD_TYPE}"/fip.srec "${OUTPUT_DIR_TFA}" 2>/dev/null || true
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
  atf_create_flashwriter_images
  atf_do_install
  atf_do_deploy
}
