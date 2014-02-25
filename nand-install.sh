#!/bin/sh

##------------------------------------------------------------------------------
##  Script for cubietruck:
##
##  This script creates two partitions on the nand flash of the cubietruck board. 
##  The first partition is formatted for vfat. It contains the u-boot loader 
##  and the uImage*. The uImage is copied from the sd card /boot/uImage.
##  The second partition is formatted as ext4* (change it to ubifs). 
##  The root data from the sd card is copied to the second partition.
##
##  The installation requires a reboot.
##  -> call this script a second time after reboot.
##  
##  When the flash process has terminated, all leds on the board will go off.
##
##------------------------------------------------------------------------------

# Check if user is root
if [ $(id -u) != "0" ]; then
echo "Error: You must be root to run this script."
    exit 1
fi

cat > .install-exclude <<EOF
/dev/*
/proc/*
/sys/*
/media/*
/mnt/*
/run/*
/tmp/*
/boot/*
EOF

exec 2>/dev/null
umount /mnt
exec 2>&1

clear_console
echo "

W A R N I N G !!!

This script will NUKE / erase your NAND partition and copy content of SD card to it
"
echo -n "Proceed (y/n)? (default: y): "
read nandinst

if [ "$nandinst" == "n" ]
then
exit 0
fi

FLAG=".reboot-nand-install.pid"

if [ ! -f $FLAG ]; then
echo "Partitioning"
(echo y;) | nand-part -f a20 /dev/nand 32768 'bootloader 32768' 'rootfs 0' >> /dev/null || true
echo "
Press a key to reboot than run this script again!
"
touch $FLAG
read zagon
reboot
exit 0
fi

echo "Formatting and optimizing NAND rootfs ... up to 30 sec"
mkfs.vfat /dev/nanda >> /dev/null
mkfs.ext4 /dev/nandb >> /dev/null
tune2fs -o journal_data_writeback /dev/nandb >> /dev/null
tune2fs -O ^has_journal /dev/nandb >> /dev/null
e2fsck -f /dev/nandb

echo "Creating NAND bootfs ... few seconds"
mount /dev/nanda /mnt
tar -zxvf bootpartition.tar.gz -C /mnt/

cp /boot/uImage /mnt/

umount /mnt

echo "Creating NAND rootfs ... up to 5 min"
mount /dev/nandb /mnt
rsync -aH --exclude-from=.install-exclude / /mnt
umount /mnt
echo "All done. Press a key to power off, than remove SD and boot from NAND"
rm $FLAG
rm .install-exclude
read konec
poweroff
