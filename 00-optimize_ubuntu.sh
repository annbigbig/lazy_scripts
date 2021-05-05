#!/bin/bash
# This script will perform lots of work for optimizing Ubuntu 20.04 LTS you've just installed
# before you run this script , please specify some parameters here:
#
# these parameters will be used in firewall rules:      <<Tested on Ubuntu Mate 20.04 Desktop Edition>>
########################################################################################################
OS_TYPE="Server"                        # only two values could work well 'Desktop' or 'Server'
LAN="192.168.21.0/24"                   # The local network that you allow packets come in from there
VPN="172.25.169.0/24"                   # The VPN network that you allow packets come in from there
MY_TIMEZONE="Asia/Taipei"               # The timezone that you specify for this VPS node
ADD_SWAP="no"                           # Do u need swap space ? fill in 'yes' or 'YES' will add swap for u
YOUR_VNC_PASSWORD="vnc"                 # set your vnc password here
########################################################################################################
# useful links: 
# https://www.tecmint.com/set-permanent-dns-nameservers-in-ubuntu-debian/
# https://linuxconfig.org/how-to-switch-back-networking-to-etc-network-interfaces-on-ubuntu-20-04-focal-fossa-linux
# https://vitux.com/ubuntu-network-configuration/
########################################################################################################

say_goodbye (){
	echo "goodbye everyone"
}

fix_network_interfaces_name(){
	if [ $OS_TYPE == "Server" ] ; then
            # change network interface name from ens3/ens7 to eth0/eth1 , and disable netplan
            sed -i -- 's|GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX="consoleblank=0 net.ifnames=0 biosdevname=0 netcfg/do_not_use_netplan=true"|g' /etc/default/grub
            update-grub
	fi
}

modify_network_config() {
	if [ $OS_TYPE == "Server" ] ; then
             NETWORK_CONFIG_FILE="/etc/network/interfaces"
             rm -rf $NETWORK_CONFIG_FILE
             cat >> $NETWORK_CONFIG_FILE << "EOF"
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d:
# source-directory /etc/network/interfaces.d
auto lo
iface lo inet loopback

# if u get ip from DHCP service
#auto eth0
#iface eth0 inet dhcp

# if u get ip from manual (static)
auto eth0
  iface eth0 inet static
  address 192.168.21.231
  netmask 255.255.255.0
  gateway 192.168.21.254
  dns-nameservers 8.8.8.8 8.8.4.4 168.95.192.1 168.95.1.1

EOF
             chown root:root $NETWORK_CONFIG_FILE
             chmod 644 $NETWORK_CONFIG_FILE
        fi
}

