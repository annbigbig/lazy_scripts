#!/bin/bash
# This script will perform lots of work for optimizing Ubuntu 24.04 LTS you've just installed
# before you run this script , please specify some parameters here ;
# these parameters will be used in firewall rules or system settings :
# 
########################################################################################################
OS_TYPE="Server"                        # only two values could work well 'Desktop' or 'Server'
LAN="192.168.251.0/24"                  # The local network that you allow packets come in from there
OPENVPN_NETWORK="10.8.0.0/24"           # The OpenVPN network that you allow packets come in from there
IKEV2VPN_NETWORK="10.10.10.0/24"        # The IKEv2VPN network that you allow packets come in from there
MY_TIMEZONE="Asia/Taipei"               # The timezone that you specify for this VPS node
ADD_SWAP="yes"                          # Do u need swap space ? fill in 'yes' or 'YES' will add swap for u
YOUR_VNC_PASSWORD="vnc"                 # set your vnc password here
########################################################################################################
# no need to setup below , script will know it and use it automatically for u 
WIRED_INTERFACE_NAME="$(ip link show | grep '2:' | cut -d ':' -f 2 | sed 's/^ *//g' | head -1)"
OS_TYPE="$(echo $OS_TYPE | tr '[:lower:]' '[:upper:]')"
########################################################################################################
# useful links: 
# https://www.tecmint.com/set-permanent-dns-nameservers-in-ubuntu-debian/
# https://linuxconfig.org/how-to-switch-back-networking-to-etc-network-interfaces-on-ubuntu-20-04-focal-fossa-linux
# https://vitux.com/ubuntu-network-configuration/
# https://linuxhint.com/update-resolv-conf-on-ubuntu/
# https://bash.cyberciti.biz/security/linux-openvpn-firewall-etc-iptables-add-openvpn-rules-sh-shell-script/
########################################################################################################
#                            <<Tested on Ubuntu Mate 24.04 DESKTOP Edition>>
#                            <<Tested on Ubuntu 24.04 Server Edition>>
########################################################################################################

say_goodbye (){
	echo "see you next time"
}

about_network_config(){
	echo -e "network config is /etc/netplan/50-cloud-init.yaml controled by netplan \n"
	echo -e "for the stability of system,  do not change it , leave it as it is.\n"
	echo -e "網路設定檔放在/etc/netplan/50-cloud-init.yaml，由netplan控制 \n"
	echo -e "為了系統穩定，請不要多事去修改它 \n"
}

disable_ipv6_entirely() {
	echo 'net.ipv6.conf.all.disable_ipv6 = 1' >> /etc/sysctl.conf
	echo 'net.ipv6.conf.default.disable_ipv6 = 1' >> /etc/sysctl.conf
	echo 'net.ipv6.conf.lo.disable_ipv6 = 1' >> /etc/sysctl.conf
	sysctl -p
}

disable_dnssec() {
	# turn off DNSSEC for speed up the dns query
	sed -i -- 's|#DNSSEC=no|DNSSEC=no|g' /etc/systemd/resolved.conf
	systemctl restart systemd-resolved.service
}

sync_system_time() {
        # set timezone
        timedatectl set-timezone $MY_TIMEZONE
        timedatectl

        NTPDATE_INSTALL="$(dpkg --get-selections | grep ntpdate)"
        if [ -z "$NTPDATE_INSTALL" ]; then
                apt-get update
                apt-get install -y ntpdate
		cat > /etc/cron.daily/ntpdate << "EOF"
#!/bin/sh
ntpdate -v pool.ntp.org
EOF
                chmod +x /etc/cron.daily/ntpdate
        fi
        ntpdate -v pool.ntp.org
}

fix_too_many_authentication_failures() {
	if [ $OS_TYPE == "DESKTOP" ] ; then
        	sed -e '/pam_motd/ s/^#*/#/' -i /etc/pam.d/login
        	apt-get purge -y landscape-client landscape-common
	fi
}

