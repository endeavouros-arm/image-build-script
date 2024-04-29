#!/bin/sh
# This script will attempt to resize the partition and filesystem in order to fill the drive and do a few other minor adjustments to the system
 # Credits to rpi-distro https://github.com/RPi-Distro/raspi-config/

# Get device and partition numbers/names
 # Root Partition
PART_DEV=`findmnt / -o source -n | cut -f1 -d"["`

# Remove '/dev/' from the name 
PART_NAME=`echo $PART_DEV | cut -d "/" -f 3`

# Set just the name of the device, usually mmcblk0
DEV_NAME=`echo /sys/block/*/${PART_NAME} | cut -d "/" -f 4`

# Add /dev/ to device name
DEV="/dev/${DEV_NAME}"

# Get Number of device as single digit integer
PART_NUM=`cat /sys/block/${DEV_NAME}/${PART_NAME}/partition`

# Get size of SDCard (final sector)
SECTOR_SIZE=`cat /sys/block/${DEV_NAME}/size`

# Set the ending sector that the partition should be resized too
END_SECTOR=`expr $SECTOR_SIZE - 1`

#growpartfs $PART_DEV

# resize the partition
# parted command disabled for now. Using sfdisk instead
#parted -m $DEV u s resizepart $PART_NUM yes $END_SECTOR
echo ", +" | sfdisk --no-reread -N $PART_NUM $DEV

# reload the partitions in the kernel
#partprobe
partx -u $DEV

# resize
if [[ $(lsblk -o NAME,FSTYPE | grep $PART_NAME | awk '{print $2}') = "btrfs" ]]; then
    btrfs filesystem resize max /
else
    resize2fs $PART_DEV
fi

# systemctl disable resize-fs.service
# rm /usr/local/bin/resize-fs.sh

# printf "\n\n${CYAN}Your system will reboot in 5 seconds.${NC}\n\n"
# sleep 5
# systemctl reboot

# Change fstab to boot partition UUID
# genfstab -U / > /etc/fstab
# Change boot script to root partition UUID
# ROOT_UUID=$(lsblk -o NAME,UUID | grep $PART_NAME | awk '{print $2}')
#if [ -f /boot/extlinux/extlinux.conf ]; then
#    sed -i "s/LABEL=ROOT_EOS/UUID=$ROOT_UUID/g" /boot/extlinux/extlinux.conf
#elif [ -f /boot/boot.ini ]; then
#    sed -i "s/LABEL=ROOT_EOS/UUID=$ROOT_UUID/g" /boot/boot.ini
# elif [ -f /boot/cmdline.txt ]; then
#    sed -i "s/LABEL=ROOT_EOS/UUID=$ROOT_UUID/g" /boot/cmdline.txt
# fi


# rm /usr/local/resize-fs.sh
# rm /etc/systemd/system/resize-fs.service
# rm /etc/systemd/system/multi-user.target.wants/resize-fs.service

