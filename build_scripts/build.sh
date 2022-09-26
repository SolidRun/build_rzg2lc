#!/bin/bash

#---------------------------------------------------------------------------
# Please read the README.md file first for proper setup
#---------------------------------------------------------------------------

# This build script can be used to build
#  * Trusted Firmware-A
#  * u-boot
#  * Renesas Flash Writer
#  * Linux Kernel

# Please read "Repository Installs.txt" to install the toolchains.

# Please read "Toolchain Installs.txt" to install the toolchains.

# The output files you need will be copied to the 'output_xxxxx' directory. xxx will be the name of your board.

# Supported Boards
# MACHINE=smarc-rzg2lc	# Renesas RZ/G2LC EVK
# MACHINE=rzg2lc-solidrun	# solidrun RZ/G2LC platform



#----------------------------------------------
# Default Settings
#----------------------------------------------
TFA_DIR_DEFAULT=rzg_trusted-firmware-a
UBOOT_DIR_DEFAULT=renesas-u-boot-cip
FW_DIR_DEFAULT=rzg2_flash_writer
KERNEL_DIR_DEFAULT=rz_linux-cip
OUT_DIR=output_${MACHINE}

# Read in functions from build_common.sh
if [ ! -e build_common.sh ] ; then
  echo -e "\n ERROR: File \"build_common.sh\" not found\n."
  exit
else
  source build_common.sh
fi


# Toolchain Selection GUI
# Since each sub-script will want to ask the user what toolchain to use, we will keep a common interface in this file.
if [ "$1" == "toolchain_select" ] ; then

    SELECT=$(whiptail --title "Toolchain setup" --menu "You may use ESC+ESC to cancel.\nEnter the command line you want to run before build.\n" 0 0 0 \
    "1  ARM gcc-arm-11.2-2022.02" "  /opt/arm/gcc-arm-11.2-2022.02-x86_64-aarch64-none-elf" \
  	"0  (none)" "  default -> ROOTDIR/build/toolchain/gcc-arm*" \
	3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 0 ] ; then
    case "$SELECT" in
      1\ *)
          x_TOOLCHAIN_SETUP_NAME="ARM gcc-arm-10.3-2021.1"
          x_TOOLCHAIN_SETUP="PATH=/opt/arm/gcc-arm-none-eabi-10.3-2021.1/bin:\$PATH ; export CROSS_COMPILE=aarch64-none-elf-" ;;
      0\ *)
          x_TOOLCHAIN_SETUP_NAME="(none)"
          x_TOOLCHAIN_SETUP= ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $SELECT" 20 60 1
  fi

  # Save our replies to some tmp file so other scripts can read it
  echo "x_TOOLCHAIN_SETUP_NAME=\"$x_TOOLCHAIN_SETUP_NAME\"" > /tmp/toolchain_reply.txt
  echo "x_TOOLCHAIN_SETUP=\"$x_TOOLCHAIN_SETUP\"" >> /tmp/toolchain_reply.txt

  exit
fi

# $1 = env variable to save
# $2 = value
# Remember, we we share this file with other scripts, so we only want to change
# the lines used by this script
save_setting() {


  if [ ! -e $SETTINGS_FILE ] ; then
    touch $SETTINGS_FILE # create file if does not exit
  fi

  # Do not change the file if we did not make any changes
  grep -q "^$1=$2$" $SETTINGS_FILE
  if [ "$?" == "0" ] ; then
    return
  fi

  sed '/^'"$1"'=/d' -i $SETTINGS_FILE
  echo  "$1=$2" >> $SETTINGS_FILE

  # Delete empty or blank lines
  sed '/^$/d' -i $SETTINGS_FILE

  # Sort the file to keep the same order
  sort -o $SETTINGS_FILE $SETTINGS_FILE
}


# Save Settings to file
# Since each sub-script will want to save their settings, we will keep a common interface in this file.
if [ "$1" == "save_setting" ] ; then

  if [ "$SETTINGS_FILE" == "" ] ; then
    echo -e "\nERROR: SETTINGS_FILE not set\n"
    exit
  fi

  # Call the function in this file
  save_setting "$2" "$3"

  exit
fi