firewall_setting(){
        FIREWALL_RULE_FILE="/etc/network/if-up.d/firewall"
        if [ ! -f $FIREWALL_RULE_FILE ]; then
                echo -e "writing local firewall rule to $FIREWALL_RULE_FILE \n"
                cat >> $FIREWALL_RULE_FILE << EOF
#!/bin/bash
# ============ Set your network parameters here ===================================================
iptables=/sbin/iptables
loopback=127.0.0.1
local="\$(/sbin/ip addr show $WIRED_INTERFACE_NAME | grep 'inet' | grep -v 'inet6' | tr -s ' ' | cut -d ' ' -f 3 | cut -d '/' -f 1)"
if [ $OS_TYPE == "SERVER" ] ; then
	local="\$(/sbin/ip addr show $WIRED_INTERFACE_NAME | grep 'inet' | grep -v 'inet6' | tr -s ' ' | cut -d ' ' -f 3 | cut -d '/' -f 1)"
fi
#local=192.168.251.248
lan=$LAN
vpn1=$OPENVPN_NETWORK
vpn2=$IKEV2VPN_NETWORK
# =================================================================================================
if [ -n \$local ] ; then
  \$iptables -t nat -F
  \$iptables -t nat -A POSTROUTING -s \$vpn1 -o $WIRED_INTERFACE_NAME -j MASQUERADE
  \$iptables -t nat -A POSTROUTING -s \$vpn2 -o $WIRED_INTERFACE_NAME -m policy --pol ipsec --dir out -j ACCEPT
  \$iptables -t nat -A POSTROUTING -s \$vpn2 -o $WIRED_INTERFACE_NAME -j MASQUERADE
  \$iptables -t filter -F
  \$iptables -t filter -A INPUT -i lo -s \$loopback -d \$loopback -p all -j ACCEPT
  \$iptables -t filter -A INPUT -s \$local -d \$local -p all -j ACCEPT
  \$iptables -t filter -A INPUT -s \$lan -d \$local -p all -j ACCEPT
  \$iptables -t filter -A INPUT -s \$vpn1 -d \$local -p all -j ACCEPT
  \$iptables -t filter -A INPUT -s \$vpn2 -d \$local -p all -j ACCEPT
  \$iptables -t filter -A INPUT -p udp --dport 53 -j ACCEPT
  \$iptables -t filter -A INPUT -i tun0 -j ACCEPT
  \$iptables -t filter -A INPUT -i $WIRED_INTERFACE_NAME -p udp --dport 1194 -j ACCEPT
  \$iptables -t filter -A INPUT -i $WIRED_INTERFACE_NAME -p udp --dport 500 -j ACCEPT
  \$iptables -t filter -A INPUT -i $WIRED_INTERFACE_NAME -p udp --dport 4500 -j ACCEPT
  \$iptables -t filter -A INPUT -d \$local -p tcp --dport 36000 --syn -m state --state NEW -m limit --limit 10/s --limit-burst 5 -j ACCEPT
  \$iptables -t filter -A INPUT -d \$local -p tcp --dport 36000 --syn -m state --state NEW -j DROP
  \$iptables -t filter -A INPUT -d \$local -p tcp --dport 25 --syn -m state --state NEW -m limit --limit 20/s --limit-burst 10 -j ACCEPT
  \$iptables -t filter -A INPUT -d \$local -p tcp --dport 25 --syn -m state --state NEW -j DROP
  \$iptables -t filter -A INPUT -d \$local -p tcp --dport 80 --syn -m state --state NEW -m limit --limit 300/s --limit-burst 10 -j ACCEPT
  \$iptables -t filter -A INPUT -d \$local -p tcp --dport 80 --syn -m state --state NEW -j DROP
  \$iptables -t filter -A INPUT -d \$local -p tcp --dport 110 --syn -m state --state NEW -m limit --limit 20/s --limit-burst 10 -j ACCEPT
  \$iptables -t filter -A INPUT -d \$local -p tcp --dport 110 --syn -m state --state NEW -j DROP
  \$iptables -t filter -A INPUT -d \$local -p tcp --dport 443 --syn -m state --state NEW -m limit --limit 300/s --limit-burst 10 -j ACCEPT
  \$iptables -t filter -A INPUT -d \$local -p tcp --dport 443 --syn -m state --state NEW -j DROP
  \$iptables -t filter -A INPUT -s \$lan -d \$local -p icmp -j ACCEPT
  \$iptables -t filter -A INPUT -s \$vpn1 -d \$local -p icmp -j ACCEPT
  \$iptables -t filter -A INPUT -s \$vpn2 -d \$local -p icmp -j ACCEPT
  \$iptables -t filter -A INPUT -p icmp --icmp-type 8 -m limit --limit 10/s --limit-burst 5 -j ACCEPT
  \$iptables -t filter -A INPUT -p icmp --icmp-type 8 -j DROP
  \$iptables -t filter -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  \$iptables -t filter -P INPUT DROP
  \$iptables -t filter -A FORWARD -i $WIRED_INTERFACE_NAME -o tun0 -j ACCEPT
  \$iptables -t filter -A FORWARD -i tun0 -o $WIRED_INTERFACE_NAME -j ACCEPT
  \$iptables -t filter -A FORWARD --match policy --pol ipsec --dir in  --proto esp -s \$vpn2 -j ACCEPT
  \$iptables -t filter -A FORWARD --match policy --pol ipsec --dir out  --proto esp -s \$vpn2 -j ACCEPT
  \$iptables -t mangle -A FORWARD --match policy --pol ipsec --dir in -s \$vpn2 -o $WIRED_INTERFACE_NAME -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360
  \$iptables -t nat -L -n --line-number
  \$iptables -t filter -L -n --line-number
  \$iptables -t mangle -L -n --line-number
fi
# =================================================================================================
EOF
		chmod +x $FIREWALL_RULE_FILE
		echo -e "done.\n"
        fi
}

