#!/bin/bash

source "${ROOTDIR}/build_scripts/build_common.sh"

FW_SR_IMAGES_URI="https://images.solid-run.com/RZ/FlashWriter"

fw_devices=("RZG2LC" "RZG2UL" "RZG2L" "RZV2L")
fw_mem=("512MB_1PCS" "1GB_1PCS" "2GB_1PCS")

fw_configure() {
    mkdir -p "${OUTPUT_DIR_FLASHWRITER}"
}

fw_fetch() {
    cd "${OUTPUT_DIR_FLASHWRITER}"
    local filename
    for fw_device in "${fw_devices[@]}"; do
        for fw_mem_size in "${fw_mem[@]}"; do
            filename="Flash_Writer_SCIF_${fw_device}_HUMMINGBOARD_DDR4_${fw_mem_size}.mot"
            if [[ ! -f "$filename" ]]; then
                echo "Fetching $filename"
                wget -q "${FW_SR_IMAGES_URI}/$filename" -O "$filename" &
            fi
        done
    done
    wait
}

fw_deploy() {
    mkdir -p ${DEPLOY_DIR}/flashwriter
    cp "${OUTPUT_DIR_FLASHWRITER}"/*.mot ${DEPLOY_DIR}/flashwriter
}


flashwriter_clean() {
    rm "${OUTPUT_DIR_FLASHWRITER}"/*
}

flashwriter_build() {
    echo "================================="
    echo "Fetching flashwriter...."
    echo "================================="
    fw_configure
    fw_fetch
    fw_deploy
}

