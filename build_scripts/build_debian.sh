#!/bin/bash
source "${ROOTDIR}/build_scripts/build_common.sh"

DEBIAN_CACHE_FILE="${BUILDDIR_TMP_DEBIAN}/debian.hash"
DEBIAN_ROOT_CONF="${ROOTDIR}/configs/debian/config.sh"
DEBIAN_ROOT_STAGE2="${ROOTDIR}/configs/debian/stage2.sh"

debian_do_configure() {
  mkdir -p "${BUILDDIR_TMP_DEBIAN}"
  mkdir -p "${OUTPUT_DIR_DEBIAN}"
}

debian_calc_hash() {
    local sha
    sha1="$(sha256sum ${DEBIAN_ROOT_CONF} | awk '{print $1}')"
    echo "$sha1$sha2"
}

debian_check_cache() {
    if [[ ! -f "${BUILDDIR_TMP_DEBIAN}/rootfs.tar.gz" || ! -f "${DEBIAN_CACHE_FILE}" ]]; then
        echo "false"
        return
    elif [[ "$(debian_calc_hash)" == "$(cat ${DEBIAN_CACHE_FILE})" ]]; then
        echo "true"
        return
    fi
    echo "false"
}

debian_store_cache() {
    debian_calc_hash > "${DEBIAN_CACHE_FILE}"
}

debian_do_debootstrap() {
    cd "${BUILDDIR_TMP_DEBIAN}"
    source ${DEBIAN_ROOT_CONF}
    fakeroot debootstrap --variant=minbase \
			--arch=arm64 --components=main,contrib,non-free \
			--foreign \
			--include=${DEBIAN_PACKAGES} \
			${DEBIAN_RELEASE} \
			rootfs \
			${DEBIAN_MIRROR}
    cp ${DEBIAN_ROOT_STAGE2} rootfs/stage2.sh
    chmod +x rootfs/stage2.sh
}

debian_do_stage2() {
    cd "${BUILDDIR_TMP_DEBIAN}"
    truncate -s 2G "${BUILDDIR_TMP_DEBIAN}/rootfs.img"
    mkfs.ext2 -F -d "${BUILDDIR_TMP_DEBIAN}/rootfs" "${BUILDDIR_TMP_DEBIAN}/rootfs.img"
    qemu-system-aarch64 \
			-m 1G \
			-M virt \
			-cpu cortex-a57 \
			-smp 4 \
			-netdev user,id=eth0 \
			-device virtio-net-device,netdev=eth0 \
			-drive file=rootfs.img,if=none,format=raw,id=hd0 \
			-device virtio-blk-device,drive=hd0 \
			-nographic \
			-no-reboot \
			-kernel "${OUTPUT_DIR_KERNEL}/Image" \
			-append "console=ttyAMA0 root=/dev/vda rootfstype=ext2 ip=dhcp rw init=/stage2.sh"

}

debian_do_pack() {
    cd "${BUILDDIR_TMP_DEBIAN}"
    mkdir -p "${BUILDDIR_TMP_DEBIAN}/rootfs_tmp"
    fakeroot debugfs -R "rdump / ${BUILDDIR_TMP_DEBIAN}/rootfs_tmp" rootfs.img
    tar -czf "${BUILDDIR_TMP_DEBIAN}/rootfs.tar.gz" -C "${BUILDDIR_TMP_DEBIAN}/rootfs_tmp" .
}

debian_do_install() {
    cp "${BUILDDIR_TMP_DEBIAN}/rootfs.tar.gz" "${OUTPUT_DIR_DEBIAN}"
    debian_store_cache
}

debian_do_clean() {
    rm -rf "${BUILDDIR_TMP_DEBIAN:?}"/*
    rm -rf "${OUTPUT_DIR_DEBIAN:?}"/*
}

debian_clean() {
    debian_do_clean
}

debian_build() {
    echo "================================="
    echo "Generating Debian...."
    echo "================================="
    # Only rebuild rootfs if defconfig or toolchain were changed
    debian_do_configure
    if [[ "$(debian_check_cache)" == "true" ]]; then
        echo "Skipping cached debian"
    else
        debian_do_clean
        debian_do_debootstrap
        debian_do_stage2
        debian_do_pack
    fi
    debian_do_install
}
