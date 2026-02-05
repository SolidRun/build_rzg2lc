#!/bin/bash

# we don't have status code checks for each step - use "-e" with a trap instead
function error() {
	status=$?
	printf "ERROR: Line %i failed with status %i: %s\n" $BASH_LINENO $status "$BASH_COMMAND" >&2
	exit $status
}
trap error ERR
set -e

# set -x

ROOTDIR=$(pwd)
BUILDSCRIPT_DIR="${ROOTDIR}/build_scripts"
REPO_PREFIX=$(git log -1 --pretty=format:%h)


: "${MACHINE:=rzg2lc-solidrun}"
: "${DISTRO:=buildroot}"
: "${DEBIAN_RELEASE:=bookworm}"
: "${CROSS_TOOLCHAIN:=""}"
: "${USE_CCACHE:=true}"
: "${ROOTFS_FREE_SIZE:=100M}"
: "${COMPRESSION_FORMAT:=""}"

COMPRESSION_FORMATS=("gzip" "xz" "zstd")

source "${BUILDSCRIPT_DIR}/build_uboot.sh"
source "${BUILDSCRIPT_DIR}/build_atf.sh"
source "${BUILDSCRIPT_DIR}/build_kernel.sh"
source "${BUILDSCRIPT_DIR}/build_cywfmac.sh"
source "${BUILDSCRIPT_DIR}/build_rswlan.sh"
source "${BUILDSCRIPT_DIR}/assemble_bootloaders.sh"
source "${BUILDSCRIPT_DIR}/build_${DISTRO}.sh"
source "${BUILDSCRIPT_DIR}/build_flashwriter.sh"
source "${BUILDSCRIPT_DIR}/assemble_image.sh"

TARGETS=("uboot" "atf" "kernel" "bootimage" "cywfmac" "rswlan" "${DISTRO}" "flashwriter" "image")

declare -A DEPENDENCIES
DEPENDENCIES["atf"]="uboot"
DEPENDENCIES["cywfmac"]="kernel"
DEPENDENCIES["rswlan"]="kernel"
DEPENDENCIES["bootimage"]="uboot atf kernel"
DEPENDENCIES["image"]="uboot atf kernel bootimage cywfmac rswlan distro"

is_valid_target() {
  for t in "${TARGETS[@]}"; do
    if [[ "$1" == "$t" ]]; then
      return 0
    fi
  done
  return 1
}

resolve_dependencies() {
  local target="$1"

  # Check if the target has any dependencies
  if [[ -n "${DEPENDENCIES[$target]}" ]]; then
    for dep in ${DEPENDENCIES[$target]}; do
      echo "Resolving dependency: $target depends on $dep"
      ${dep}_build  # Build each dependency first
    done
  fi
}

set_machine_settings() {
  case "$MACHINE" in
      "rzg2ul-solidrun")
        UBOOT_DEFCONFIG=rzg2ul-solidrun_defconfig
        TFA_PLATFORM=g2ul
        TFA_BOARD=sr_rzg2ul
        TFA_EXTRA_ARGS="SOC_TYPE=2"
        KERNEL_OVERLAYS_PREFIX=rzg2l # g2ul som can reuse g2l sd/mmc overlays
        ;;
      "rzg2lc-solidrun")
        UBOOT_DEFCONFIG=rzg2lc-solidrun_defconfig
        TFA_PLATFORM=g2l
        TFA_BOARD=sr_rzg2lc
        KERNEL_OVERLAYS_PREFIX=rzg2l # g2lc som can reuse g2l sd/mmc overlays
        ;;
      "rzg2l-solidrun")
        UBOOT_DEFCONFIG=rzg2l-solidrun_defconfig
        TFA_PLATFORM=g2l
        TFA_BOARD=sr_rzg2l
        KERNEL_OVERLAYS_PREFIX=rzg2l
        ;;
      "rzv2l-solidrun")
        UBOOT_DEFCONFIG=rzv2l-solidrun_defconfig
        TFA_PLATFORM=v2l
        TFA_BOARD=sr_rzv2l
        KERNEL_OVERLAYS_PREFIX=rzg2l # v2l som can reuse g2l sd/mmc overlays
        ;;
      "rzv2n-solidrun")
        UBOOT_DEFCONFIG=rzv2n-solidrun_defconfig
        TFA_PLATFORM=v2n
        TFA_BOARD=sr_som
        KERNEL_OVERLAYS_PREFIX=rzv2n
        ;;
      *)
        echo "Unknown Machine=$MACHINE -> default=rzg2lc-solidrun"
        UBOOT_DEFCONFIG=rzg2lc-solidrun_defconfig
        TFA_PLATFORM=g2l
        TFA_BOARD=sr_rzg2lc
        KERNEL_OVERLAYS_PREFIX=rzg2l # g2lc som can reuse g2l sd/mmc overlays
        ;;
  esac
}