# Setting are kept in a board.ini file.
# If you want to use a different board.in file, you can define it before you run this script
#    $ export SETTINGS_FILE=my_board.ini
#    $ ./build.sh

if [ "$SETTINGS_FILE" == "" ] ; then
  # If not set, use default file name
  SETTINGS_FILE=board.ini
  export SETTINGS_FILE=$SETTINGS_FILE

  # Read in our settings
  if [ -e "$SETTINGS_FILE" ] ; then
    source $SETTINGS_FILE
  fi
fi

if [ "$MACHINE" == "" ] && [ "$1" != "s" ] ; then
  echo -e "\nERROR: No board selected. Please run \"./build.sh s\"\n"
  exit
fi


#----------------------------------------------
# Help Menu
#----------------------------------------------
if [ "$1" == "" ] ; then

  if [ "$BOARD_VERSION" != "" ] ; then
    BOARD_VERSION_TEXT="($BOARD_VERSION)"
  fi

  echo "\

Board: $MACHINE $BOARD_VERSION_TEXT

Please select what you want to build:

  ./build.sh f                       # Build Renesas Flash Writer
  ./build.sh t                       # Build Trusted Firmware-A
  ./build.sh u                       # Build u-boot
  ./build.sh k                       # Build Linux Kernel
  ./build.sh m                       # Build Linux Kernel multimedia modules

  ./build.sh s                       # Setup - Choose board and build options
"
  exit
fi

if [ "$1" == "t" ] ; then
  ./build_tfa.sh $2 $3 $4
  exit
fi
if [ "$1" == "u" ] ; then
  ./build_uboot.sh $2 $3 $4
  exit
fi
if [ "$1" == "f" ] ; then
  ./build_flashwriter.sh $2 $3 $4
  exit
fi
if [ "$1" == "k" ] ; then
  ./build_kernel.sh $2 $3 $4
  exit
fi
if [ "$1" == "m" ] ; then
  ./build_mm.sh $2 $3 $4
  exit
fi


if [ "$1" == "s" ] ; then

  # Check for required Host packages
  check_packages

  SELECT=$(whiptail --title "Board Selection" --menu "You may use ESC+ESC to cancel." 0 0 0 \
  "1  rzg2lc-solidrun" "Solidrun RZ/G2LC" \
	"2  smarc-rzg2lc" "Renesas SMARC RZ/G2LC" \
	3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 0 ] ; then
    BOARD_VERSION=""  # Clear out BOARD_VERSION in case there is not one
    case "$SELECT" in
      1\ *) FW_BOARD=RZG2LC_SOLIDRUN ; MACHINE=rzg2lc-solidrun ;;
      2\ *) FW_BOARD=RZG2LC_SMARC ; MACHINE=smarc-rzg2lc ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $SELECT" 20 60 1
  else
    # canceled
    exit
  fi

  # Clear out the current settings file
  echo "" > $SETTINGS_FILE

  # Select common toolchain
  whiptail --msgbox "Please select a Toolchain" 0 0 0
  select_toolchain "COMMON_TOOLCHAIN_SETUP_NAME" "COMMON_TOOLCHAIN_SETUP"
  save_setting COMMON_TOOLCHAIN_SETUP_NAME "\"$COMMON_TOOLCHAIN_SETUP_NAME\""
  save_setting COMMON_TOOLCHAIN_SETUP "\"$COMMON_TOOLCHAIN_SETUP\""

  # Save our default directories
  save_setting TFA_DIR $TFA_DIR_DEFAULT
  save_setting UBOOT_DIR $UBOOT_DIR_DEFAULT
  save_setting FW_DIR $FW_DIR_DEFAULT
  save_setting KERNEL_DIR $KERNEL_DIR_DEFAULT

  # The board
  save_setting MACHINE $MACHINE
  save_setting OUT_DIR output_${MACHINE}
  save_setting BOARD_VERSION $BOARD_VERSION

  # Set defaults for Flash Writer script
  save_setting FW_BOARD $FW_BOARD

  # Set defaults for Flash Writer script
  if  [ "$MACHINE" == "smarc-rzg2lc" ] || [ "$MACHINE" == "rzg2lc-solidrun" ]; then
    save_setting TFA_FIP 1
  else
    save_setting TFA_FIP 0
  fi

fi
