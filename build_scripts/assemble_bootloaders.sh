#!/bin/bash

source "${ROOTDIR}/build_scripts/build_common.sh"

do_bootloaders_configure() {
    mkdir -p "${BUILDDIR_TMP_BOOT_IMAGE}"
    mkdir -p "${OUTPUT_DIR_BOOT_IMAGE}"
}

do_bootloaders_overlays_fit() {
    cp ${ROOTDIR}/configs/image/overlays-fit.its ${BUILDDIR_TMP_BOOT_IMAGE}
    cp ${OUTPUT_DIR_KERNEL}/sd-overlay.dtbo ${BUILDDIR_TMP_BOOT_IMAGE}
    cp ${OUTPUT_DIR_KERNEL}/mmc-overlay.dtbo ${BUILDDIR_TMP_BOOT_IMAGE}
    cd ${BUILDDIR_TMP_BOOT_IMAGE}
    mkimage -f overlays-fit.its overlays.itb
}

do_bootloaders_binman() {
    mkdir -p ${BUILDDIR_TMP_BOOT_IMAGE}/${MACHINE}
	dtc -I dts -O dtb -o ${BUILDDIR_TMP_BOOT_IMAGE}/${MACHINE}/u-boot.dtb $ROOTDIR/configs/image/binman-boot-image.dts
	${SRC_DIR_UBOOT}/tools/binman/binman -B ${BUILDDIR_TMP_BOOT_IMAGE} build \
        -I "${BUILDDIR_TMP_BOOT_IMAGE}" -I "${OUTPUT_DIR_TFA}" -O "${BUILDDIR_TMP_BOOT_IMAGE}" -b "${MACHINE}"
}

do_bootloaders_install() {
    cp "${BUILDDIR_TMP_BOOT_IMAGE}/boot_image_sd.bin" "${OUTPUT_DIR_BOOT_IMAGE}"
	cp "${BUILDDIR_TMP_BOOT_IMAGE}/boot_image_mmc.bin" "${OUTPUT_DIR_BOOT_IMAGE}"
    cp "${BUILDDIR_TMP_BOOT_IMAGE}/overlays.itb" "${OUTPUT_DIR_BOOT_IMAGE}"
}

do_bootloaders_deploy() {
    mkdir -p ${DEPLOY_DIR}/${MACHINE}
    cp "${OUTPUT_DIR_BOOT_IMAGE}/boot_image_sd.bin" "${DEPLOY_DIR}/${MACHINE}-sd-bootloader-${REPO_PREFIX}.img"
	cp "${OUTPUT_DIR_BOOT_IMAGE}/boot_image_mmc.bin" "${DEPLOY_DIR}/${MACHINE}-mmc-bootloader-${REPO_PREFIX}.img"
    cp "${BUILDDIR_TMP_BOOT_IMAGE}/overlays.itb" "${DEPLOY_DIR}/${MACHINE}"
    echo "Created bootloader image images/${MACHINE}-sd-bootloader-${REPO_PREFIX}.img"
    echo "Created bootloader image images/${MACHINE}-mmc-bootloader-${REPO_PREFIX}.img"
}

bootimage_clean() {
    rm "${BUILDDIR_TMP_BOOT_IMAGE}"/*
    rm "${OUTPUT_DIR_BOOT_IMAGE}"/*
}

bootimage_build() {
    echo "================================="
	echo "Generating Bootloader Images...."
	echo "================================="
    do_bootloaders_configure
    do_bootloaders_overlays_fit
    do_bootloaders_binman
    do_bootloaders_install
    do_bootloaders_deploy
}