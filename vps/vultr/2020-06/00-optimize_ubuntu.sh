#!/bin/bash
# This script will perform lots of work for optimizing Ubuntu 20.04 LTS you've just installed
# before you run this script , please specify some parameters here:
#
# these parameters will be used in firewall rules:           <<Tested on Ubuntu 20.04 Server Edition>>
######################################################################################################
VULTR_INTERNAL_IP="172.16.225.17"       # set internal ip address for this node
VULTR_INTERNAL_NETMASK="255.255.255.0"  # set internal networks netmask for this node
VULTR_INTERNAL_LAN="172.16.225.0/24"    # The local network that you attached for this VPS node
######################################################################################################
MY_VPN="10.8.0.0/24"                    # The VPN network that you allow packets come in from there
MY_TIMEZONE="Asia/Taipei"               # The timezone that you specify for this VPS node
MY_BROTHER="45.77.131.215/32"           # Another VPS nodes IP that will exchange data with you
######################################################################################################

say_goodbye (){
	echo "goodbye everyone"
}

fix_network_interfaces_name(){
        # change network interface name from ens3/ens7 to eth0/eth1 , and disable GOD DAMN netplan
        sed -i -- 's|GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX="consoleblank=0 net.ifnames=0 biosdevname=0 netcfg/do_not_use_netplan=true"|g' /etc/default/grub
        update-grub
}

modify_network_config() {
        NETWORK_CONFIG_FILE="/etc/network/interfaces"
        rm -rf $NETWORK_CONFIG_FILE
        cat >> $NETWORK_CONFIG_FILE << "EOF"
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d:
# source-directory /etc/network/interfaces.d
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet static
    address VULTR_INTERNAL_IP
    netmask VULTR_INTERNAL_NETMASK
    mtu 1450
EOF
	sed -i -- "s|VULTR_INTERNAL_IP|$VULTR_INTERNAL_IP|g" $NETWORK_CONFIG_FILE
	sed -i -- "s|VULTR_INTERNAL_NETMASK|$VULTR_INTERNAL_NETMASK|g" $NETWORK_CONFIG_FILE
        chown root:root $NETWORK_CONFIG_FILE
        chmod 644 $NETWORK_CONFIG_FILE
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

	# get accurate time
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
        sed -e '/pam_motd/ s/^#*/#/' -i /etc/pam.d/login
        apt-get purge -y landscape-client landscape-common
}

firewall_setting(){
        FIREWALL_RULE_FILE="/etc/network/if-up.d/firewall"
        if [ ! -f $FIREWALL_RULE_FILE ]; then
                echo "writing local firewall rule to $FIREWALL_RULE_FILE \n"
                cat >> $FIREWALL_RULE_FILE << EOF
#!/bin/bash
# ============ Set your network parameters here ===================================================
iptables=/sbin/iptables
public_ip="\$(/sbin/ip addr show eth0 | grep 'inet' | grep -v 'inet6' | tr -s ' ' | cut -d ' ' -f 3 | cut -d '/' -f 1)"
private_ip="\$(/sbin/ip addr show eth1 | grep 'inet' | grep -v 'inet6' | tr -s ' ' | cut -d ' ' -f 3 | cut -d '/' -f 1)"
lan=$VULTR_INTERNAL_LAN
vpn=$MY_VPN
brother=$MY_BROTHER
# =================================================================================================
if [ -n \$public_ip -a -n \$private_ip ] ; then
  \$iptables -t filter -F
  \$iptables -t filter -A INPUT -i lo -p all -j ACCEPT
  \$iptables -t filter -A INPUT -i eth0 -s \$public_ip -d \$public_ip -p all -j ACCEPT
  \$iptables -t filter -A INPUT -i eth0 -s \$brother -d \$public_ip -p all -j ACCEPT
  \$iptables -t filter -A INPUT -i eth0 -s \$vpn -d \$public_ip -p all -j ACCEPT
  \$iptables -t filter -A INPUT -i eth1 -s \$private_ip -d \$private_ip -p all -j ACCEPT
  \$iptables -t filter -A INPUT -i eth1 -s \$lan -d \$private_ip -p all -j ACCEPT
  \$iptables -t filter -A INPUT -i eth1 -s \$vpn -d \$private_ip -p all -j ACCEPT
  \$iptables -t filter -A INPUT -s \$public_ip -d \$private_ip -p all -j ACCEPT
  \$iptables -t filter -A INPUT -s \$private_ip -d \$public_ip -p all -j ACCEPT
  \$iptables -t filter -A INPUT -p tcp --dport 53 -j ACCEPT
  \$iptables -t filter -A INPUT -p udp --dport 53 -j ACCEPT
  \$iptables -t filter -A INPUT -d \$public_ip -p tcp --dport 36000 --syn -m state --state NEW -m limit --limit 15/s --limit-burst 20 -j ACCEPT
  \$iptables -t filter -A INPUT -d \$public_ip -p tcp --dport 36000 --syn -m state --state NEW -j DROP
  \$iptables -t filter -A INPUT -d \$public_ip -p tcp --dport 80 --syn -m state --state NEW -m limit --limit 400/s --limit-burst 500 -j ACCEPT
  \$iptables -t filter -A INPUT -d \$public_ip -p tcp --dport 80 --syn -m state --state NEW -j DROP
  \$iptables -t filter -A INPUT -d \$public_ip -p tcp --dport 443 --syn -m state --state NEW -m limit --limit 400/s --limit-burst 500 -j ACCEPT
  \$iptables -t filter -A INPUT -d \$public_ip -p tcp --dport 443 --syn -m state --state NEW -j DROP
  \$iptables -t filter -A INPUT -p icmp -j ACCEPT
  \$iptables -t filter -A INPUT -p icmp --icmp-type 8 -m limit --limit 10/s -j ACCEPT
  \$iptables -t filter -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  \$iptables -t filter -P INPUT DROP
  \$iptables -t filter -L -n --line-number
fi
# =================================================================================================
EOF
		chmod +x $FIREWALL_RULE_FILE
		echo "done.\n"
        fi
}