delete_route_to_169_254_0_0(){
	if [ $OS_TYPE == "DESKTOP" ] ; then
             echo -e "delete route to 169.254.0.0/16 \n"
             FILE1="/etc/network/if-up.d/avahi-autoipd"
             sed -i -- "s|/bin/ip route add|#/bin/ip route add|g" $FILE1
             sed -i -- "s|/sbin/route add|#/sbin/route add|g" $FILE1
             echo -e "done.\n"
	fi
}

add_swap_space(){

	if [ $ADD_SWAP == "YES" ] || [ $ADD_SWAP == "yes" ] ; then
             HOW_MANY_TIMES_KEYWORD_SWAP_APPEARS="$(cat /etc/fstab | grep -c swap)"
             if [ $HOW_MANY_TIMES_KEYWORD_SWAP_APPEARS -eq 0 ] && [ ! -f /swapfile ]; then
                     echo -e "swap config not in /etc/fstab && /swapfile not exists\n"
                     echo -e "populate a empty file of 4096MB size with /dev/zero\n"
                     dd if=/dev/zero of=/swapfile bs=1M count=4096
                     sync
                     chmod 600 /swapfile
                     mkswap /swapfile
                     swapon -s
     	             echo -e "before swapon\n"
                     swapon /swapfile
                     echo -e "after swapon\n"
                     swapon -s
                     echo "/swapfile  none          swap    sw          0       0" >> /etc/fstab
                     echo -e "swap configuration already write to /etc/fstab\n"
             fi
        else
             echo -n "user chosen no need to add swap space ... disable swap for u "
	     swapoff -a
	     sed -e '/\/swap/ s/^#*/#/' -i /etc/fstab
	fi

}

remove_fcitx5(){
   # for some reason i don't know
   # there is no so called 'fcitx5-table-boshiamy' package existed in apt repositories
   # so i have to REMOVE/UNINSTALL everything about fcitx5
   # and reinstall those fcitx version4 (OLD) packages later in order to use Chinese input method Boshiamy
	if [ $OS_TYPE == "DESKTOP" ] ; then
   		apt list --installed | grep fcitx5
   		apt-get purge fcitx5* -y
   		apt-get purge libfcitx5* -y
   		apt autoremove -y
   	fi
}

