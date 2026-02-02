#!/bin/bash

ZONE_DIR="/usr/share/zoneinfo/"
declare -a TIMEZONE_LIST

generate_timezone_list() {

	input=$1
	if [[ -d $input ]]; then
		for i in "$input"/*; do
			generate_timezone_list $i
		done
	else
		TIMEZONE=${input/#"$ZONE_DIR/"}
		TIMEZONE_LIST+=($TIMEZONE)
		TIMEZONE_LIST+=("")
	fi
}

_offer_wifi(){
    # offer to connect to WiFi
    whiptail  --title "EndeavourOS ARM Setup - Connect to WiFi"  --yesno --yes-button "No" --no-button "Yes" "           If no wired ethernet connection is available you need\n            to connect to WiFi with a network SSID and password.\n\n                     Do you wish to connect to WiFi? \n\n" 10 80 15 3>&2 2>&1 1>&3
    if [ "$?" == "1" ]; then
    nmtui-connect
    fi
}  # end of _offer_wifi

_offer_bluetooth() {
    # offer to enable bluetooth
    whiptail  --title "EndeavourOS ARM Setup - Enable Bluetooth"  --yesno --yes-button "No" --no-button "Yes" "                     Bluetooth is disabled by default\n                    on RPi 4b, RPi 5, and Pinebook Pro. \n\n                     Do you wish to enable Bluetooth? \n\n" 11 80 15 3>&2 2>&1 1>&3
    if [ "$?" == "1" ]; then
       sed -i 's/dtoverlay=disable-bt/# dtoverlay=disable-bt/g' /boot/config.txt
       systemctl enable bluetooth
       whiptail  --title "EndeavourOS ARM Setup - Bluetooth enabled"  --msgbox "                Bluetooth has been enabled in /boot/config.txt\n               See more on the EndeavourOS WiKi bluetooth page.\n          https://discovery.endeavouros.com/audio/bluetooth/2021/03/ \n\n" 10 80 15 3>&2 2>&1 1>&3
    fi
}   # end of _offer_bluetooth

_edit_mirrorlist() {
    local user_confirmation
    local changes
    local mirrors
    local mirror1
    local old
    local new
    local file
    local str

    whiptail  --title "EndeavourOS ARM Setup - mirrorlist"  --yesno "\n     Mirrorlist uses a Geo-IP based mirror selection and load balancing.\n          Do you wish to override this and choose mirrors near you?\n\n" 10 80 3>&2 2>&1 1>&3
    user_confirmation=$?
    changes=0
    while [ "$user_confirmation" == "0" ]
    do
        tail -n +11 /etc/pacman.d/mirrorlist | grep -e ^"###" -e ^"# S" -e^"  S"  > tmp-mirrorlist
        readarray -t mirrors < tmp-mirrorlist

        mirror1=$(whiptail --cancel-button 'Done' --notags --title "EndeavourOS ARM Setup - Mirror Selection" --menu "\n Please choose a mirror to enable.\n Only choose lines starting with: \"# Server\" or \"  Server\"\n Enter will toggle the chosen item between commented and uncommented.\n Note: You can navigate to different sections with Page Up/Down keys.\n When finished selecting, press right arrow key twice" 34 80 20 \
           "${mirrors[0]}" "${mirrors[0]}" \
           "${mirrors[1]}" "${mirrors[1]}" \
           "${mirrors[2]}" "${mirrors[2]}" \
           "${mirrors[3]}" "${mirrors[3]}" \
           "${mirrors[4]}" "${mirrors[4]}" \
           "${mirrors[5]}" "${mirrors[5]}" \
           "${mirrors[6]}" "${mirrors[6]}" \
           "${mirrors[7]}" "${mirrors[7]}" \
           "${mirrors[8]}" "${mirrors[8]}" \
           "${mirrors[9]}" "${mirrors[9]}" \
           "${mirrors[10]}" "${mirrors[10]}" \
           "${mirrors[11]}" "${mirrors[11]}" \
           "${mirrors[12]}" "${mirrors[12]}" \
           "${mirrors[13]}" "${mirrors[13]}" \
           "${mirrors[14]}" "${mirrors[14]}" \
           "${mirrors[15]}" "${mirrors[15]}" \
           "${mirrors[16]}" "${mirrors[16]}" \
           "${mirrors[17]}" "${mirrors[17]}" \
           "${mirrors[18]}" "${mirrors[18]}" \
           "${mirrors[19]}" "${mirrors[19]}" \
           "${mirrors[20]}" "${mirrors[20]}" \
           "${mirrors[21]}" "${mirrors[21]}" \
           "${mirrors[22]}" "${mirrors[22]}" \
           "${mirrors[23]}" "${mirrors[23]}" \
           "${mirrors[24]}" "${mirrors[24]}" \
           "${mirrors[25]}" "${mirrors[25]}" \
           "${mirrors[26]}" "${mirrors[26]}" \
           "${mirrors[27]}" "${mirrors[27]}" \
           "${mirrors[28]}" "${mirrors[28]}" \
           "${mirrors[29]}" "${mirrors[29]}" \
           "${mirrors[30]}" "${mirrors[30]}" \
           "${mirrors[31]}" "${mirrors[31]}" \
           "${mirrors[32]}" "${mirrors[32]}" \
           "${mirrors[33]}" "${mirrors[33]}" \
           "${mirrors[34]}" "${mirrors[34]}" \
           "${mirrors[35]}" "${mirrors[35]}" \
        3>&2 2>&1 1>&3)
        user_confirmation=$?
        if [ "$user_confirmation" == "0" ]; then
           str=${mirror1:0:8}
           case $str in
              "# Server") changes=$((changes+1))
                          old=${mirror1::-12}
                          new=${old/["#"]/" "}
                          sed -i "s|$old|$new|g" /etc/pacman.d/mirrorlist ;;
              "  Server") changes=$((changes+1))
                          old=${mirror1::-12}
                          new=${old/[" "]/"#"}
                          sed -i "s|$old|$new|g" /etc/pacman.d/mirrorlist ;;
                       *) whiptail  --title "EndeavourOS ARM Setup - ERROR"  --msgbox "     You have selected an item that cannot be edited. Please try again.\n     Only select lines that start with \"# Server\" or \"  Server\"\n     Other items are invalid.\n\n" 10 80 3>&2 2>&1 1>&3
           esac
        fi
    done

    if [ $changes -gt 0 ]; then
       sed -i 's|Server = http://mirror.archlinuxarm.org|# Server = http://mirror.archlinuxarm.org|' /etc/pacman.d/mirrorlist
    fi
    file="tmp-mirrorlist"
    if [ -f "$file" ]; then
       rm tmp-mirrorlist
    fi
}   # end of function _edit_mirrorlist

_enable_paralleldownloads() {
    local user_confirmation
    local numdwn
    local new

    whiptail  --title "EndeavourOS ARM Setup - Parallel Downloads"  --yesno "             By default, pacman has Parallel Downloads disabled.\n                  Do you wish to enable Parallel Downloads?\n\n" 8 80 15 3>&2 2>&1 1>&3

    user_confirmation=$?
    if [ "$user_confirmation" == "0" ]; then
       numdwn=$(whiptail --title "EndeavourOS ARM Setup - Parallel Downloads" --menu --notags "\n           When enabled, Pacman has 5 Parallel Downloads as a default.\n                  How many Parallel Downloads do you wish? \n\n" 22 80 9 \
         "2" " 2 Parallel Downloads" \
         "3" " 3 Parallel Downloads" \
         "4" " 4 Parallel Downloads" \
         "5" " 5 Parallel Downloads" \
         "6" " 6 Parallel Downloads" \
         "7" " 7 Parallel Downloads" \
         "8" " 8 Parallel Downloads" \
         "9" " 9 Parallel Downloads" \
         "10" "10 Parallel Downloads" \
       3>&2 2>&1 1>&3)
    fi

    if [[ $numdwn -gt 1 ]]; then
       old=$(cat /etc/pacman.conf | grep ParallelDownloads)
       new="ParallelDownloads = $numdwn"
       sed -i "s|$old|$new|g" /etc/pacman.conf
    fi
}   # end of function _enable_paralleldownloads





_set_time_zone() {
    printf "\n${CYAN}Setting Time Zone...${NC}"
    ln -sf $TIMEZONEPATH /etc/localtime
}

_enable_ntp() {
    printf "\n${CYAN}Enabling NTP...${NC}"
    timedatectl set-ntp true
    timedatectl timesync-status
    sleep 1
}

_sync_hardware_clock() {
    printf "\n${CYAN}Syncing Hardware Clock${NC}\n\n"
    hwclock -r
    if [ $? == "0" ]
    then
       hwclock --systohc
       printf "\n${CYAN}hardware clock was synced${NC}\n"
    else
       printf "\n${RED}No hardware clock was found${NC}\n"
    fi
}

_set_locale() {
    printf "\n${CYAN}Setting Locale...${NC}\n"
    sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
    locale-gen
    printf "\nLANG=en_US.UTF-8\n\n" > /etc/locale.conf
}

_set_hostname() {
    printf "\n${CYAN}Setting hostname...${NC}"
    printf "\n$HOSTNAME\n\n" > /etc/hostname
}

_config_etc_hosts() {
    printf "\n${CYAN}Configuring /etc/hosts...${NC}"
    printf "\n127.0.0.1\tlocalhost\n" > /etc/hosts
    printf "::1\t\tlocalhost\n" >> /etc/hosts
    printf "127.0.1.1\t$HOSTNAME.localdomain\t$HOSTNAME\n\n" >> /etc/hosts
}

_change_user_alarm() {
    local tmpfile

    printf "\n${CYAN}Delete default username (alarm) and Creating a user...${NC}\n"
    userdel -rf alarm     #delete the default user from the image
#   useradd -m -G users -s /bin/bash -u 1000 "$USERNAME"
    useradd -m -G wheel,sys,rfkill,users -s /bin/bash -u 1000 "$USERNAME"
    printf "\n${CYAN} Updating user password...${NC}\n"
    echo "${USERNAME}:${USERPASSWD}" | chpasswd
    printf "$USERNAME  ALL=(ALL:ALL) ALL" >> /etc/sudoers
    gpasswd -a $USERNAME wheel
}   # End of function _change_user_alarm

_clean_up() {
    # rebranding to EndeavourOS
    sed -i 's/Arch/EndeavourOS/' /etc/issue
    sed -i 's/Arch/EndeavourOS/' /etc/arch-release
}

_completed_notification() {
    printf "\n\n${CYAN}Installation is complete!\n\n"
    printf "\nRemember your new user name and password when logging in.\n"
#    printf "\nSSH server was installed and enabled to listen on port $SSHPORT\n"
    printf "\nfirewalld was installed and enabled.  public is the default zone.\n"
#    printf "\nThe ssh service is in use allowing the appropriate ssh port though.\n"
#    printf "\nsources is set to the IP address of your router, which will only allow"
#    printf "\naccess to the server from your local LAN on the specified port\n\n"

    printf "Pressing Ctrl c will exit the script and give a CLI prompt"
    printf "\nto allow the user to use pacman to add additional packages"
    printf "\nor change configs. This will not remove install files from /root\n\n"
    printf "Pressing the Enter key exits the script, removes all install files, and reboots the computer."
    printf "\nIn some instances, Ctrl+Alt+Del may be necessary for reboot.${NC}\n\n"
}

_lxqt_instuctions() {
   printf "\n####  You have installed LXQT for your desktop ####\n"
   printf "\nWayland is disabled by default, enable Wayland as follows\n"
   printf "\n${RED}After the first boot, do the following:\n"
   printf "In the sddm screen, in the upper left corner, change \"LXQT Desktop Wayland\" to \"LXQT Desktop x11\"\n"
   printf "Then login to LXQT.  A window appears asking to select \"KWIN\" or \"Openbox\" choose either one${NC}\n"
   printf "\n${CYAN}Once booted, in the \"Application Launcher\" choose Preferences - Session Settings\n"
   printf "click on \"\Wayland Settings (Experimental)\"icon\n"
   printf "under \"Wayland Compositor:\" use the down arrow and choos \"kwin_wayland\"\n"
   printf "under \"Screenlock Command:\" type in \"loginctl lock-session\"\n"
   printf "still in \"Session Settings\" click on the \"Basic Settings\" icon\n"
   printf "under \"Window Manager\" click on the down arrow.\n"
   printf "there you choose which x11 window manager (kwin_x11 or openbox) will be enabled after the next logout/reboot\n\n"
   printf "In your home directory will be a text file named \"LXQT_instructions.txt\" with the above instructions${NC}\n"
}

_precheck_setup() {
    local script_directory
    local whiptail_installed
   
    # check where script is installed
    script_directory="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    if [[ "$script_directory" == "/home/alarm/"* ]]; then
       whiptail_installed=$(pacman -Qs libnewt)
       if [[ "$whiptail_installed" != "" ]]; then
          whiptail --title "Error - Cannot Continue" --msgbox "This script is in the alarm user's home folder which will be removed.  \
          \n\nPlease move it to the root user's home directory and rerun the script." 10 80
          exit
       else
          printf "${RED}Error - Cannot Continue. This script is in the alarm user's home folder which will be removed. Please move it to the root user's home directory and rerun the script.${NC}\n"
          exit
       fi
    fi

    # check to see if script was run as root #####
    if [ $(id -u) -ne 0 ]
    then
       whiptail_installed=$(pacman -Qs libnewt)
       if [[ "$whiptail_installed" != "" ]]; then
          whiptail --title "Error - Cannot Continue" --msgbox "Please run this script with sudo or as root" 8 47
          exit
       else
          printf "${RED}Error - Cannot Continue. Please run this script with sudo or as root.${NC}\n"
          exit
       fi
    fi
    # Prevent script from continuing if there's any processes running under the alarm user #
    # as we won't be able to delete the user later on in the script #

    if [[ $(pgrep -u alarm) != "" ]]; then
       whiptail_installed=$(pacman -Qs libnewt)
       if [[ "$whiptail_installed" != "" ]]; then
          whiptail --title "Error - Cannot Continue" --msgbox "alarm user still has processes running. Kill them to continue setup." 8 47
          exit
       else
          printf "${RED}Error - Cannot Continue. alarm user still has processes running. Kill them to continue setup.${NC}\n"
          exit
       fi
    fi
 }  # end of function _precheck_setup

_install_ssd() {
    local user_confirmation
    local finished
    local base_dialog_content
    local dialog_content
    local exit_status
    local datadevicename
    local datadevicesize
    local mntname
    local uuidno

    usbssd=$(whiptail --title "EndeavourOS ARM Setup - SSD Configuration" --menu --notags "\n  You can do the following with a connected USB SSD for data storge:\n\n  Partition & format, create mount points, & config /etc/fstab.\n  Only create Mount points for an existing USB SSD\n  Do nothing\n\n" 16 75 3 \
       "0" "Partion & format, create mount points, config /etc/fstab" \
       "1" "Only create mount points" \
       "2" "Do nothing" \
       3>&2 2>&1 1>&3)

   case $usbssd in
       0)  whiptail  --title "EndeavourOS ARM Setup - SSD Configuration"  --yesno "        Discharge any bodily static by touching something grounded.\n Connect a USB 3 external enclosure with a SSD or hard drive installed\n\n \
       CAUTION: ALL data on this drive will be erased\n \
       Do you want to continue?" 12 80
           user_confirmation="$?"

           if [ $user_confirmation == "0" ]
           then
              finished=1
              base_dialog_content="\nThe following storage devices were found\n\n$(lsblk -o NAME,MODEL,FSTYPE,SIZE,FSUSED,FSAVAIL,MOUNTPOINT)\n\n \
              Enter target device name without a partition designation (e.g. /dev/sda or /dev/mmcblk0):"
              dialog_content="$base_dialog_content"
              while [ $finished -ne 0 ]
              do
                 datadevicename=$(whiptail --title "EndeavourOS ARM Setup - micro SD Configuration" --inputbox "$dialog_content" 27 115 3>&2 2>&1 1>&3)
                 exit_status=$?
                 if [ $exit_status == "1" ]; then
                    printf "\nInstall SSD aborted by user\n\n"
                    return
                 fi
                 if [[ ! -b "$datadevicename" ]]; then
                    dialog_content="$base_dialog_content\n    Not a listed block device, or not prefaced by /dev/ Try again."
                 else
                    case $datadevicename in
                       /dev/sd*)  if [[ ${#datadevicename} -eq 8 ]]; then
                                    finished=0
                                  else
                                     dialog_content="$base_dialog_content\n    Input improperly formatted. Try again."
                                 fi ;;
                  /dev/mmcblk*)  if [[ ${#datadevicename} -eq 12 ]]; then
                                    finished=0
                                 else
                                    dialog_content="$base_dialog_content\n    Input improperly formatted. Try again."
                                 fi ;;
                    esac
                 fi
              done

              ##### Determine data device size in MiB and partition ###
              printf "\n${CYAN}Partitioning, & formatting DATA storage device...${NC}\n"
              datadevicesize=$(fdisk -l | grep "Disk $datadevicename" | awk '{print $5}')
              ((datadevicesize=$datadevicesize/1048576))
              ((datadevicesize=$datadevicesize-1))  # for some reason, necessary for USB thumb drives
              printf "\n${CYAN}Partitioning DATA device $datadevicename...${NC}\n"
              parted --script -a minimal $datadevicename \
              mklabel gpt \
              unit mib \
              mkpart primary 1MiB $datadevicesize"MiB" \
              quit
              sleep 3
              if [[ ${datadevicename:5:4} = "nvme" ]]
              then
                 mntname=$datadevicename"p1"
              else
                 mntname=$datadevicename"1"
              fi
              printf "\n${CYAN}Formatting DATA device $mntname...${NC}\n"
              printf "\n${CYAN}If \"/dev/sdx contains a ext4 file system Labelled XXXX\" or similar appears,    Enter: y${NC}\n\n"
              mkfs.ext4 -F -L DATA $mntname
              sleep 3
              printf "\n${CYAN}Creating mount points /server & /serverbkup${NC}\n\n"
              mkdir /server /serverbkup
              chown root:users /server /serverbkup
              chmod 774 /server /serverbkup
              sleep 2
              printf "\n${CYAN}Adding DATA storage device to /etc/fstab...${NC}"
              cp /etc/fstab /etc/fstab-bkup
              uuidno=$(lsblk -o UUID $mntname)
              uuidno=$(echo $uuidno | sed 's/ /=/g')
              printf "\n# $mntname\n$uuidno      /server          ext4            rw,relatime     0 2\n" >> /etc/fstab
              printf "\n${CYAN} New /etc/fstab${NC}\n"
              cat /etc/fstab
              sleep 4
              printf "\n${CYAN}Mounting DATA device $mntname on /server...${NC}"
              mount $mntname /server
              chown root:users /server /serverbkup
              chmod 774 /server /serverbkup
              printf "\033c"; printf "\n"
              printf "${CYAN}Data storage device summary:\n\n"
              printf "\nAn external USB 3 device was partitioned, formatted, and /etc/fstab was configured.\n"
              printf "This device will be on mount point /server and will be mounted at bootup.\n"
              printf "The mount point /serverbkup was also created for use in backing up the DATA device.${NC}\n"
              printf "\n\nPress Enter to continue\n"
              read -n 1 z
           fi ;;

       1)  mkdir /server /serverbkup
           chown root:users /server /serverbkup
           chmod 774 /server /serverbkup
           printf "${CYAN}Data storage device summary:${NC}\n\n"
           printf "Mount point for the USB SSD DATA device will be on /server\n"
           printf "/etc/fstab will need to be configured.\n\n"
           printf "Mount point /serverbkup was also created for use in backing up the DATA device.\n\n"
           printf "\n\nPress Enter to continue\n"
           read -n 1 z ;;
       2) return ;;
   esac
}  # end of function _install_ssd


 _check_internet_connection() {
   clear
   printf "\n${CYAN}Checking Internet Connection...${NC}\n\n"
       ethernet=$(nmcli dev status | grep 'ethernet  connected' | awk '{print $1}')
       wifi=$(nmcli dev status | grep 'wifi      connected' | awk '{print $1}')
       if [ "$ethernet" == "" ] && [ "$wifi" == "" ]; then
          printf "\n\n${RED}No Internet Connection was detected\nFix your Internet Connection and try again${NC}\n\n"
          exit
       fi
       if [ "$ethernet" != "" ]; then
           printf "\n${CYAN}Network device $ethernet is UP${NC}\n\n"
       fi
       if [ "$wifi" != "" ]; then
           printf "\n${CYAN}Network device $wifi is UP${NC}\n\n"
       fi

    ping -c 3 208.67.220.220 -W 5
    if [ "$?" != "0" ]
    then
       ping -c 3 208.67.222.222 -W 5
    fi
    if [ "$?" != "0" ]
    then
       printf "\n\n${RED}No Internet Connection was detected\nFix your Internet Connection and try again${NC}\n\n"
       exit
    fi
 }  # end of function _check_internet_connection


_odroidn2_desktop() {
     DENAME=$(whiptail --nocancel --title "EndeavourOS ARM Setup - Desktop Selection" --menu --notags "\n              Choose which Desktop Environment to install\n\n" 22 75 12 \
          "0" "No Desktop Environment" \
          "1" "KDE Plasma     (x11 only)" \
          "2" "Xfce4          (x11 only)" \
          "3" "Cinnamon       (Both x11 & Wayland)" \
          "4" "Mate           (Native x11 only)" \
          "5" "LXQT & Openbox (x11 only)" \
          "6" "LXDE & Openbox (Native x11 only)" \
          "7" "i3wm           (Native x11 only)" \
     3>&2 2>&1 1>&3)

          case $DENAME in
             0) DENAME="NONE" ;;
             1) DENAME="PLASMA" ;;
             2) DENAME="XFCE4" ;;
             3) DENAME="CINNAMON" ;;
             4) DENAME="MATE" ;;
             5) DENAME="LXQT" ;;
             6) DENAME="LXDE" ;;
             7) DENAME="I3WM" ;;
          esac
}  # end _odroidn2_desktop

_normal_desktops() {
     DENAME=$(whiptail --nocancel --title "EndeavourOS ARM Setup - Desktop Selection" --menu --notags "\n              Choose which Desktop Environment to install\n\n" 22 75 12 \
          "0" "No Desktop Environment" \
          "1" "KDE Plasma" \
          "2" "Gnome" \
          "3" "Xfce4" \
          "4" "Cinnamon" \
          "5" "Mate" \
          "6" "Budgie" \
          "7" "LXQT & Openbox (Experimental)" \
          "8" "LXDE & Openbox (Experimental)" \
          "9" "i3wm" \
         "10" "Cosmic (Comunity Edition WIP)" \
         3>&2 2>&1 1>&3)

         case $DENAME in
             0) DENAME="NONE" ;;
             1) DENAME="PLASMA" ;;
             2) DENAME="GNOME" ;;
             3) DENAME="XFCE4" ;;
             4) DENAME="CINNAMON" ;;
             5) DENAME="MATE" ;;
             6) DENAME="BUDGIE" ;;
             7) DENAME="LXQT" ;;
             8) DENAME="LXDE" ;;
             9) DENAME="I3WM" ;;
            10) DENAME="COSMIC" ;;
     esac
}  # end _normal_desktops

_user_input() {
    local userinputdone
    local finished
    local description
    local initial_user_password
    local initial_root_password
    local lasttriad
    local xyz

    case $PLATFORM in
            RPi4 | RPi5 | Pinebook)
              _offer_wifi
              _offer_bluetooth ;;
    esac
    _edit_mirrorlist
    _enable_paralleldownloads

    userinputdone=1
    while [ $userinputdone -ne 0 ]
    do
       generate_timezone_list $ZONE_DIR
       TIMEZONE=$(whiptail --nocancel --title "EndeavourOS ARM Setup - Timezone Selection" --menu \
       "\nPlease choose your timezone.\nNote: You can navigate to different sections with Page Up/Down or the A-Z keys." 25 85 14 --cancel-button 'Back' "${TIMEZONE_LIST[@]}" 3>&2 2>&1 1>&3)
       TIMEZONEPATH="${ZONE_DIR}${TIMEZONE}"

       finished=1
       description="\nEnter your desired hostname"
       while [ $finished -ne 0 ]
       do
  	      HOSTNAME=$(whiptail --nocancel --title "EndeavourOS ARM Setup - Configuration" --inputbox "$description" 8 60 3>&2 2>&1 1>&3)
          if [ "$HOSTNAME" == "" ]
          then
	 	    description="\n Host name cannot be blank. Enter your desired hostname"
          else
            finished=0
          fi
       done # enter timezone

       finished=1
       description="\nEnter your full name, i.e. John Doe"
       while [ $finished -ne 0 ]
       do
	      FULLNAME=$(whiptail --nocancel --title "EndeavourOS ARM Setup - User Setup" --inputbox "$description" 8 60 3>&2 2>&1 1>&3)

          if [ "$FULLNAME" == "" ]
          then
             description="\nEntry is blank. Enter your full name"
          else
             finished=0
          fi
       done # enter full name

       finished=1
       description="\nEnter your desired user name"
       while [ $finished -ne 0 ]
       do
	      USERNAME=$(whiptail --nocancel --title "EndeavourOS ARM Setup - User Setup" --inputbox "$description" 8 60 3>&2 2>&1 1>&3)

          if [ "$USERNAME" == "" ]
          then
             description="\nEntry is blank. Enter your desired username"
          else
             finished=0
          fi
       done # username

       finished=1
       initial_user_password=""
       description="\nEnter desired password for $USERNAME"
       while [ $finished -ne 0 ]
       do
	      USERPASSWD=$(whiptail --nocancel --title "EndeavourOS ARM Setup - User Setup" --passwordbox "$description" 10 60 3>&2 2>&1 1>&3)

          if [ "$USERPASSWD" == "" ]; then
              description="\nEntry is blank.\nEnter desired password for $USERNAME"
              initial_user_password=""
          elif [[ "$initial_user_password" == "" ]]; then
              initial_user_password="$USERPASSWD"
              description="\nConfirm password for $USERNAME"
          elif [[ "$initial_user_password" != "$USERPASSWD" ]]; then
              description="\nPasswords do not match.\nEnter desired password for $USERNAME"
              initial_user_password=""
          elif [[ "$initial_user_password" == "$USERPASSWD" ]]; then
              finished=0
         fi
       done # enter user password

       finished=1
       initial_root_password=""
       description="\nEnter desired password for the root user"
       while [ $finished -ne 0 ]
       do
	       ROOTPASSWD=$(whiptail --nocancel --title "EndeavourOS ARM Setup - Root User Setup" --passwordbox "$description" 10 60 3>&2 2>&1 1>&3)
           if [ "$ROOTPASSWD" == "" ]; then
              description="\nEntry is blank. Enter desired password for root user"
              initial_root_password=""
           elif [[ "$initial_root_password" == "" ]]; then
              initial_root_password="$ROOTPASSWD"
              description="\nConfirm password for root user"
           elif [[ "$initial_root_password" != "$ROOTPASSWD" ]]; then
              description="\nPasswords do not match.\nRe-enter desired password for the root user"
              initial_root_password=""
           elif [[ "$initial_root_password" == "$ROOTPASSWD" ]]; then
             finished=0
           fi
       done   # enter root password

       #   Enter SSHPORT
       if [ "$PLATFORM" == "ServRPi" ] || [ "$PLATFORM" == "Servodn" ]; then
          finished=1
          description="\n  For better security, change the SSH port\n  to something besides 22\n\n  Enter the desired SSH port between 8000 and 48000"
          while [ $finished -ne 0 ]
          do
             SSHPORT=$(whiptail --nocancel  --title "EndeavourOS ARM Setup - Server Configuration"  --inputbox "$description" 12 60 3>&2 2>&1 1>&3)

             if [ "$SSHPORT" -eq "$SSHPORT" ] # 2>/dev/null
             then
               if [ $SSHPORT -lt 8000 ] || [ $SSHPORT -gt 48000 ]
               then
                description="\nYour choice is out of range, try again.\n\nEnter the desired SSH port between 8000 and 48000"
                else
                finished=0
               fi
             else
                 description="\nYour choice is not a number, try again.\n\nEnter the desired SSH port between 8000 and 48000"
             fi
          done  # enter SSHPORT

          # enter last triad of IP address
          ETHERNETDEVICE=$(ip r | awk 'NR==1{print $5}')
          ROUTERIP=$(ip r | awk 'NR==1{print $3}')
          THREETRIADS=$ROUTERIP
          xyz=${THREETRIADS#*.*.*.}
          THREETRIADS=${THREETRIADS%$xyz}
          finished=1
          description="\n  Servers work best with a Static IP address. \n  The first three triads of your router are $THREETRIADS\n  For the best router compatibility, the last triad should be between 120 and 250\n\n  Enter the last triad of the desired static IP address $THREETRIADS"
          finished=1
          while [ $finished -ne 0 ]
          do
             lasttriad=$(whiptail --nocancel --title "EndeavourOS ARM Setup - Server Configuration"  --title "SETTING UP THE STATIC IP ADDRESS FOR THE SERVER" --inputbox "$description" 13 88 3>&2 2>&1 1>&3)
             if [ "$lasttriad" -eq "$lasttriad" ] # 2>/dev/null
             then
             if [ $lasttriad -lt 120 ] || [ $lasttriad -gt 250 ]
             then
                description="\nFor the best router compatibility, the last triad should be between 120 and 250\n\nEnter the last triad of the desired static IP address $THREETRIADS\n\nYour choice is out of range. Please try again\n"
             else
                   finished=0
             fi
             else
	         description="\nFor the best router compatibility, the last triad should be between 120 and 250\n\nEnter the last triad of the desired static IP address $THREETRIADS\n\nYour choice is not a number.  Please try again\n"
             fi
          done # enter last triad of IP address

          STATICIP=$THREETRIADS$lasttriad
          STATICIP=$STATICIP"/24"

          whiptail --title "EndeavourOS ARM Setup - Review Settings" --yesno "\n              To review, you entered the following information:\n\n \
          Time Zone: $TIMEZONE \n \
          Host Name: $HOSTNAME \n \
          Full Name: $FULLNAME \n \
          User Name: $USERNAME \n \
          SSH Port:  $SSHPORT \n \
          Static IP: $STATICIP \n\n \
          Is this information correct?" 16 80
          userinputdone="$?"

      else
          if [ "$PLATFORM" == "OdroidN2" ]; then
             _odroidn2_desktop
          else
             _normal_desktops
          fi

       whiptail --title "EndeavourOS ARM Setup - Review Settings" --yesno "\n              To review, you entered the following information:\n\n \
       Time Zone: $TIMEZONE \n \
       Host Name: $HOSTNAME \n \
       Full Name: $FULLNAME \n \
       User Name: $USERNAME \n \
       Desktop:   $DENAME \n\n \
       Is this information correct?" 16 80
       userinputdone="$?"
       fi
   done  # user input finished
clear
}   # end of function _user_input


_desktop_setup() {
    # eos-rankmirrors  #ranks all mirrors
    eos-rankmirrors --ignore hacktegic,funami,leitecastro,sjtu,c0urier # for testing
    if [ "$DENAME" == "NONE" ]; then
        printf "${CYAN}Updating Base Packages${NC}}\n\n"
        pacman -Syyu --noconfirm
    else
        grep -w "$DENAME" /root/DE-pkglist.txt | awk '{print $2}' > packages
        if [ "$PLATFORM" == "OdroidN2" ] && [ "$DENAME" == "PLASMA" ]; then
           printf "plasma-x11-session\n" >> packages
        fi
        printf "${CYAN}Installing $DENAME${NC}\n\n"
        pacman -Syyu --needed --noconfirm - < packages
        rm packages
    fi
    if [ "$DENAME" == "LXQT" ]; then
        sed -i 's/Name=LXQt Desktop/Name=LXQT Desktop x11/g' /usr/share/xsessions/lxqt.desktop
        sed -i 's/Name=LXQt (Wayland)/Name=LXQT Desktop Wayland/g' /usr/share/wayland-sessions/lxqt-wayland.desktop
    fi
    case $DENAME in
       PLASMA | LXQT) systemctl enable sddm.service ;;
       GNOME) systemctl enable gdm ;;
       XFCE4 | CINNAMON | MATE | BUDGIE | LXDE | I3WM) systemctl enable lightdm ;;
       COSMIC) systemctl enable cosmic-greeter ;;
    esac
}   # end of function _desktop_setup

_server_setup() {
    # create static IP with user supplied static IP
    printf "\n${CYAN}Creating configuration file for static IP address...${NC}"
    wiredconnection=$(nmcli con | grep "Wired" | awk '{print $1, $2, $3}')
    nmcli con mod "$wiredconnection" \
    ipv4.addresses "$STATICIP" \
    ipv4.gateway "$ROUTERIP" \
    ipv4.dns "$ROUTERIP,8.8.8.8" \
    ipv4.method "manual"
    systemctl disable NetworkManager.service
    systemctl enable --now NetworkManager.service

    printf "\n${CYAN}Configure SSH...${NC}"
    sed -i "/Port 22/c Port $SSHPORT" /etc/ssh/sshd_config
    sed -i '/PermitRootLogin/c PermitRootLogin no' /etc/ssh/sshd_config
    sed -i '/PasswordAuthentication/c PasswordAuthentication yes' /etc/ssh/sshd_config
    sed -i '/PermitEmptyPasswords/c PermitEmptyPasswords no' /etc/ssh/sshd_config
    systemctl disable sshd.service
    systemctl enable sshd.service


    printf "\n${CYAN}Enable and Configure firewalld...${NC}\n"
    UFWADDR=$THREETRIADS
    UFWADDR+="0/24"
    systemctl enable --now firewalld
    firewall-cmd --reload
    firewall-cmd --permanent --zone=public --service=ssh --remove-port=22/tcp
    firewall-cmd --permanent --zone=public --service=ssh --add-port=$SSHPORT/tcp
    firewall-cmd --permanent --zone=public --remove-service=dhcpv6-client
    firewall-cmd --permanent --zone=public --add-source=$UFWADDR
    firewall-cmd --permanent --zone=public --remove-forward
    firewall-cmd --reload

    secondary_ip=$(ip addr | grep "secondary dynamic" | awk '{print $2}')
    secondary_device=$(ip addr | grep "secondary dynamic" | awk '{print $NF}')
    if [ $secondary_ip ]; then
       printf "\n${CYAN}A secondary device needs to be removed${NC}\n\n"
       ip addr del $secondary_ip dev $secondary_device
       ip addr
    fi

    sleep 3
#    pacman -Syu --noconfirm yay # pahis
}   # end of function _server_setup


#################################################
#          script starts here                   #
#################################################

Main() {
    chvt 2
    TIMEZONE=""
    TIMEZONEPATH=""
    PLATFORM=""    # e.g. OdroidN2, rpi4, ServRPi, etc.
    USERNAME=""
    HOSTNAME=""
    FULLNAME=""
    DENAME=""
    SSHPORT=""
    THREETRIADS=""
    STATICIP=""
    ROUTERIP=""
    ETHERNETDEVICE=""
    UFWADDR=""

    # Declare color variables
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color

    dmesg -n 1    # prevent low level kernel messages from appearing on screen 
    printf "\n${CYAN}   Initiating...please wait.${NC}\n"
    sleep 3

    file="/root/platformname"
    read -d $'\x04' PLATFORM < "$file"

    _precheck_setup    # check various conditions before continuing the script
    _user_input
    _check_internet_connection
    pacman-key --init
    pacman-key --populate archlinuxarm endeavouros 
    pacman-key --lsign-key EndeavourOS
    pacman-key --lsign-key builder@archlinuxarm.org
    sleep 6
    pacman -Syy
    _set_time_zone
    _enable_ntp
    _sync_hardware_clock
    _set_locale
    _set_hostname
    _config_etc_hosts
    printf "\n${CYAN}Updating root user password...${NC}\n\n"
    echo "root:${ROOTPASSWD}" | chpasswd

    case $PLATFORM in
        ServRPi | Servodn) _server_setup
                           _install_ssd ;;
        *) _desktop_setup ;;
    esac

    if [ "$DENAME" == "XFCE4" ]; then
       cp /root/xfce4-desktop.xml /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/
       cp /root/xfce4-backgrounds/eos-wallpaper-1.png /usr/share/backgrounds/xfce/
       cp /root/xfce4-backgrounds/eos-wallpaper-2.png /usr/share/backgrounds/xfce/
       cp /root/xfce4-backgrounds/eos-wallpaper-3.png /usr/share/backgrounds/xfce/
       cp /root/xfce4-backgrounds/eos-wallpaper-4.png /usr/share/backgrounds/xfce/
    fi

    rm /root/xfce4-desktop.xml
    rm -rf /root/xfce4-backgrounds
    _change_user_alarm   # remove user alarm and create new user of choice

    if [ "$DENAME" == "LXDE" ] || [ "$DENAME" == "LXQT" ]; then
       cp -R /root/openbox-configs/.config /home/$USERNAME/
       cp -R /root/openbox-configs/.themes /home/$USERNAME
       cp -R /root/openbox-configs/.gtkrc-2.0 /home/$USERNAME
    fi
    rm -rf /root/openbox-configs/
    systemctl disable resize-fs.service
    rm /etc/systemd/system/resize-fs.service
    rm /root/resize-fs.service
    rm /root/resize-fs.sh
    systemctl disable config-eos.service
    rm /etc/systemd/system/config-eos.service
    rm /root/config-eos.sh
    rm /root/DE-pkglist.txt
    rm /root/platformname
    if [ "$DENAME" == "LXQT" ]; then
       cp /root/lxqt_instructions.txt /home/$USERNAME/
    fi
    rm /root/lxqt_instructions.txt
    _completed_notification
    if [ "$DENAME" == "LXQT" ]; then
       _lxqt_instuctions
    fi
    read -n 1 z
    systemctl reboot
}  # end of Main

Main "$@"
