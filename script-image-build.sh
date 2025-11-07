#!/bin/bash

_partition_Radxa5b() {
    dd if=/dev/zero of=$DEVICENAME bs=1M count=18
#    dd if=rk3588-uboot.img of=$DEVICENAME
#    dd if=rk3588-uboot.img ibs=1 skip=0 count=15728640 of=$DEVICENAME
#    printf "\n\n${CYAN}46b3dc9b4dd0abc5ed30417eaeaac321${NC}\n"
#    dd if=$DEVICENAME ibs=1 skip=0 count=15728640 | md5sum
#    printf "\nBoth check sums should be the same\n"
    parted --script -a minimal $DEVICENAME \
    mklabel gpt \
    mkpart primary 17MiB 34MiB \
    mkpart primary 34MiB $DEVICESIZE"MiB" \
    quit

    dd if=rk3588-uboot-j.bin ibs=1 skip=0 count=15728640 of=$DEVICENAME
    printf "\n\n${CYAN}cdd31c860ee3a39d315d9f2a8382f8e2${NC}\n"
    dd if=$DEVICENAME ibs=1 skip=0 count=15728640 | md5sum
    printf "\n\n${CYAN}Both check sums should be the same.  Then Press Enter.${NC}\n\n"
    read z
}

_partition_Pinebook() {
    dd if=/dev/zero of=$DEVICENAME bs=1M count=16
    parted --script -a minimal $DEVICENAME \
    mklabel msdos \
    unit mib \
    mkpart primary fat32 16MiB 400MiB \
    mkpart primary 400MiB $DEVICESIZE"MiB" \
    quit
}

_partition_OdroidN2() {
    parted --script -a minimal $DEVICENAME \
    mklabel msdos \
    unit mib \
    mkpart primary fat32 2MiB 514MiB \
    mkpart primary 514MiB $DEVICESIZE"MiB" \
    quit
}

_partition_RPi4() {
    parted --script -a minimal $DEVICENAME \
    mklabel gpt \
    unit MiB \
    mkpart primary fat32 2MiB 514MiB \
    mkpart primary 514MiB $DEVICESIZE"MiB" \
    quit
}

_copy_stuff_for_chroot() {
    mkdir /mnt/home/alarm
    cp $WORKDIR/script-image-chroot.sh /mnt/root/
    cp $WORKDIR/config-eos.sh /mnt/root/
    cp $WORKDIR/config-eos.service /mnt/home/alarm/
    cp $WORKDIR/lxqt_instructions.txt /mnt/root
    cp $WORKDIR/xfce4-desktop.xml /mnt/root
    cp -R $WORKDIR/xfce4-backgrounds /mnt/root
    cp $WORKDIR/resize-fs.service /mnt/root
    cp $WORKDIR/resize-fs.sh /mnt/root
    cp $WORKDIR/DE-pkglist.txt /mnt/root
    cp -R $WORKDIR/openbox-configs /mnt/root
    cp $WORKDIR/smb.conf /mnt/home/alarm
    cp $WORKDIR/lsb-release /mnt/home/alarm
    cp $WORKDIR/os-release /mnt/home/alarm

    case $PLATFORM in
      RPi4 | ServRPi)     cp $WORKDIR/rpi4-config.txt /mnt/home/alarm ;;
      RPi5)               cp $WORKDIR/rpi4-config.txt /mnt/home/alarm
                          cp $WORKDIR/99-vd3.conf /mnt/etc/X11/xorg.conf.d ;;
      OdroidN2 | Servodn) cp $WORKDIR/n2-boot.ini /mnt/home/alarm ;;
    esac
    if [ "$PLATFORM" == "ServRPi" ]; then 
       sed -i 's/# dtoverlay=disable-wifi/dtoverlay=disable-wifi/g' /mnt/home/alarm/rpi4-config.txt
    fi
    printf "$PLATFORM\n" > platformname
    cp platformname /mnt/root/
    rm platformname
}   #  end of function _copy_stuff_for_chroot

