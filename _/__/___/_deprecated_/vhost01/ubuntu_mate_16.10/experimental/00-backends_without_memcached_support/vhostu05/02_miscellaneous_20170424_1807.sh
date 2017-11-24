#!/bin/bash
# This script will perform lots of work for fine tune Ubuntu 16.04.02 LTS you've just installed
# before you run this script , please specify some parameters here:
#
LAN="172.28.117.0/24" # The local network that you allow packets come in from there
VPN="10.8.0.0/24" # The VPN network that you allow packets come in from there
#####################

say_goodbye (){
	echo "goodbye everyone"
}

fix_network_interfaces_name(){
        #ETH0_MAC_ADDRESS=$(ifconfig enp0s3 | grep -A 1 'ether' | head -1 | cut -d " " -f 10)
        ETH0_MAC_ADDRESS=$(/sbin/ip addr show enp0s3 | grep ether | tr -s ' ' | cut -d ' ' -f 3)
        NETWORK_RULES_FILE="/etc/udev/rules.d/70-network.rules"
        touch $NETWORK_RULES_FILE
        HOW_MANY_TIMES_ETH0_APPEAR=$(cat $NETWORK_RULES_FILE | grep -c "eth0")
        ZERO=0
        HOW_MANY_LINES_IN_NETWORK_RULES_FILE=$(wc -l $NETWORK_RULES_FILE | cut -d ' ' -f 1)

        if [ ! -z "$ETH0_MAC_ADDRESS" -a "$ETH0_MAC_ADDRESS" != " " -a $HOW_MANY_TIMES_ETH0_APPEAR -eq 0 ]; then
                echo "mac address of eth0 : $ETH0_MAC_ADDRESS \n"
                echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$ETH0_MAC_ADDRESS\", NAME=\"eth0\"" >> $NETWORK_RULES_FILE
        fi

        if [ $HOW_MANY_LINES_IN_NETWORK_RULES_FILE -eq 1 ]; then
                echo "$NETWORK_RULES_FILE has been created successfully."
        fi
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
        apt-get purge landscape-client landscape-common
}

firewall_setting(){
        FIREWALL_RULE_FILE="/etc/network/if-up.d/firewall"
        if [ ! -f $FIREWALL_RULE_FILE ]; then
                echo "writing local firewall rule to $FIREWALL_RULE_FILE \n"
                cat >> $FIREWALL_RULE_FILE << EOF
#!/bin/bash
# ============ Set your network parameters here ===================================================
iptables=/sbin/iptables
loopback=127.0.0.1
local="\$(/sbin/ip addr show eth0 | grep dynamic | tr -s ' ' | cut -d ' ' -f 3 | cut -d '/' -f 1)"
#local="\$(/sbin/ip addr show wlan0 | grep dynamic | tr -s ' ' | cut -d ' ' -f 3 | cut -d '/' -f 1)"
#local=10.1.1.170
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
  \$iptables -t filter -A INPUT -s \$lan -p tcp --dport 36000 --syn -m state --state NEW -m limit --limit 10/s --limit-burst 20 -j ACCEPT
  \$iptables -t filter -A INPUT -s \$lan -p tcp --dport 36000 --syn -m state --state NEW -j DROP
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
	string="build-essential:git:htop:memtester:vim:subversion:synaptic:vinagre:seahorse:fcitx:fcitx-table-boshiamy:fcitx-chewing"
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
        apt-get install -y gcc-4.8 g++-4.8
        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.8 48 --slave /usr/bin/g++ g++ /usr/bin/g++-4.8
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
	fix_network_interfaces_name
	disable_ipv6_entirely
	disable_dnssec
	sync_system_time
	fix_too_many_authentication_failures
	#firewall_setting
	delete_route_to_169_254_0_0
	#add_swap_space
	install_softwares
	#install_chrome_browser
	remove_ugly_fonts
        downgrade_gcc_version
        unlock_apt_bala_bala
        update_system
	echo -e "now you should reboot your computer for configurations take affect.\n"
	echo -e "RUN 'reboot' in your prompt # symbol\n"
}

echo -e "This script will do the following tasks for your x64 machine, including: \n"
echo -e "  1.Fix network interfaces name (To conventional 'eth0' and 'wlan0') \n"
echo -e "  2.disable ipv6 entirely \n"
echo -e "  3.disable DNSSEC for systemd-resolved.service \n"
echo -e "  4.install ntpdate and sync system time \n"
echo -e "  5.fix too many authentication failures problem \n"
echo -e "  6.Firewall rule setting (Write firewall rules in /etc/network/if-up.d/firewall) \n"
echo -e "  7.delete route to 169.254.0.0 \n"
echo -e "  8.add swap space with 4096MB \n"
echo -e "  9.install softwares you need \n"
echo -e "  10.install chrome browser \n"
echo -e "  11.remove ugly fonts \n"
echo -e "  12.downgrade gcc/g++ version to 4.8 \n"
echo -e "  13.unlock apt package manager \n"
echo -e "  14.update packages to newest version \n"

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