set_toolchain() {
  if [ -z "${CROSS_TOOLCHAIN}" ]; then
    if [[ ! -d ${ROOTDIR}/build/toolchain/arm-gnu-toolchain-13.3.rel1-x86_64-aarch64-none-linux-gnu/bin ]]; then
      mkdir -p ${ROOTDIR}/build/toolchain
      cd ${ROOTDIR}/build/toolchain
      wget https://developer.arm.com/-/media/Files/downloads/gnu/13.3.rel1/binrel/arm-gnu-toolchain-13.3.rel1-x86_64-aarch64-none-linux-gnu.tar.xz
      tar -xf arm-gnu-toolchain-13.3.rel1-x86_64-aarch64-none-linux-gnu.tar.xz
    fi
    export PATH=${ROOTDIR}/build/toolchain/arm-gnu-toolchain-13.3.rel1-x86_64-aarch64-none-linux-gnu/bin:$PATH
    if [ "$USE_CCACHE" == "true" ]; then
      mkdir -p $ROOTDIR/build/toolchain/ccache_symlinks
      ln -sf $(which ccache) $ROOTDIR/build/toolchain/ccache_symlinks/aarch64-none-linux-gnu-gcc
      ln -sf $(which ccache) $ROOTDIR/build/toolchain/ccache_symlinks/aarch64-none-linux-gnu-g++
      export PATH="$ROOTDIR/build/toolchain/ccache_symlinks:$PATH"
    fi
    CROSS_TOOLCHAIN=aarch64-none-linux-gnu-
  fi
}

check_submodules() {
  cd "${ROOTDIR}"
  # Check and initialize missing submodules
  local submodules=("build/u-boot" "build/linux-stable" "build/rzg_trusted-firmware-a" "build/buildroot" "build/cyw-fmac" "build/rswlan")
  for submodule in "${submodules[@]}"; do
    if [[ ! -d "${ROOTDIR}/${submodule}/.git" ]] && [[ ! -f "${ROOTDIR}/${submodule}/.git" ]]; then
      echo "Initializing missing submodule: ${submodule}"
      git submodule update --init --depth 1 "${submodule}"
    fi
  done
}

show_help() {
  echo "Usage: MACHINE=[machine] DISTRO=[distro] $0 [build|clean] [target]"
  echo "Targets: ${TARGETS[*]}"
  echo "Examples:"
  echo "  $0               # Build all targets"
  echo "  $0 build uboot   # Build uboot only"
  echo "  $0 clean kernel  # Clean kernel only"
  echo "  $0 --help        # Show this help message"
  echo "Available machines:"
  echo "rzg2lc-solidrun (default), rzg2ul-solidrun, rzg2l-solidrun, rzv2l-solidrun, rzv2n-solidrun"
  echo "Available distros:"
  echo "buildroot (default), debian"
  echo "Available env vars:"
  echo "MACHINE=rzg2l-solidrun - Machine name (default: rzg2lc-solidrun)"
  echo "DISTRO=debian - Distro to build (default: buildroot)"
  echo "CROSS_TOOLCHAIN=aarch64-linux-gnu- - Toolchain to use (default: download arm-gnu-toolchain-13.3)"
  echo "ROOTFS_FREE_SIZE=1G - Extra rootfs free size (default: 100M)"
  echo "COMPRESSION_FORMAT=zstd - if specified, image will be commpressed (zstd, xz, gzip)"
}

main() {
  local action="$1"
  local target="$2"

  if [[ "$action" == "--help" ]]; then
    show_help
    exit 0
  fi

  if [[ "$DISTRO" != "debian" && "$DISTRO" != "buildroot" ]]; then
    echo "Error: DISTRO environment variable must be set to either 'debian' or 'buildroot'."
    exit 1
  fi

  set_machine_settings
  set_toolchain
  check_submodules

  # Default behavior: if no arguments are provided, build all targets
  if [[ -z "$action" ]]; then
    echo "Building all targets..."
    for t in "${TARGETS[@]}"; do
      ${t}_build
    done
    exit 0
  fi

  if ! is_valid_target "$target"; then
    echo "Invalid target: $target"
    show_help
    exit 1
  fi

  if [[ "$action" == "build" ]]; then
    resolve_dependencies "$target"
    ${target}_build
  elif [[ "$action" == "clean" ]]; then
    ${target}_clean
  else
    echo "Unknown action: $action"
    show_help
    exit 1
  fi
}

main "$@"