_fstab_uuid() {

    local fstabuuid=""

    printf "\n${CYAN}Changing /etc/fstab to UUID numbers instead of a lable such as /dev/sda.${NC}\n"
    mv /mnt/etc/fstab /mnt/etc/fstab-bkup
    partition=$(sed 's#\/dev\/##g' <<< $PARTNAME1)
    fstabuuid="UUID="$(lsblk -o NAME,UUID | grep $partition | awk '{print $2}')
    # fstabuuid should be UUID=XXXX-XXXX
    printf "# /etc/fstab: static file system information.\n#\n# Use 'blkid' to print the universally unique identifier for a device; this may\n" > /mnt/etc/fstab
    printf "# be used with UUID= as a more robust way to name devices that works even if\n# disks are added and removed. See fstab(5).\n" >> /mnt/etc/fstab
    printf "#\n# <file system>             <mount point>  <type>  <options>  <dump>  <pass>\n\n"  >> /mnt/etc/fstab
    printf "$fstabuuid  /boot  vfat  defaults  0  0\n\n" >> /mnt/etc/fstab
}   # end of fucntion _fstab_uuid

_install_Radxa5b_image() {

    local partition
    local uuidno
    local old

    pacstrap -cGM /mnt - < ARM-pkglist.txt
    _copy_stuff_for_chroot
    cp -r rk3588-boot/extlinux /mnt/boot/
    cp -r rk3599-boot/dtbs /mnt/boot
    # change extlinux.conf to UUID instead of partition label.
    partition=$(sed 's#\/dev\/##g' <<< $PARTNAME2)
    uuidno="root=UUID="$(lsblk -o NAME,UUID | grep $partition | awk '{print $2}')
    # uuidno should now be root=UUID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXX
    old=$(grep 'root=' /mnt/boot/extlinux/extlinux.conf | awk '{print $2}')
    sed -i "s#$old#$uuidno#" /mnt/boot/extlinux/extlinux.conf
}   # End of function _install_Radxa5b_image

_install_Pinebook_image() {

    local partition
    local uuidno
    local old

    pacstrap -cGM /mnt - < ARM-pkglist.txt
    _copy_stuff_for_chroot
    _fstab_uuid
    # change extlinux.conf to UUID instead of partition label.
    partition=$(sed 's#\/dev\/##g' <<< $PARTNAME2)
    uuidno="root=UUID="$(lsblk -o NAME,UUID | grep $partition | awk '{print $2}')
    # uuidno should now be root=UUID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXX
    old=$(grep 'root=' /mnt/boot/extlinux/extlinux.conf | awk '{print $5}')

    case $FORMAT in
        btrfs) btrfsoptions=" rootflags=subvol=@ rootfstype=btrfs fsck.repair=no "
               uuidno=" "$uuidno$btrfsoptions
               sed -i "s#$old#$uuidno#" /mnt/boot/extlinux/extlinux.conf
               ;;
        ext4)  sed -i "s#$old#$uuidno#" /mnt/boot/extlinux/extlinux.conf
               ;;
    esac
}   # End of function _install_Pinebook_image

_install_OdroidN2_image() {

    local partition
    local uuidno
    local boot_options
    local new

    pacstrap -cGM /mnt - < ARM-pkglist.txt
    _copy_stuff_for_chroot
    cp /mnt/boot/boot.ini /mnt/boot/boot.ini.orig
    cp n2-boot.ini /mnt/boot/boot.ini
    _fstab_uuid
    # change boot.ini to UUID instead of partition label.
    partition=$(sed 's#\/dev\/##g' <<< $PARTNAME2)
    uuidno="\"root=UUID="$(lsblk -o NAME,UUID | grep $partition | awk '{print $2}')
    case $FORMAT in
        btrfs) boot_options=" rootwait rw fsck.repair=no\""
               new="setenv bootargs "$uuidno"$boot_options"
               sed -i "s/^setenv bootargs \"root=.*/$new/" /mnt/boot/boot.ini
               btrfsoptions="setenv bootargs \"\${bootargs} rootflags=subvol=@ rootfstype=btrfs\""
               sed -i "/^setenv bootargs \"root=.*/a $btrfsoptions" /mnt/boot/boot.ini
               ;;
        ext4)  boot_options=" rootwait rw fsck.repair=yes\""
               new="setenv bootargs "$uuidno"$boot_options"
               sed -i "s/^setenv bootargs \"root=.*/$new/" /mnt/boot/boot.ini
               ;;
    esac
}   # End of function _install_OdroidN2_image


