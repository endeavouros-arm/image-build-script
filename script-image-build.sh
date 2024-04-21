#!/bin/bash

_partition_OdroidN2() {
    parted --script -a minimal $DEVICENAME \
    mklabel msdos \
    unit mib \
    mkpart primary fat32 2MiB 258MiB \
    mkpart primary 258MiB $DEVICESIZE"MiB" \
    quit
}

_partition_RPi4() {
    parted --script -a minimal $DEVICENAME \
    mklabel gpt \
    unit MiB \
    mkpart primary fat32 2MiB 202MiB \
    mkpart primary ext4 202MiB $DEVICESIZE"MiB" \
    quit
}

_copy_stuff_for_chroot() {
    mkdir $WORKDIR/MP/home/alarm
    cp script-image-chroot.sh $WORKDIR/MP/root/
    cp config-eos.sh $WORKDIR/MP/root/
    cp resize-fs.service $WORKDIR/MP/root
    cp resize-fs.sh $WORKDIR/MP/root
#    cp smb.conf $WORKDIR/MP/home/alarm
    cp config-eos.service $WORKDIR/MP/home/alarm/
    cp lsb-release $WORKDIR/MP/home/alarm
    cp DE-pkglist.txt $WORKDIR/MP/alarm
    cp os-release $WORKDIR/MP/home/alarm
    cp rpi4-config.txt $WORKDIR/MP/home/alarm/
#    case $PLATFORM in
#      RPi4)    cp rpi4-config.txt $WORKDIR/MP/home/alarm/ ;;
#      OdroidN2) cp n2-boot.ini $WORKDIR/MP/home/alarm ;;
#    esac
    printf "$PLATFORM\n" > platformname
    cp platformname $WORKDIR/MP/root/
    rm platformname
    printf "$TYPE\n" > type
    cp type $WORKDIR/MP/root/
    rm type
}   #  end of function _copy_stuff_for_chroot

_fstab_uuid() {

    local fstabuuid=""

    printf "\n${CYAN}Changing /etc/fstab to UUID numbers instead of a lable such as /dev/sda.${NC}\n"
    mv $WORKDIR/MP/etc/fstab $WORKDIR/MP/etc/fstab-bkup
    partition=$(sed 's#\/dev\/##g' <<< $PARTNAME1)
    fstabuuid="UUID="$(lsblk -o NAME,UUID | grep $partition | awk '{print $2}')
    # fstabuuid should be UUID=XXXX-XXXX
    printf "# /etc/fstab: static file system information.\n#\n# Use 'blkid' to print the universally unique identifier for a device; this may\n" > $WORKDIR/MP/etc/fstab
    printf "# be used with UUID= as a more robust way to name devices that works even if\n# disks are added and removed. See fstab(5).\n" >> $WORKDIR/MP/etc/fstab
    printf "#\n# <file system>             <mount point>  <type>  <options>  <dump>  <pass>\n\n"  >> $WORKDIR/MP/etc/fstab
    printf "$fstabuuid  /boot  vfat  defaults  0  0\n\n" >> $WORKDIR/MP/etc/fstab
}   # end of fucntion _fstab_uuid

_install_OdroidN2_image() {

    pacstrap -cGM $WORKDIR/MP - < $WORKDIR/ARM-pkglist.txt
    _copy_stuff_for_chroot
    cp $WORKDIR/MP/boot/boot.ini $WORKDIR/MP/boot/boot.ini.orig
    cp $WORKDIR/n2-boot.ini $WORKDIR/MP/boot/boot.ini
    _fstab_uuid
    partition=$(sed 's#\/dev\/##g' <<< $PARTNAME2)
    uuidno="root=UUID="$(lsblk -o NAME,UUID | grep $partition | awk '{print $2}')
    # uuidno should now be "root=UUID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXX  
    old=$(cat $WORKDIR/MP/boot/boot.ini | grep root= | awk '{print $3}')
    sed -i "s#$old#$uuidno#" $WORKDIR/MP/boot/boot.ini    
#    dd if=MP/boot/u-boot.bin of=$DEVICENAME conv=fsync,notrunc bs=512 seek=1
#    sed -i '/setenv bootargs "root=UUID=/c\setenv bootargs "root=/dev/mmcblk1p2 rootwait rw"' MP/boot/boot.ini

}   # End of function _install_OdroidN2_image


