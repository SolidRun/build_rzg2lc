#!/bin/sh

# run second-stage bootstrap
/debootstrap/debootstrap --second-stage

# set empty root password
passwd -d root

# delete self
rm -f /stage2.sh

# flush disk
sync

# power-off
reboot -f