_install_RPi_image() { 

    local partition
    local uuidno
    local boot_options
    local new

    pacstrap -cGM /mnt - < ARM-pkglist.txt
    _copy_stuff_for_chroot
    _fstab_uuid
    partition=$(sed 's#\/dev\/##g' <<< $PARTNAME2)
    uuidno="root=UUID="$(lsblk -o NAME,UUID | grep $partition | awk '{print $2}')
    # uuidno should now be "root=UUID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXX "
    case $FORMAT in
        btrfs) boot_options=" rootflags=subvol=@ rootfstype=btrfs fsck.repair=no rw rootwait console=serial0,115200 console=tty1" ;;
        ext4)  boot_options=" rw rootwait console=serial0,115200 console=tty1 fsck.repair=yes" ;;
    esac
    new=$uuidno"$boot_options"
    printf "$new\n" > /mnt/boot/cmdline.txt
}   # End of function _install_RPi_image

_partition_format_mount() {

   fallocate -l 8.5G test.img
#   fallocate -l 10G test.img   # For Radxa 5B
   fallocate -d test.img

   DVN=$(losetup --find --show test.img)
   DEVICENAME="$DVN"
   printf "\n${CYAN} DEVICENAME ${NC}\n"
   echo $DEVICENAME
   echo $DVN

   if [ "$DEVICENAME" != "/dev/loop0" ]; then
      printf "\n\n${RED}A loop device exists. Delete extra loop devices.${NC}\n\n"
      exit
   fi
   ##### Determine data device size in MiB and partition ###
   printf "\n${CYAN}Partitioning, & formatting storage device...${NC}\n"
   DEVICESIZE=8192
#   DEVICESIZE=10100  #For Radxa 5B
   printf "\n${CYAN}Partitioning storage device $DEVICENAME...${NC}\n"

   case $PLATFORM in   
      RPi4 | RPi5 | ServRPi) _partition_RPi4 ;;
      OdroidN2 | Servodn)    _partition_OdroidN2 ;;
      Pinebook)              _partition_Pinebook ;;
      Radxa5b)               _partition_Radxa5b ;;
   esac

   if [ "$PLATFORM" == "ServRPi" ] || [ "$PLATFORM" == "Servodn" ]; then
      $FORMAT="ext4"
   fi
  
   printf "\n${CYAN}Formatting storage device $DEVICENAME...${NC}\n"
   printf "\n${CYAN}If \"/dev/sdx contains a ext4 file system Labelled XXXX\" or similar appears, Enter: y${NC}\n\n\n"
   PARTNAME1=$DEVICENAME"p1"
   mkfs.fat -n BOOT_ENOS $PARTNAME1
   PARTNAME2=$DEVICENAME"p2"
   case $FORMAT in
        ext4)  mkfs.ext4 -F -L ROOT_ENOS $PARTNAME2
               mount $PARTNAME2 /mnt
               mkdir /mnt/boot
               mount $PARTNAME1 /mnt/boot
               ;;
        btrfs) mkfs.btrfs -f -L ROOT_ENOS $PARTNAME2
               mkdir /mnt/boot
               mount $PARTNAME2 /mnt
               btrfs subvolume create /mnt/@
               btrfs subvolume create /mnt/@home
               btrfs subvolume create /mnt/@log
               btrfs subvolume create /mnt/@cache
               umount /mnt
               o_btrfs=defaults,compress=zstd:4,noatime,commit=120
               mount -o $o_btrfs,subvol=@ $PARTNAME2 /mnt
               mkdir -p /mnt/{boot,home,var/log,var/cache}
               mount -o $o_btrfs,subvol=@home $PARTNAME2 /mnt/home
               mount -o $o_btrfs,subvol=@log $PARTNAME2 /mnt/var/log
               mount -o $o_btrfs,subvol=@cache $PARTNAME2 /mnt/var/cache
               mount $PARTNAME1 /mnt/boot
               ;;
   esac

} # end of function _partition_format_mount

_check_if_root() {
    local whiptail_installed

    if [ $(id -u) -ne 0 ]
    then
          printf "${RED}Error - Cannot Continue. Please run this script as sudo or root.${NC}\n"
          exit
    fi
    if [[ "$SUDO_USER" == "" ]]; then
         USERNAME=$USER
    else
         USERNAME=$SUDO_USER
    fi
}  # end of function _check_if_root

_arch_chroot(){
    # arch-chroot dir-to-mount file-on-mounted-dir-to-execute
    arch-chroot /mnt /root/script-image-chroot.sh
}