_install_RPi_image() { 

    pacstrap -cGM $WORKDIR/MP - < $WORKDIR/ARM-pkglist.txt
    _copy_stuff_for_chroot
#    case $TYPE in
#      Rootfs)  sed -i 's/mmcblk0/mmcblk1/' $WORKDIR/MP/etc/fstab
#               ;;
#      Image)  _fstab_uuid
              _fstab_uuid
              partition=$(sed 's#\/dev\/##g' <<< $PARTNAME2)
              uuidno="root=UUID="$(lsblk -o NAME,UUID | grep $partition | awk '{print $2}')
              # uuidno should now be "root=UUID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXX
              old=$(cat $WORKDIR/MP/boot/cmdline.txt | grep root= | awk '{print $1}')
              sed -i "s#$old#$uuidno#" $WORKDIR/MP/boot/cmdline.txt
#              ;;
#    esac
}  # End of function _install_RPi_image

#_install_RPi5_image() { 
#    pacstrap -cGM $WORKDIR/MP - < $WORKDIR/pkglist-rpi5.txt
#    _copy_stuff_for_chroot
#    _fstab_uuid
#    partition=$(sed 's#\/dev\/##g' <<< $PARTNAME2)
#    uuidno="root=UUID="$(lsblk -o NAME,UUID | grep $partition | awk '{print $2}')
    # uuidno should now be "root=UUID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXX
#    old=$(cat $WORKDIR/MP/boot/cmdline.txt | grep root= | awk '{print $1}')
#    sed -i "s#$old#$uuidno#" $WORKDIR/MP/boot/cmdline.txt
#}  # End of function _install_RPi5_image

_partition_format_mount() {

   fallocate -l 7.5G test.img
   fallocate -d test.img

   DVN=$(losetup --find --show test.img)
   DEVICENAME="$DVN"
   printf "\n${CYAN} DEVICENAME ${NC}\n"
   echo $DEVICENAME
   echo $DVN
   printf "\nlosetup -a = "
   losetup -a
   printf "\n${CYAN}Ensure that only /dev/loop0 exists, then press Enter${NC}\n"
   read z
   ##### Determine data device size in MiB and partition ###
   printf "\n${CYAN}Partitioning, & formatting storage device...${NC}\n"
   DEVICESIZE=$(fdisk -l | grep "Disk $DEVICENAME" | awk '{print $5}')
   ((DEVICESIZE=$DEVICESIZE/1048576))
   ((DEVICESIZE=$DEVICESIZE-10))  # for some reason, necessary for USB thumb drives
   printf "\n${CYAN}Partitioning storage device $DEVICENAME...${NC}\n"

   case $PLATFORM in   
      RPi4 | RPi5) _partition_RPi4 ;;
      OdroidN2) _partition_OdroidN2 ;;
   esac
  
   printf "\n${CYAN}Formatting storage device $DEVICENAME...${NC}\n"
   printf "\n${CYAN}If \"/dev/sdx contains a ext4 file system Labelled XXXX\" or similar appears, Enter: y${NC}\n\n\n"

   DEVICENAME=$DEVICENAME"p"

   PARTNAME1=$DEVICENAME"1"
   mkfs.fat -n BOOT_ENOS $PARTNAME1
   PARTNAME2=$DEVICENAME"2"
   mkfs.ext4 -F -L ROOT_ENOS $PARTNAME2
   mkdir $WORKDIR/MP
   mount $PARTNAME2 $WORKDIR/MP
   mkdir $WORKDIR/MP/boot
   mount $PARTNAME1 $WORKDIR/MP/boot
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
    arch-chroot $WORKDIR/MP /root/script-image-chroot.sh
}


_create_image(){

    local DEVICENAME

    case $PLATFORM in
       OdroidN2) DEVICENAME="odroid-n2" ;;
       RPi4)     DEVICENAME="rpi4" ;;
       RPi5)     DEVICENAME="rpi5" ;;
    esac
          xz -kvfT0 -2 $WORKDIR/test.img
          cp $WORKDIR/test.img.xz /home/$USERNAME/endeavouros-arm/test-images/enosLinuxARM-$DEVICENAME-latest.img.xz
          printf "\n\nCreating the image is finished.\nand will calculate a sha512sum\n\n"
          cd /home/$USERNAME/endeavouros-arm/test-images/
          sha512sum enosLinuxARM-$DEVICENAME-latest.img.xz > "enosLinuxARM-$DEVICENAME-latest.img.xz.sha512sum"
          cd $WORKDIR

