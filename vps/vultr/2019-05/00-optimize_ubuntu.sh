#!/bin/bash
# This script will perform lots of work for optimizing Ubuntu 18.04 LTS you've just installed
# before you run this script , please specify some parameters here:
#
# these parameters will be used in firewall rules:
#####################################################################################
MY_LAN="172.16.225.0/24" # The local network that you attached for this VPS node
MY_PRIVATE_STATIC_IP="172.16.225.17" # The private ip address that you specify for this VPS node
MY_TIMEZONE="Asia/Taipei"
MY_BROTHER="140.82.10.123/32" # Another VPS node that will exchange data with you
#####################################################################################
#### *** Special Thanks *** ####
# http://www.ubuntugeek.com/disable-netplan-on-ubuntu-17-10.html
# https://www.itzgeek.com/how-tos/mini-howtos/change-default-network-name-ens33-to-old-eth0-on-ubuntu-16-04.html
#####################################################################################

say_goodbye (){
	echo "goodbye everyone"
}

fix_network_interfaces_name(){
	# change network interface name from ens3/ens7 to eth0/eth1 , and disable netplan
	sed -i -- 's|GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX="consoleblank=0 net.ifnames=0 biosdevname=0 netcfg/do_not_use_netplan=true"|g' /etc/default/grub
	update-grub
}

modify_network_config() {
        NETWORK_CONFIG_FILE="/etc/network/interfaces"
	rm -rf $NETWORK_CONFIG_FILE
	cat >> $NETWORK_CONFIG_FILE << "EOF"
# ifupdown has been replaced by netplan(5) on this system.  See
# /etc/netplan for current configuration.
# To re-enable ifupdown on this system, you can run:
#    sudo apt install ifupdown
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
iface eth0 inet6 auto

auto eth1
iface eth1 inet static
   address MY_PRIVATE_STATIC_IP
   netmask 255.255.255.0
   mtu 1450
EOF
        sed -i -- "s|MY_PRIVATE_STATIC_IP|$MY_PRIVATE_STATIC_IP|g" $NETWORK_CONFIG_FILE
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
	# you need these commands if your Ubuntu version is 17.04
	echo 'DNSSEC=off' >> /etc/systemd/resolved.conf
	systemctl restart systemd-resolved.service
}

sync_system_time() {
        timedatectl set-timezone $MY_TIMEZONE
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
private_ip=$MY_PRIVATE_STATIC_IP
lan=$MY_LAN
brother=$MY_BROTHER
# =================================================================================================
if [ -n \$local ] ; then
  \$iptables -t filter -F
  \$iptables -t filter -A INPUT -i lo -p all -j ACCEPT
  \$iptables -t filter -A INPUT -i eth0 -s \$public_ip -d \$public_ip -p all -j ACCEPT
  \$iptables -t filter -A INPUT -i eth0 -s \$brother -d \$public_ip -p all -j ACCEPT
  \$iptables -t filter -A INPUT -i eth1 -s \$private_ip -d \$private_ip -p all -j ACCEPT
  \$iptables -t filter -A INPUT -i eth1 -s \$lan -d \$private_ip -p all -j ACCEPT
  \$iptables -t filter -A INPUT -s \$public_ip -d \$private_ip -p all -j ACCEPT
  \$iptables -t filter -A INPUT -s \$private_ip -d \$public_ip -p all -j ACCEPT
  \$iptables -t filter -A INPUT -p tcp --dport 53 -j ACCEPT
  \$iptables -t filter -A INPUT -p udp --dport 53 -j ACCEPT
  \$iptables -t filter -A INPUT -d \$public_ip -p tcp --dport 36000 --syn -m state --state NEW -m limit --limit 10/s --limit-burst 20 -j ACCEPT
  \$iptables -t filter -A INPUT -d \$public_ip -p tcp --dport 36000 --syn -m state --state NEW -j DROP
  \$iptables -t filter -A INPUT -d \$public_ip -p tcp --dport 80 --syn -m state --state NEW -m limit --limit 800/s --limit-burst 1000 -j ACCEPT
  \$iptables -t filter -A INPUT -d \$public_ip -p tcp --dport 80 --syn -m state --state NEW -j DROP
  \$iptables -t filter -A INPUT -d \$public_ip -p tcp --dport 443 --syn -m state --state NEW -m limit --limit 800/s --limit-burst 1000 -j ACCEPT
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
	echo -e "delete route to 169.254.0.0/16 \n"
        FILE1="/etc/network/if-up.d/avahi-autoipd"
	sed -i -- "s|/bin/ip route add|#/bin/ip route add|g" $FILE1
	sed -i -- "s|/sbin/route add|#/sbin/route add|g" $FILE1
	echo -e "done.\n"
}

