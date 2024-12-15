#!/bin/bash

source "${ROOTDIR}/build_scripts/build_common.sh"

BUILDROOT_DEFCONFIG="rz-solidrun_defconfig"
BUILDROOT_DEFCONFIG_PATH="${ROOTDIR}/configs/buildroot"
BUILDROOT_CACHE_FILE="${BUILDDIR_TMP_BUILDROOT}/buildroot.hash"
BUILDROOT_DL_DIR="${CACHE_DIR}/buildroot_dl"

buildroot_do_configure() {
    set_ccache buildroot
    mkdir -p "${BUILDDIR_TMP_BUILDROOT}"
    mkdir -p "${OUTPUT_DIR_BUILDROOT}"
    cp "${BUILDROOT_DEFCONFIG_PATH}/${BUILDROOT_DEFCONFIG}" "${SRC_DIR_BUILDROOT}/configs"
    if [ "$USE_CCACHE" == "true" ]; then
		echo "BR2_CCACHE=y" >> ${SRC_DIR_BUILDROOT}/configs/${BUILDROOT_DEFCONFIG}
		echo "BR2_CCACHE_DIR=$CCACHE_DIR" >> ${SRC_DIR_BUILDROOT}/configs/${BUILDROOT_DEFCONFIG}
	fi
}

buildroot_calc_hash() {
    local sha
    sha="$( (cat "${BUILDROOT_DEFCONFIG_PATH}/${BUILDROOT_DEFCONFIG}"; echo -n "${CROSS_TOOLCHAIN}") | sha256sum | awk '{print $1}')"
    echo "$sha"
}

buildroot_check_cache() {
    if [[ ! -f "${BUILDDIR_TMP_BUILDROOT}/images/rootfs.tar.gz" || ! -f "${BUILDDIR_TMP_BUILDROOT}/images/initrd.img" || ! -f "${BUILDROOT_CACHE_FILE}" ]]; then
        echo "false"
        return
    elif [[ "$(buildroot_calc_hash)" == "$(cat ${BUILDROOT_CACHE_FILE})" ]]; then
        echo "true"
        return
    fi
    echo "false"
}

buildroot_store_cache() {
    buildroot_calc_hash > "${BUILDROOT_CACHE_FILE}"
}

buildroot_do_compile() {
    cd "${SRC_DIR_BUILDROOT}"
    export BR2_DL_DIR=${BUILDROOT_DL_DIR}
    make O="${BUILDDIR_TMP_BUILDROOT}" "${BUILDROOT_DEFCONFIG}" --silent
    make O="${BUILDDIR_TMP_BUILDROOT}" -j "${MAKE_JOBS}" --silent
}

buildroot_make_initramfs() {
    mkimage -A arm64 -O linux -T ramdisk -C gzip -d "${BUILDDIR_TMP_BUILDROOT}/images/rootfs.cpio.gz" "${BUILDDIR_TMP_BUILDROOT}/images/initrd.img"
}

buildroot_do_install() {
    cp "${BUILDDIR_TMP_BUILDROOT}/images/rootfs.tar.gz" "${OUTPUT_DIR_BUILDROOT}"
    cp "${BUILDDIR_TMP_BUILDROOT}/images/initrd.img" "${OUTPUT_DIR_BUILDROOT}"
    buildroot_store_cache
}

buildroot_clean() {
    rm -rf "${OUTPUT_DIR_BUILDROOT}"
    rm -rf "${BUILDDIR_TMP_BUILDROOT}"
    rm -rf ${BUILDROOT_DL_DIR}
    buildroot_do_configure
}

buildroot_build() {
	echo "================================="
	echo "Generating Buildroot...."
	echo "================================="
    buildroot_do_configure
    # Only rebuild rootfs if defconfig or toolchain were changed
    if [[ "$(buildroot_check_cache)" == "true" ]]; then
        echo "Skipping cached buildroot"
    else
        buildroot_do_compile
        buildroot_make_initramfs
    fi
    buildroot_do_install
}