enable_resolvconf_service() {
	if [ $OS_TYPE == "Server" ] ; then
             # if your network use static ip settings , u need this to let it function normally (save it from dxxn-low dns query time)
	     if [ -L /etc/resolv.conf ] ; then
		rm -rf /etc/resolv.conf
		touch /etc/resolv.conf
		echo "nameserver 168.95.1.1" >> /etc/resolv.conf
		echo "nameserver 168.95.192.1" >> /etc/resolv.conf
	     fi
             apt-get install resolvconf -y
             cp /etc/resolvconf/resolv.conf.d/head /etc/resolvconf/resolv.conf.d/head.default
             rm /etc/resolvconf/resolv.conf.d/head
             cat >> /etc/resolvconf/resolv.conf.d/head << "EOF"
nameserver 8.8.4.4
nameserver 8.8.8.8

options single-request-reopen
EOF
        systemctl enable resolvconf.service
        systemctl restart resolvconf.service
        # cat /etc/resolv.conf u will know what it did for u
	fi
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

disable_cloudinit_garbage_messages() {
        touch /etc/cloud/cloud-init.disabled
}

fix_too_many_authentication_failures() {
        sed -e '/pam_motd/ s/^#*/#/' -i /etc/pam.d/login
        apt-get purge -y landscape-client landscape-common
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
local="\$(/sbin/ip addr show eth0 | grep 'inet' | grep -v 'inet6' | tr -s ' ' | cut -d ' ' -f 3 | cut -d '/' -f 1)"
#local="\$(/sbin/ip addr show wlan0 | grep 'inet' | grep -v 'inet6' | tr -s ' ' | cut -d ' ' -f 3 | cut -d '/' -f 1)"
#local=192.168.21.231
lan=$LAN
vpn=$VPN
# =================================================================================================
if [ -n \$local ] ; then
  \$iptables -t filter -F
  \$iptables -t filter -A INPUT -i lo -s \$loopback -d \$loopback -p all -j ACCEPT
  #\$iptables -t filter -A INPUT -i eth0 -s \$local -d \$local -p all -j ACCEPT
  #\$iptables -t filter -A INPUT -i eth0 -s \$lan -d \$local -p all -j ACCEPT
  #\$iptables -t filter -A INPUT -i eth0 -s \$vpn -d \$local -p all -j ACCEPT
  \$iptables -t filter -A INPUT -s \$local -d \$local -p all -j ACCEPT
  \$iptables -t filter -A INPUT -s \$lan -d \$local -p all -j ACCEPT
  \$iptables -t filter -A INPUT -s \$vpn -d \$local -p all -j ACCEPT
  \$iptables -t filter -A INPUT -p udp --dport 53 -j ACCEPT
  \$iptables -t filter -A INPUT -d \$local -p tcp --dport 36000 --syn -m state --state NEW -m limit --limit 10/s --limit-burst 20 -j ACCEPT
  \$iptables -t filter -A INPUT -d \$local -p tcp --dport 36000 --syn -m state --state NEW -j DROP
  \$iptables -t filter -A INPUT -d \$local -p tcp --dport 80 --syn -m state --state NEW -m limit --limit 160/s --limit-burst 200 -j ACCEPT
  \$iptables -t filter -A INPUT -d \$local -p tcp --dport 80 --syn -m state --state NEW -j DROP
  \$iptables -t filter -A INPUT -d \$local -p tcp --dport 443 --syn -m state --state NEW -m limit --limit 160/s --limit-burst 200 -j ACCEPT
  \$iptables -t filter -A INPUT -d \$local -p tcp --dport 443 --syn -m state --state NEW -j DROP
  \$iptables -t filter -A INPUT -s \$lan -d \$local -p icmp -j ACCEPT
  \$iptables -t filter -A INPUT -s \$vpn -d \$local -p icmp -j ACCEPT
  \$iptables -t filter -A INPUT -p icmp --icmp-type 8 -m limit --limit 10/s -j ACCEPT
  \$iptables -t filter -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  \$iptables -t filter -P INPUT DROP
  \$iptables -t filter -L -n --line-number
fi
# =================================================================================================
EOF
		chmod +x $FIREWALL_RULE_FILE
		echo -e "done.\n"
        fi
}

delete_route_to_169_254_0_0(){
	# UBUNTU_VER -> value 1 means Ubuntu Version between 18 to 21
	UBUNTU_VER=$(cat /etc/lsb-release | grep 'RELEASE' | cut -d "=" -f 2 | grep '[18|19|20|21]' | wc -l)
	if [ $UBUNTU_VER -eq 0 ] ; then
             echo -e "delete route to 169.254.0.0/16 , only OLDer Ubuntu (version number less then 18.04) need to do this . \n"
             FILE1="/etc/network/if-up.d/avahi-autoipd"
             sed -i -- "s|/bin/ip route add|#/bin/ip route add|g" $FILE1
             sed -i -- "s|/sbin/route add|#/sbin/route add|g" $FILE1
             echo -e "done.\n"
	fi
}

add_swap_space(){

	if [ $ADD_SWAP = "YES" ] || [ $ADD_SWAP = "yes" ] ; then
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

install_softwares(){
        apt-get update
	if [ $OS_TYPE == "Desktop" ] ; then
	     string="build-essential:git:htop:memtester:vim:subversion:synaptic:vinagre:seahorse:fcitx:fcitx-table-boshiamy:fcitx-chewing:net-tools:unzip:cifs-utils:sshfs"
	elif [ $OS_TYPE == "Server" ] ; then
	     string="build-essential:git:htop:memtester:vim:net-tools:ifupdown:unzip:cifs-utils:sshfs"
	else
	     string="build-essential:git:htop:memtester:vim:subversion:unzip:cifs-utils:sshfs"
	fi
	IFS=':' read -r -a array <<< "$string"
	for index in "${!array[@]}"
	do
           PACKAGE_COUNT=$((index+1))
           PACKAGE_NAME=${array[index]}
           #if [ -z "$(dpkg --get-selections | grep $PACKAGE_NAME)" ]; then
              #echo "$PACKAGE_NAME was not installed on your system, install now ... "
              apt-get install -y $PACKAGE_NAME
           #else
              #echo "$PACKAGE_NAME has been installed on your system."
           #fi
	done
}

install_chrome_browser() {
	if [ $OS_TYPE == "Desktop" ] ; then
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
	apt-get --purge remove fonts-arphic-ukai fonts-arphic-uming -y
	apt autoremove -y
	# remove all of packages that were marked as 'deinstall'
	UNWANNTED_PACKAGES=$(dpkg --get-selections | grep deinstall | cut -f1)
	if [ -n "$UNWANNTED_PACKAGES" ] ; then
	     dpkg --purge `dpkg --get-selections | grep deinstall | cut -f1`
        else
             echo -e "nothing to uninstall , skip this function ... \n"
	fi
}

downgrade_gcc_version() {
        apt-get install -y gcc-7 g++-7
        apt-get install -y gcc-8 g++-8
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 70 --slave /usr/bin/g++ g++ /usr/bin/g++-7
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 80 --slave /usr/bin/g++ g++ /usr/bin/g++-8
	update-alternatives --set gcc /usr/bin/gcc-8
	gcc -v && g++ -v
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
        apt-get dist-upgrade -y
        apt autoremove -y
        # after installation , change it back to its original value 755
        chmod 755 /var/lib/update-notifier/package-data-downloads/partial
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
	
  if [ -z "$(dpkg --get-selections | grep x11vnc)" ] && [ $OS_TYPE == "Desktop" ] ; then
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
  fi

  ### README parts ###
  echo -e "################################################################################################ \n"
  echo -e "#  HOW to connect to a remote host that runs x11vnc at 127.0.0.1:5900  ? ? ?                   # \n"
  echo -e "#  if that remote host has a SSH Service running on tcp port 36000 just like my situation      # \n"
  echo -e "#  u could fire command below to bind its 127.0.0.1:5900 to your local tcp port 5999 :         # \n"
  echo -e "#        ssh -p36000 -L 5999:127.0.0.1:5900 -N -f username@192.168.21.231                      # \n"
  echo -e "#  replace <username> and <192.168.21.231> with your real username and ip address , thats all  # \n"
  echo -e "################################################################################################ \n"
}

main(){
        unlock_apt_bala_bala
        update_system
	install_softwares
	fix_network_interfaces_name
	enable_resolvconf_service
	modify_network_config
	disable_ipv6_entirely
	disable_dnssec
	sync_system_time
	disable_cloudinit_garbage_messages
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
echo -e "  3.install softwares you need \n"
echo -e "  4.Fix network interfaces name (To conventional 'eth0' and 'wlan0') \n"
echo -e "  5.Enable resolvconf service \n"
echo -e "  6.modify network config /etc/network/interfaces \n"
echo -e "  7.disable ipv6 entirely \n"
echo -e "  8.disable DNSSEC for systemd-resolved.service \n"
echo -e "  9.install ntpdate and sync system time \n"
echo -e "  10.disable cloudinit messages that appear to foreground \n"
echo -e "  11.fix too many authentication failures problem \n"
echo -e "  12.Firewall rule setting (Write firewall rules in /etc/network/if-up.d/firewall) \n"
echo -e "  13.delete route to 169.254.0.0 \n"
echo -e "  14.add swap space with 4096MB \n"
echo -e "  15.install chrome browser \n"
echo -e "  16.remove ugly fonts \n"
echo -e "  17.downgrade gcc/g++ version to 7.x \n"
echo -e "  18.turn off apport problem report popup dialog \n"
echo -e "  19.install x11vnc service (running on 127.0.0.1:5900) for u if your OS_TYPE is Desktop \n"

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