install_softwares(){
        apt-get update
	if [ $OS_TYPE == "DESKTOP" ] ; then
	     string="build-essential:git:htop:memtester:vim:subversion:synaptic:vinagre:seahorse:fcitx:fcitx-table-boshiamy:fcitx-chewing:net-tools:unzip:cifs-utils:sshfs:software-properties-common:tmux"
	elif [ $OS_TYPE == "SERVER" ] ; then
	     string="build-essential:git:htop:memtester:vim:net-tools:ifupdown:unzip:cifs-utils:sshfs:software-properties-common:tmux"
	else
	     string="build-essential:git:htop:memtester:vim:subversion:unzip:cifs-utils:sshfs:software-properties-common:tmux"
	fi
	IFS=':' read -r -a array <<< "$string"
	for index in "${!array[@]}"
	do
           PACKAGE_COUNT=$((index+1))
           PACKAGE_NAME=${array[index]}
           if [ -z "$(dpkg --get-selections | grep $PACKAGE_NAME)" ]; then
              echo "$PACKAGE_NAME was not installed on your system, install now ... "
              apt-get install -y $PACKAGE_NAME
           else
              echo "$PACKAGE_NAME has been installed on your system."
           fi
	done
}

install_chrome_browser() {
	if [ $OS_TYPE == "DESKTOP" ] ; then
             wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
             sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
             apt-get update
             apt-get install -y google-chrome-stable

             # for supressing error messages like this when u run 'apt-get update'
             #   W: Target Packages (main/binary-amd64/Packages) is configured multiple times in /etc/apt/sources.list.d/google-chrome.list:3 and /etc/apt/sources.list.d/google.list:1
             #   W: Target Packages (main/binary-all/Packages) is configured multiple times in /etc/apt/sources.list.d/google-chrome.list:3 and /etc/apt/sources.list.d/google.list:1
             sed -i -- 's/^/#/' /etc/apt/sources.list.d/google.list
	fi
}

remove_ugly_fonts() {
	if [ $OS_TYPE == "DESKTOP" ] ; then

		apt-get --purge remove fonts-arphic-ukai fonts-arphic-uming -y
		apt autoremove -y
		# remove all of packages that were marked as 'deinstall'
		UNWANNTED_PACKAGES=$(dpkg --get-selections | grep deinstall | cut -f1)
		if [ -n "$UNWANNTED_PACKAGES" ] ; then
			dpkg --purge `dpkg --get-selections | grep deinstall | cut -f1`
       	 	else
			echo -e "nothing to uninstall , skip this function ... \n"
		fi

	fi
}

downgrade_gcc_version() {
	# this command will list gcc version now installed on your system (default gcc version on Ubuntu 24.04 are 13 and 14)
	apt list --installed | grep gcc

	# this command will list available packages for installation (older version is 10 and 11)
	apt-cache search gcc

	# install gcc/g++ version 10 and 11 , and set default gcc/g++ version to use 10
        apt-get install -y gcc-10 g++-10
        apt-get install -y gcc-11 g++-11
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 100 --slave /usr/bin/g++ g++ /usr/bin/g++-10
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 110 --slave /usr/bin/g++ g++ /usr/bin/g++-11
	update-alternatives --set gcc /usr/bin/gcc-10
	gcc -v && g++ -v

	# if u wanna switch to another version again , use this command below :
        # update-alternatives --config gcc
}

unlock_apt_bala_bala(){
        #
        # This function is only needed if you ever seen error messages below
        # E: Could not get lock /var/lib/dpkg/lock - open (11 Resource temporarily unavailable)
        # E: Unable to lock the administration directory (/var/lib/dpkg/) is another process using it?
        #
        rm -rf /var/lib/apt/lists/lock
        rm -rf /var/cache/apt/archives/lock
        rm -rf /var/lib/dpkg/lock
        dpkg --configure -a
}

update_system() {
        # this problem maybe occur
        # https://bugs.launchpad.net/ubuntu/+source/aptitude/+bug/1543280
        # before install/upgrade package, change directory permission number to 777 for it
        chmod 777 /var/lib/update-notifier/package-data-downloads/partial
        apt-get update
        #apt-get dist-upgrade -y
        apt-get upgrade -y
        apt autoremove -y
        # after installation , change it back to its original value 700
        chmod 700 /var/lib/update-notifier/package-data-downloads/partial
}

