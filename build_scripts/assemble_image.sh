#!/bin/bash

source "${ROOTDIR}/build_scripts/build_common.sh"

IMAGE_NAME="${MACHINE}-sd-${DISTRO}-${REPO_PREFIX}.img"

do_image_configure() {
    mkdir -p "${BUILDDIR_TMP_IMAGE}"
    mkdir -p "${OUTPUT_DIR_IMAGE}"
}

do_image_clean() {
    rm -rf ${BUILDDIR_TMP_IMAGE:?}/*
    rm -rf ${OUTPUT_DIR_IMAGE:?}/*
}

do_image_prepare_partitions() {
    cd "${BUILDDIR_TMP_IMAGE}"
    cp ${OUTPUT_DIR_BOOT_IMAGE}/boot_image_sd.bin bootloader.img
    mkdir -p boot/dtb/renesas
    mkdir -p boot/extlinux
    cp ${OUTPUT_DIR_KERNEL}/Image.gz boot
    cp ${OUTPUT_DIR_KERNEL}/dtbs/* boot/dtb/renesas
    if [ -f "${OUTPUT_DIR}/${DISTRO}/initrd.img" ]; then 
        cp "${OUTPUT_DIR}/${DISTRO}/initrd.img" boot
    fi
    mkdir -p root
    fakeroot tar --same-owner --exclude='./dev/*' -xpf ${OUTPUT_DIR}/${DISTRO}/rootfs.tar.gz -C root
    fakeroot mkdir -p root/boot
}

get_needed_size() {
    local dir="$1"
    local total_size=$(du -sb "$dir" | cut -f1)
    # Calculate 30% extra space
    local extra_space=$(echo "$total_size * 0.2" | bc)
    # Calculate the total required size (in bytes)
    local total_required_size=$(echo "$total_size + $extra_space" | bc)
    # Align to 4MB blocks (4 * 1024 * 1024 bytes = 4194304 bytes)
    local aligned_size=$(echo "((($total_required_size + 4194303) / 4194304)) * 4194304" | bc)
    echo "$aligned_size"
}

apply_overlay_to_rootfs() {
    local overlay_path="$1"
    local rootfs="$2"
    find "${overlay_path}" -type f -name "*" -printf "%P\n" | e2cp -G 0 -O 0 -P 644 -s "${overlay_path}" -d "${rootfs}:/" -a
    find "${overlay_path}" -type l -name "*" -printf "%P\n" | e2cp -G 0 -O 0 -P 644 -s "${overlay_path}" -d "${rootfs}:/" -a
}

set_host_name() {
    echo "${MACHINE}" > ${BUILDDIR_TMP_IMAGE}/hostname
	echo "127.0.0.1 localhost ${MACHINE}" > ${BUILDDIR_TMP_IMAGE}/hosts
	e2cp -G 0 -O 0 ${BUILDDIR_TMP_IMAGE}/hosts ${BUILDDIR_TMP_IMAGE}/root.img:/etc/hosts
	e2cp -G 0 -O 0 ${BUILDDIR_TMP_IMAGE}/hostname ${BUILDDIR_TMP_IMAGE}/root.img:/etc/hostname
}

do_rootfs_install_additions() {
    if test -d ${ROOTDIR}/overlay/${DISTRO}; then
        apply_overlay_to_rootfs ${ROOTDIR}/overlay/${DISTRO} ${BUILDDIR_TMP_IMAGE}/root.img
    fi
    apply_overlay_to_rootfs ${ROOTDIR}/overlay/common ${BUILDDIR_TMP_IMAGE}/root.img
    apply_overlay_to_rootfs ${OUTPUT_DIR_KERNEL}/modules ${BUILDDIR_TMP_IMAGE}/root.img
    set_host_name
}

do_create_root_part() {
    local ROOT_PART_SIZE=$(get_needed_size "${BUILDDIR_TMP_IMAGE}/root")
    local extra_size=$(numfmt --from=iec ${ROOTFS_FREE_SIZE})
    local total_size=$((ROOT_PART_SIZE+extra_size))
    truncate -s "${total_size}" "${BUILDDIR_TMP_IMAGE}/root.img"
    fakeroot mkfs.ext4 -L rootfs -F -d "${BUILDDIR_TMP_IMAGE}/root" "${BUILDDIR_TMP_IMAGE}/root.img"
    do_rootfs_install_additions
}

do_create_boot_part() {
    local BOOT_PART_SIZE=$(get_needed_size "${BUILDDIR_TMP_IMAGE}/boot")
    truncate -s "${BOOT_PART_SIZE}" "${BUILDDIR_TMP_IMAGE}/boot.img"
    mkfs.vfat -n BOOT "${BUILDDIR_TMP_IMAGE}/boot.img"
    mcopy -s -i "${BUILDDIR_TMP_IMAGE}/boot.img" boot/* ::/
}

do_generate_extlinux() {
    local PARTNUMBER=2
	local PARTUUID=$(blkid -s PTUUID -o value ${BUILDDIR_TMP_IMAGE}/${IMAGE_NAME})
    cp "${ROOTDIR}/configs/image/extlinux.conf.tmpl" ${BUILDDIR_TMP_IMAGE}/extlinux.conf
	PARTUUID=${PARTUUID}'-0'${PARTNUMBER}
    sed -i "s/%PARTUUID%/${PARTUUID}/g" "${BUILDDIR_TMP_IMAGE}/extlinux.conf"
}

do_image_assemble() {
    do_create_root_part
    do_create_boot_part
    cd ${BUILDDIR_TMP_IMAGE}

	# define partition offsets
	# note: partition start and end sectors are inclusive, add/subtract 1 where appropriate
	IMAGE_BOOTPART_START=8 # partition start aligned to 8MiB
	IMAGE_BOOTPART_SIZE=$(stat -c "%s" boot.img)
    IMAGE_BOOTPART_SIZE_M=$((IMAGE_BOOTPART_SIZE/1024/1024))
    IMAGE_BOOTPART_END=$((IMAGE_BOOTPART_START+IMAGE_BOOTPART_SIZE_M))
	IMAGE_ROOTPART_SIZE=$(stat -c "%s" root.img)
    IMAGE_ROOTPART_SIZE_M=$((IMAGE_ROOTPART_SIZE/1024/1024))
	IMAGE_ROOTPART_START=${IMAGE_BOOTPART_END}
	IMAGE_SIZE=$((IMAGE_BOOTPART_START+IMAGE_BOOTPART_SIZE_M+IMAGE_ROOTPART_SIZE_M+1))

	# Create the output image, 2 partitions: 1 boot partition and one root partition
	truncate -s ${IMAGE_SIZE}M $IMAGE_NAME
	parted -s $IMAGE_NAME -- mklabel msdos mkpart primary fat32 ${IMAGE_BOOTPART_START}M ${IMAGE_BOOTPART_END}M mkpart primary ext4 ${IMAGE_ROOTPART_START}M 100%
    do_generate_extlinux

    dd if=bootloader.img of=$IMAGE_NAME bs=512 seek=0 conv=notrunc,sparse

	# mark both partitions bootable:
	sfdisk -A ${IMAGE_NAME} 1 2

	mcopy -s -i "${BUILDDIR_TMP_IMAGE}/boot.img" extlinux.conf ::/extlinux/extlinux.conf


	# Now find offsets in output image
	FIRST_PARTITION_OFFSET=$(fdisk $IMAGE_NAME -l | grep img1 | awk '{print $3}')
	SECOND_PARTITION_OFFSET=$(fdisk $IMAGE_NAME -l | grep img2 | awk '{print $3}')

	# Write boot partition into output partition
	dd if=boot.img bs=512 of=$IMAGE_NAME seek=$FIRST_PARTITION_OFFSET conv=notrunc

	# write rootfs into second partition
	dd if=root.img bs=512 of=$IMAGE_NAME seek=$SECOND_PARTITION_OFFSET conv=notrunc,sparse
    bmaptool create ${IMAGE_NAME} > ${IMAGE_NAME}.bmap
    do_image_compress
}

do_image_compress() {
    cd "${BUILDDIR_TMP_IMAGE}"
    if [ -n "${COMPRESSION_FORMAT}" ]; then
        if [[ ${COMPRESSION_FORMATS[*]} =~ ${COMPRESSION_FORMAT} ]]; then
            echo "Compressing ${IMAGE_NAME} with ${COMPRESSION_FORMAT}"
            zstd -T0 --format=${COMPRESSION_FORMAT} -k "${BUILDDIR_TMP_IMAGE}/${IMAGE_NAME}"
        fi
    fi
}

do_image_install() {
    cp "${BUILDDIR_TMP_IMAGE}/${IMAGE_NAME}"* "${OUTPUT_DIR_IMAGE}"
}

do_image_deploy() {
    cp "${OUTPUT_DIR_IMAGE}/${IMAGE_NAME}"* "${DEPLOY_DIR}/"
    echo "Created image images/${MACHINE}-sd-${DISTRO}-${REPO_PREFIX}.img"
}

image_clean() {
    do_image_clean
}

image_build() {
    echo "================================="
	echo "Generating Images...."
	echo "================================="
    do_image_configure
    do_image_clean
    do_image_prepare_partitions
    do_image_assemble
    do_image_install
    do_image_deploy
}