#       RPi4)
#          xz -kvfT0 -2 $WORKDIR/test.img
#          cp $WORKDIR/test.img.xz /home/$USERNAME/endeavouros-arm/test-images/enosARM-server-rpi4-latest.img.xz
#          printf "\n\nCreating the image is finished.\nand will calculate a sha512sum\n\n"
#          cd /home/$USERNAME/endeavouros-arm/test-images/
#          sha512sum enosARM-server-rpi4-latest.img.xz > "enosARM-server-rpi4-latest.img.xz.sha512sum"
#          cd $WORKDIR ;;

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
   printf "\nHELP\n"
   printf "Build EndeavourOS ARM Images\n"
   printf "options:\n"
   printf " -h  Print this Help.\n\n"
   printf "These options are required\n"
   printf " -p  enter platform: rpi4 rpi5 or odn\n"
#   printf " -t  image type: r (for rootfs) or i (for image) \n"
   printf " -c  create image: (y) or n\n"
   printf "example: sudo ./build-server-image-eos.sh -p rpi4 -c y \n"
   printf "Ensure directory \"/home/$USERNAME/endeavouros-arm/test-images\" exists\n"
#   printf "Ensure that the directory $IMAGEDIR exists\n\n"
}

_read_options() {
    # Available options
    opt=":p:t:c:h:"
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
#        t)
#          TYP="${OPTARG}"
#          ;;
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
     *) PLAT1=true;;
    esac

#    case $TYP in
#         r) TYPE="Rootfs" ;;
#         i) TYPE="Image" ;;
#    esac
     TYPE="Image"

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
    PLAT=""
    PLATFORM=" "     # e.g. OdroidN2, RPi4, etc.
    DEVICENAME=" "   # storage device name e.g. /dev/sda
    DEVICESIZE="1"
    PARTNAME1=" "
    PARTNAME2=" "
    USERNAME=" "
    CRE=" "
    CREATE=" "
    TYP=" "
    TYPE=" "
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

    rm -rf $WORKDIR/test.img $WORKDIR/test.img.xz

    _partition_format_mount  # function to partition, format, and mount a uSD card or eMMC card
    cp $WORKDIR/ISO-packages.txt  $WORKDIR/ARM-pkglist.txt
    case $PLATFORM in
       RPi4)    cat $WORKDIR/addons-rpi4.txt >> $WORKDIR/ARM-pkglist.txt
                 _install_RPi_image ;;
       RPi5)     cat $WORKDIR/addons-rpi5.txt >> $WORKDIR/ARM-pkglist.txt
                 _install_RPi_image ;;
       OdroidN2) cat $WORKDIR/addons-odn.txt >> $WORKDIR/ARM-pkglist.txt
                 _install_OdroidN2_image ;;
    esac
    rm $WORKDIR/ARM-pkglist.txt

#    case $PLATFORM in
#       RPi4 | RPi5)   _install_RPi_image ;;
#       RPi5)    _install_RPi_image ;;
#       OdroidN2) _install_OdroidN2_image ;;
#    esac

    printf "\n\n${CYAN}arch-chroot for configuration.${NC}\n\n"
    _arch_chroot

    case $PLATFORM in
      OdroidN2)
         dd if=MP/boot/u-boot.bin of=$DEVICENAME conv=fsync,notrunc bs=512 seek=1
    esac

#    if $CREATE ; then
#       if [ "$TYPE" == "Rootfs" ]; then
#            printf "\n\n${CYAN}Creating Rootfs${NC}\n\n"
#            _create_rootfs
#            printf "\n\n${CYAN}Created Rootfs${NC}\n\n"
#       fi
#    fi

    umount $WORKDIR/MP/boot $WORKDIR/MP
    rm -rf $WORKDIR/MP

    losetup -d /dev/loop0

    if $CREATE ; then
#        if [ "$TYPE" == "Image" ]; then
            printf "\n${CYAN}Creating Image${NC}\n"
            _create_image
            printf "\n${CYAN}Created Image${NC}\n\n"
#        fi
    fi

    exit
}

Main "$@"