change_apport_settings() {

	#   i don't wannt see this anymore uh uh uh      #
	#
	##################################################
	#                                                #
	#     System program problem detected            #
	#     do you want to report the problem now ?    #
	#                                                #
        #     [ Cancel ]     [ Report problem... ]       #
        #                                                #
	##################################################
	sed -i -- 's|enabled=1|enabled=0|g' /etc/default/apport
}

install_x11vnc(){
	
  if [ -z "$(dpkg --get-selections | grep x11vnc)" ] && [ $OS_TYPE == "DESKTOP" ] ; then
	  echo -e "ready to install x11vnc ... ( it will run on 127.0.0.1:5900 ) \n"
      apt-get install -y x11vnc
      echo -e "done. \n"
      x11vnc -storepasswd $YOUR_VNC_PASSWORD /etc/x11vnc.pass
      touch /lib/systemd/system/x11vnc.service
      cat >> /lib/systemd/system/x11vnc.service << EOF
[Unit]
Description=Start x11vnc at startup.
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -auth /var/run/lightdm/root/:0 -forever -loop -noxdamage -repeat -rfbauth /etc/x11vnc.pass -localhost -rfbport 5900 -shared -logfile /tmp/x11vnc.log

[Install]
WantedBy=multi-user.target
EOF
      systemctl daemon-reload
      systemctl enable x11vnc.service
      systemctl start x11vnc.service
      systemctl status x11vnc.service

  ### README parts ###
  echo -e "################################################################################################ \n"
  echo -e "#  HOW to connect to a remote host that runs x11vnc at 127.0.0.1:5900  ? ? ?                   # \n"
  echo -e "#  if that remote host has a SSH Service running on tcp port 36000 just like my situation      # \n"
  echo -e "#  u could fire command below to bind its 127.0.0.1:5900 to your local tcp port 5999 :         # \n"
  echo -e "#        ssh -p36000 -L 5999:127.0.0.1:5900 -N -f username@192.168.251.231                     # \n"
  echo -e "#  replace <username> and <192.168.251.231> with your real username and ip address , thats all # \n"
  echo -e "################################################################################################ \n"

  fi

}

main(){
        unlock_apt_bala_bala
        update_system
	remove_fcitx5
	install_softwares
	disable_ipv6_entirely
	disable_dnssec
	sync_system_time
	fix_too_many_authentication_failures
	firewall_setting
	delete_route_to_169_254_0_0
	add_swap_space
	install_chrome_browser
	remove_ugly_fonts
        downgrade_gcc_version
	change_apport_settings
	install_x11vnc
	echo -e "now you should reboot your computer for configurations take affect.\n"
	echo -e "RUN 'reboot' in your prompt # symbol\n"
}

echo -e "This script will do the following tasks for your x64 machine, including: \n"
echo -e "  1.unlock apt package manager \n"
echo -e "  2.update packages to newest version \n"
echo -e "  3.remove fcitx5 packages && install softwares you need \n"
echo -e "  4.disable ipv6 entirely \n"
echo -e "  5.disable DNSSEC for systemd-resolved.service \n"
echo -e "  6.install ntpdate and sync system time \n"
echo -e "  7.disable cloudinit messages that appear to foreground \n"
echo -e "  8.fix too many authentication failures problem \n"
echo -e "  9.Firewall rule setting (Write firewall rules in /etc/network/if-up.d/firewall) \n"
echo -e "  10.delete route to 169.254.0.0 \n"
echo -e "  11.add swap space with 4096MB \n"
echo -e "  12.install chrome browser \n"
echo -e "  13.remove ugly fonts \n"
echo -e "  14.downgrade gcc/g++ version to 10.x \n"
echo -e "  15.turn off apport problem report popup dialog \n"
echo -e "  16.install x11vnc service (running on 127.0.0.1:5900) for u if your OS_TYPE is DESKTOP \n"

read -p "Are you sure (y/n)?" sure
case $sure in
	[Yy]*)
		main
		;;
	[Nn]*) 
		say_goodbye
		exit 1
		;;
	*) echo "Please answer yes or no."
esac