add_swap_space(){
        HOW_MANY_TIMES_KEYWORD_SWAP_APPEARS="$(cat /etc/fstab | grep -c swap)"
        if [ $HOW_MANY_TIMES_KEYWORD_SWAP_APPEARS -eq 0 ] && [ ! -f /swapfile ]; then
                echo -e "swap config not in /etc/fstab && /swapfile not exists\n"
                echo -e "populate a empty file of 2048MB size with /dev/zero\n"
                dd if=/dev/zero of=/swapfile bs=1M count=2048
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
	string="build-essential:git:htop:memtester:vim:subversion:unzip:language-pack-zh*:fonts-wqy*:ifupdown"
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

configure_language_settings(){
        rm -rf /etc/default/locale
        cat > /etc/default/locale << "EOF"
LANG="zh_TW.UTF-8"
LANGUAGE="zh_TW.UTF-8"
LC_NUMERIC="zh_TW.UTF-8"
LC_TIME="zh_TW.UTF-8"
LC_MONETARY="zh_TW.UTF-8"
LC_PAPER="zh_TW.UTF-8"
LC_NAME="zh_TW.UTF-8"
LC_ADDRESS="zh_TW.UTF-8"
LC_TELEPHONE="zh_TW.UTF-8"
LC_MEASUREMENT="zh_TW.UTF-8"
LC_IDENTIFICATION="zh_TW.UTF-8"
EOF
}

remove_ugly_fonts() {
	apt-get remove -y fonts-arphic-ukai fonts-arphic-uming
}

downgrade_gcc_version() {
        apt-get install -y gcc-5 g++-5
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 50 --slave /usr/bin/g++ g++ /usr/bin/g++-5
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
	fix_network_interfaces_name
	modify_network_config
	disable_ipv6_entirely
	disable_dnssec
	sync_system_time
	fix_too_many_authentication_failures
	firewall_setting
	delete_route_to_169_254_0_0
	add_swap_space
	install_softwares
	remove_ugly_fonts
	configure_language_settings
        downgrade_gcc_version
	echo -e "now you should reboot your computer for configurations take affect.\n"
	echo -e "RUN 'reboot' in your prompt # symbol\n"
}

echo -e "This script will do the following tasks for your vps node, including: \n"
echo -e "  1.unlock apt package manager \n"
echo -e "  2.update packages to newest version \n"
echo -e "  3.Fix network interfaces name (To conventional 'eth0' and 'eth1') \n"
echo -e "  4.modify network config /etc/network/interfaces \n"
echo -e "  5.disable ipv6 entirely \n"
echo -e "  6.disable DNSSEC for systemd-resolved.service \n"
echo -e "  7.set timezone, install ntpdate and sync system time \n"
echo -e "  8.fix too many authentication failures problem \n"
echo -e "  9.Firewall rule setting (Write firewall rules in /etc/network/if-up.d/firewall) \n"
echo -e "  10.delete route to 169.254.0.0 \n"
echo -e "  11.add swap space with 2048MB \n"
echo -e "  12.install softwares you need \n"
echo -e "  13.remove ugly fonts \n"
echo -e "  14.configure language settings \n"
echo -e "  14.downgrade gcc/g++ version to 5.5 \n"

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