_create_image(){

    local DEVICENAME

    case $PLATFORM in
       RPi4)     DEVICENAME="rpi4" ;;
       RPi5)     DEVICENAME="rpi5" ;;
       OdroidN2) DEVICENAME="odroid-n2" ;;
       Pinebook) DEVICENAME="pbp" ;;
       Radxa5b)  DEVICENAME="radxa-5b" ;;
       ServRPi)  DEVICENAME="server-rpi" ;;
       Servodn)  DEVICENAME="server-odroid-n2" ;;
    esac
          xz -kvfT0 -2 test.img
          case $FORMAT in
             ext4) cp test.img.xz /home/$USERNAME/endeavouros-arm/test-images/enosLinuxARM-$DEVICENAME-latest.img.xz ;;
             btrfs) cp test.img.xz /home/$USERNAME/endeavouros-arm/test-images/enosLinuxARM-$DEVICENAME-btrfs-latest.img.xz ;;
          esac
          printf "\n\nCreating the image is finished.\nand will calculate a sha512sum\n\n"
          cd /home/$USERNAME/endeavouros-arm/test-images/
          case $FORMAT in
             ext4) sha512sum enosLinuxARM-$DEVICENAME-latest.img.xz > "enosLinuxARM-$DEVICENAME-latest.img.xz.sha512sum" ;;
             btrfs) sha512sum enosLinuxARM-$DEVICENAME-latest.img.xz > "enosLinuxARM-$DEVICENAME-btrfs-latest.img.xz.sha512sum" ;;
          esac
          cd $WORKDIR
}  # end of function _create_image

_create_rootfs(){
    case $PLATFORM in
       OdroidN2)# time bsdtar --use-compress-program=zstdmt -cf /home/$USERNAME/endeavouros-arm/test-images/enosLinuxARM-odroid-n2-latest.tar.zst *
          time bsdtar -cf - * | zstd -z --rsyncable -10 -T0 -of /home/$USERNAME/endeavouros-arm/test-images/enosLinuxARM-odroid-n2-latest.tar.zst
          printf "\n\nbsdtar is finished creating the image.\nand will calculate a sha512sum\n\n"
          cd ..
          dir=$(pwd)
          cd /home/$USERNAME/endeavouros-arm/test-images/
          sha512sum enosLinuxARM-odroid-n2-latest.tar.zst > enosLinuxARM-odroid-n2-latest.tar.zst.sha512sum
          cd $dir ;;
       RPi4) # time bsdtar --use-compress-program=zstdmt -cf /home/$USERNAME/endeavouros-arm/test-images/enosLinuxARM-rpi4-latest.tar.zst *
          time bsdtar -cf - * | zstd -z --rsyncable -10 -T0 -of /home/$USERNAME/pudges-place/server-images/enosARM-server-rpi4-latest.tar.zst
          printf "\n${CYAN}bsdtar is finished creating the image.\nand will calculate a sha512sum${NC}\n"

          cd $WORKDIR
          dir=$(pwd)
          cd /home/$USERNAME/pudges-place/server-images/
          sha512sum enosARM-server-rpi4-latest.tar.zst > enosARM-server-rpi4-latest.tar.zst.sha512sum
          cd $dir ;;
    esac
}  # end of function _create_rootfs

_help() {
   # Display Help
   printf "\n\nHELP\n"
   printf "Build EndeavourOS ARM Images\n"
   printf "options:\n"
   printf " -h  Print this Help.\n\n"
   printf "This option is required\n"
   printf " -p  enter platform: rpi4 rpi5 odn pbp rad srpi sodn\n\n"
   printf "These options are not required.\n"
   printf "if -f and/or -c are not entered, the paramaters in () are the defaults\n"
   printf " -f  format type: (e for ext4) or b for btrfs \n"
   printf " -c  create image: (y) or n\n"
   printf "example: sudo ./build-server-image-eos.sh -p rpi4 -f e -c y \n\n"
   printf "Ensure directory \"/home/$USERNAME/endeavouros-arm/test-images\" exists\n"
}

