#!/bin/bash

_check_if_root() {
    if [ $(id -u) -ne 0 ]
    then
      printf "\n\n${RED}PLEASE RUN THIS SCRIPT AS ROOT OR WITH SUDO${NC}\n\n"
      exit
    fi
}   # end of function _check_if_root

_finish_up() {
    printf "\nalias ll='ls -l --color=auto'\n" >> /etc/bash.bashrc
    printf "alias la='ls -al --color=auto'\n" >> /etc/bash.bashrc
    printf "alias lb='lsblk -o NAME,FSTYPE,FSSIZE,LABEL,MOUNTPOINT'\n\n" >> /etc/bash.bashrc

    sed -i 's|# Server = http://mirror.archlinuxarm.org/$arch/$repo| Server = http://mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist
    sed -i 's| Server = http://ca.us.mirror.archlinuxarm.org/$arch/$repo|# Server = http://ca.us.mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist
    sed -i 's| Server = http://fl.us.mirror.archlinuxarm.org/$arch/$repo|# Server = http://fl.us.mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist

    rm /root/script-image-chroot.sh
    rm /root/platformname
#    rm /home/alarm/smb.conf
#    rm /root/type
    case $PLATFORM_NAME in
       ServRPi | Servodn) cp /home/alarm/config-server.service /etc/systemd/system/
                          chmod +x /root/config-server.sh
                          systemctl enable config-server.service
                          ;;
      *)                  cp /home/alarm/config-eos.service /etc/systemd/system/
                          chmod +x /root/config-eos.sh
                          systemctl enable config-eos.service
                          ;;
    esac
    cp /home/alarm/lsb-release /etc/
    cp /home/alarm/os-release /etc/
    sed -i 's/Arch/EndeavourOS/g' /etc/issue
    sed -i 's/Arch/EndeavourOS/g' /usr/share/factory/etc/issue
#    sed -i "s/PRESETS=('default' 'fallback')/PRESETS=('default')/g" /etc/mkinitcpio.d/*.preset
#    rm /boot/Image.gz
#    rm /boot/*fallback.img

    systemctl enable NetworkManager
    systemctl enable systemd-timesyncd
    systemctl enable firewalld
    printf "\n${CYAN}Ready to create an image.${NC}\n"
}   # end of function _finish_up


######################   Start of Script   #################################
Main() {

    PLATFORM_NAME=" "
#    TYPE=" "

   # Declare color variables
      GREEN='\033[0;32m'
      RED='\033[0;31m'
      CYAN='\033[0;36m'
      NC='\033[0m' # No Color

   # STARTS HERE
   dmesg -n 1 # prevent low level kernel messages from appearing during the script

   # read in platformname passed by script-image-build.sh
   file="/root/platformname"
   read -d $'\x04' PLATFORM_NAME < "$file"
#   file="/root/type"
#   read -d $'\x04' TYPE < "$file"

   _check_if_root
#   sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/g' /etc/pacman.conf
   sed -i 's|#Color|Color\nILoveCandy|g' /etc/pacman.conf
   sed -i 's|#VerbosePkgLists|VerbosePkgLists\nDisableDownloadTimeout|g' /etc/pacman.conf
   sed -i '/^\[core\].*/i [endeavouros]\nSigLevel = PackageRequired\nInclude = /etc/pacman.d/endeavouros-mirrorlist\n' /etc/pacman.conf
   if [ "$PLATFORM_NAME" == "Radxa5b" ]; then  
      printf "\n\n[7Ji]\nSigLevel = Never\nServer = https://github.com/7Ji/archrepo/releases/download/$arch\n" >> /etc/pacman.conf
   fi
#   useradd -p "alarm" -G users -s /bin/bash -u 1000 "alarm"
   useradd -G users -s /bin/bash -u 1000 "alarm"
   echo "alarm:alarm" | chpasswd -c SHA256
   printf "\n${CYAN}Setting root user password...${NC}\n\n"
   echo "root:root" | chpasswd -c SHA256
   printf "alarm ALL=(ALL:ALL) NOPASSWD: ALL\n" >> /etc/sudoers
   gpasswd -a alarm wheel
#   chown alarm:alarm /home/alarm/.xinitrc
#   chmod 644 /home/alarm/.xinitrc
#   pwconv

   sed -i 's| Server = http://mirror.archlinuxarm.org/$arch/$repo|# Server = http://mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist
   sed -i 's|# Server = http://ca.us.mirror.archlinuxarm.org/$arch/$repo| Server = http://ca.us.mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist
   sed -i 's|# Server = http://fl.us.mirror.archlinuxarm.org/$arch/$repo| Server = http://fl.us.mirror.archlinuxarm.org/$arch/$repo|g' /etc/pacman.d/mirrorlist

   case $PLATFORM_NAME in
     RPi4 | RPi5 | ServRPi) cp /boot/config.txt /boot/config.txt.orig
                            cp /home/alarm/rpi4-config.txt /boot/config.txt ;;
#     Radxa5b) mkinitcpio -P ;;
   esac

#   if [ "$TYPE" == "Image" ]; then
      cp /root/resize-fs.service /etc/systemd/system/
      chmod +x /root/resize-fs.sh
      systemctl enable resize-fs.service
#   fi

   mkdir -p /etc/samba
   cp /home/alarm/smb.conf /etc/samba/
   _finish_up
   printf "\n${CYAN}Exiting arch-chroot${NC}\n"
}  # end of Main

Main "$@"