delete_route_to_169_254_0_0(){
	echo -e "i dont know how to delete route to 169.254.169.254/32 in Ubuntu 20.04 Server Edition \n"
	echo -e "desktop version is caused by avahi daemon , but this package doenst appear in Server Edition \n"
	#echo -e "delete route to 169.254.0.0/16 \n"
        #FILE1="/etc/network/if-up.d/avahi-autoipd"
	#sed -i -- "s|/bin/ip route add|#/bin/ip route add|g" $FILE1
	#sed -i -- "s|/sbin/route add|#/sbin/route add|g" $FILE1
	#echo -e "done.\n"
}

add_swap_space(){
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
}

install_softwares(){
        apt-get update
	string="build-essential:git:htop:memtester:vim:subversion:net-tools:ifupdown:unzip"
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
        wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
        sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
        apt-get update
        apt-get install -y google-chrome-stable
}

remove_ugly_fonts() {
	apt-get remove -y fonts-arphic-ukai fonts-arphic-uming
}

downgrade_gcc_version() {
        apt-get install -y gcc-7 g++-7
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 70 --slave /usr/bin/g++ g++ /usr/bin/g++-7
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

main(){
        unlock_apt_bala_bala
        update_system
	install_softwares
	fix_network_interfaces_name
	modify_network_config
	disable_ipv6_entirely
	disable_dnssec
	sync_system_time
	fix_too_many_authentication_failures
	firewall_setting
	delete_route_to_169_254_0_0
	add_swap_space
	#install_chrome_browser
	remove_ugly_fonts
        downgrade_gcc_version
	echo -e "now you should reboot your computer for configurations take affect.\n"
	echo -e "RUN 'reboot' in your prompt # symbol\n"
}

echo -e "This script will do the following tasks for your x64 machine, including: \n"
echo -e "  1.unlock apt package manager \n"
echo -e "  2.update packages to newest version \n"
echo -e "  3.install softwares you need \n"
echo -e "  4.Fix network interfaces name (To conventional 'eth0' and 'wlan0') \n"
echo -e "  5.modify network config /etc/network/interfaces \n"
echo -e "  6.disable ipv6 entirely \n"
echo -e "  7.disable DNSSEC for systemd-resolved.service \n"
echo -e "  8.install ntpdate and sync system time \n"
echo -e "  9.fix too many authentication failures problem \n"
echo -e "  10.Firewall rule setting (Write firewall rules in /etc/network/if-up.d/firewall) \n"
echo -e "  11.delete route to 169.254.0.0 \n"
echo -e "  12.add swap space with 4096MB \n"
echo -e "  13.install chrome browser \n"
echo -e "  14.remove ugly fonts \n"
echo -e "  15.downgrade gcc/g++ version to 7.x \n"

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