_read_options() {
    # Available options
    opt=":p:f:c:h:"
    local OPTIND

    if [[ ! $@ =~ ^\-.+ ]]
    then
      echo "The script requires an argument, aborting"
      _help
      exit 1
    fi

    while getopts "${opt}" arg; do
      case $arg in
        p)
          PLAT="${OPTARG}"
          ;;
        f)
          FORM="${OPTARG}"
          ;;
        c)
          CRE="${OPTARG}"
          ;;
        \?)
          echo "Option -${OPTARG} is not valid, aborting"
          _help
          exit 1
          ;;
        h|?)
          _help
          exit 1
          ;;
        :)
          echo "Option -${OPTARG} requires an argument, aborting"
          _help
          exit 1
          ;;
      esac
    done
    shift $((OPTIND-1))

    case $PLAT in
         rpi4) PLATFORM="RPi4" ;;
         rpi5) PLATFORM="RPi5" ;;
         odn) PLATFORM="OdroidN2" ;;
         pbp) PLATFORM="Pinebook" ;;
         rad) PLATFORM="Radxa5b" ;;
         srpi) PLATFORM="ServRPi" ;;
         sodn) PLATFORM="Servodn" ;;        
         *) PLAT1=true;;
    esac

    case $FORM in
         e) FORMAT="ext4" ;;
         b) FORMAT="btrfs" ;;
         *) FORMAT="ext4" ;;
    esac

    case $CRE in
         y) CREATE=true ;;
         n) CREATE=false ;;
         *) CREATE=true ;;
    esac
}


#################################################
# beginning of script
#################################################

Main() {
    # VARIABLES
    PLAT=" "
    PLATFORM=" "     # e.g. OdroidN2, rpi4, ServRPi, etc.
    DEVICENAME=" "   # storage device name e.g. /dev/sda
    DEVICESIZE="1"
    PARTNAME1=" "
    PARTNAME2=" "
    USERNAME=" "
    CRE=" "
    CREATE=" "
    FORM=" "
    FORMAT=" "
    ARCH="$(uname -m)"
    WORKDIR=$(pwd)

    # Declare color variables
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No

    pacman -S --noconfirm --needed libnewt arch-install-scripts time sed # for whiplash dialog
    _check_if_root
    _read_options "$@"

    rm -rf test.img test.img.xz

    _partition_format_mount  # function to partition, format, and mount a uSD card or eMMC card
    cp base-packages.txt  ARM-pkglist.txt
    case $PLATFORM in
       RPi4)     grep -w "$PLATFORM" base-device-addons.txt | awk '{print $2}' >> ARM-pkglist.txt
                 _install_RPi_image ;;
       RPi5)     grep -w "$PLATFORM" base-device-addons.txt | awk '{print $2}' >> ARM-pkglist.txt
                 _install_RPi_image ;;
       OdroidN2) grep -w "$PLATFORM" base-device-addons.txt | awk '{print $2}' >> ARM-pkglist.txt
                 _install_OdroidN2_image ;;
       Pinebook) grep -w "$PLATFORM" base-device-addons.txt | awk '{print $2}' >> ARM-pkglist.txt
                 _install_Pinebook_image ;;
       Radxa5b)  grep -w "$PLATFORM" base-device-addons.txt | awk '{print $2}' >> ARM-pkglist.txt
#       cp Radxa5b-base-pkglist.txt ARM-pkglist.txt
                 _install_Radxa5b_image ;; 
       ServRPi)  cp pkglist-rpi4-server.txt ARM-pkglist.txt
                 _install_RPi_image ;;
       Servodn)  cp pkglist-odn-server.txt ARM-pkglist.txt
                 _install_OdroidN2_image ;;  
    esac
    rm ARM-pkglist.txt
    printf "\n\n${CYAN}arch-chroot for configuration.${NC}\n\n"
    _arch_chroot

    case $PLATFORM in
      OdroidN2 | Servodn)  dd if=/mnt/boot/u-boot.bin of=$DEVICENAME conv=fsync,notrunc bs=512 seek=1 ;;
      Pinebook)  dd if=/mnt/boot/Tow-Boot.noenv.bin of=$DEVICENAME seek=64 conv=notrunc,fsync
                 sleep 5 ;;
#      Radxa5b) mv /mnt/boot/* //mnt/root ;;
    esac

   if [ "$FORMAT" == "btrfs" ]; then
       umount /mnt/home /mnt/var/log /mnt/var/cache

   fi

#   if [ "$PLATFORM" != "Radxa5b" ]; then
   umount /mnt/boot
   sleep 5
   umount /mnt
#   fi
#   umount /mnt
#   rm -rf /mnt

#   if mountpoint -q /mnt
#   then
#     printf "\n\nloop0 is still mounted\n"
#     read z
#   fi
#   if [ "$PLATFORM" == "Radxa5b" ]; then
#     _create_image
#   fi

    losetup -d /dev/loop0

    if $CREATE ; then
       printf "\n${CYAN}Creating Image${NC}\n"
       _create_image
       printf "\n${CYAN}Created Image${NC}\n\n"
    fi

#    losetup -d /dev/loop0

    exit
}

Main "$@"
