#!/bin/bash

source "${ROOTDIR}/build_scripts/build_common.sh"

optee_do_compile() {
	local PLATFORM=rz
	local PLATFORM_FLAVOR=$OPTEE_PLATFORM
	local TEE_CORE_LOG_LEVEL=2

	# build optee devkit
	cd "${SRC_DIR_OPTEE}"
	rm -rf out
	make -j${MAKE_JOBS} \
		ARCH=arm \
		PLATFORM=${PLATFORM} \
		PLATFORM_FLAVOR=${PLATFORM_FLAVOR} \
		CROSS_COMPILE64=${CROSS_TOOLCHAIN} \
		CROSS_COMPILE32=${CROSS_TOOLCHAIN_32} \
		CFG_ARM64_core=y \
		CFG_CRYPTO_WITH_CE=n \
		ta_dev_kit

	# TODO: build TAs

	# build optee-os
	make -j${MAKE_JOBS} \
		ARCH=arm \
		PLATFORM=$PLATFORM \
		PLATFORM_FLAVOR=${PLATFORM_FLAVOR} \
		CROSS_COMPILE64=${CROSS_TOOLCHAIN} \
		CROSS_COMPILE32=${CROSS_TOOLCHAIN_32} \
		CFG_ARM64_core=y \
		CFG_CRYPTO_WITH_CE=n \
		CFG_REE_FS=y CFG_RPMB_FS=n \
		CFG_TEE_CORE_LOG_LEVEL=$TEE_CORE_LOG_LEVEL

	mkdir -p $OUTPUT_DIR_OPTEE
	cp out/arm-plat-$PLATFORM/core/tee-pager_v2.bin $OUTPUT_DIR_OPTEE/
}

optee_build() {
	echo "================================="
	echo "Generating optee-os ...."
	echo "================================="
	optee_do_compile
}
