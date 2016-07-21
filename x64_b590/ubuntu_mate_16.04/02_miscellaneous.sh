#!/bin/bash
# This script will perform lots of work for fine tune Ubuntu 15.10 you have just flashed into micro-SD card
# plug micro-SD card into Raspberry pi 2 and turn the power on
# after first booting Raspberry pi 2 and finished username and locale settings,
# run this script on Raspberry pi 2
# before you run this script , please specify some parameters here:
#
LAN="10.1.1.0/24" # The local network that you allow packets come in from there
VPN="10.8.0.0/24" # The VPN network that you allow packets come in from there
#####################

say_goodbye (){
	echo "goodbye everyone"
}

fix_network_interfaces_name(){
	ETH0_MAC_ADDRESS=$(ifconfig |grep enp3s0 | cut -d ' ' -f 9)
	WLAN0_MAC_ADDRESS=$(ifconfig |grep wlp2s0 | cut -d ' ' -f 9)
	NETWORK_RULES_FILE="/etc/udev/rules.d/70-network.rules"
	touch $NETWORK_RULES_FILE
	HOW_MANY_TIMES_ETH0_APPEAR=$(cat $NETWORK_RULES_FILE | grep -c "eth0")
	HOW_MANY_TIMES_WLAN0_APPEAR=$(cat $NETWORK_RULES_FILE | grep -c "wlan0")
	ZERO=0
	HOW_MANY_LINES_IN_NETWORK_RULES_FILE=$(wc -l $NETWORK_RULES_FILE | cut -d ' ' -f 1)

	if [ ! -z "$ETH0_MAC_ADDRESS" -a "$ETH0_MAC_ADDRESS" != " " -a $HOW_MANY_TIMES_ETH0_APPEAR -eq 0 ]; then
		echo "mac address of eth0 : $ETH0_MAC_ADDRESS \n"
		echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$ETH0_MAC_ADDRESS\", NAME=\"eth0\"" >> $NETWORK_RULES_FILE
	fi

	if [ ! -z "$WLAN0_MAC_ADDRESS" -a "$WLAN0_MAC_ADDRESS" != " " -a $HOW_MANY_TIMES_WLAN0_APPEAR -eq 0 ]; then
		echo "mac address of wlan0 : $WLAN0_MAC_ADDRESS \n"
		echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$WLAN0_MAC_ADDRESS\", NAME=\"wlan0\"" >> $NETWORK_RULES_FILE
	fi

	if [ $HOW_MANY_LINES_IN_NETWORK_RULES_FILE -eq 2 ]; then
		echo "$NETWORK_RULES_FILE has been created successfully."
	fi
}

firewall_setting(){
        FIREWALL_RULE_FILE="/etc/network/if-up.d/firewall"
        if [ ! -f $FIREWALL_RULE_FILE ]; then
                echo "writing local firewall rule to $FIREWALL_RULE_FILE \n"
                cat >> $FIREWALL_RULE_FILE << EOF
#!/bin/sh
# ============ Set your network parameters here ===================================================
iptables=/sbin/iptables
loopback=127.0.0.1
local="\$(/sbin/ifconfig | grep -A 1 'wlan0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"
#local="\$(/sbin/ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"
#local=10.1.1.170
lan=$LAN
vpn=$VPN
# =================================================================================================
\$iptables -t filter -F
\$iptables -t filter -A INPUT -i lo -s \$loopback -d \$loopback -p all -j ACCEPT
\$iptables -t filter -A INPUT -i wlan0 -s \$local -d \$local -p all -j ACCEPT
\$iptables -t filter -A INPUT -i wlan0 -s \$lan -d \$local -p all -j ACCEPT
\$iptables -t filter -A INPUT -i wlan0 -s \$vpn -d \$local -p all -j ACCEPT
\$iptables -t filter -A INPUT -p udp --dport 53 -j ACCEPT
\$iptables -t filter -A INPUT -d \$local -p tcp --dport 36000 --syn -m state --state NEW -j ACCEPT
\$iptables -t filter -A INPUT -s \$lan -p tcp --dport 36000 --syn -m state --state NEW -j ACCEPT
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
# =================================================================================================
EOF
		chmod +x $FIREWALL_RULE_FILE
		echo "done.\n"
        fi
}

delete_route_to_169_254_0_0(){
	echo -e "delete route to 169.254.0.0/16 \n"
        FILE1="/etc/network/if-up.d/avahi-autoipd"
	sed -i -- "s|/bin/ip route|#/bin/ip route|g" $FILE1
	sed -i -- "s|/sbin/route|#/sbin/route|g" $FILE1
	echo -e "done.\n"
}

install_softwares(){
        apt-get update
	string="build-essential:git:htop:memtester:vim:subversion:synaptic:fcitx-table-boshiamy:gvncviewer"
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
	apt-get -y upgrade
}

install_chrome_browser() {
	wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - 
	sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
	apt-get update
	apt-get install -y google-chrome-stable
}

fix_too_many_authentication_failures() {
	sed -e '/pam_motd/ s/^#*/#/' -i /etc/pam.d/login
	apt-get purge landscape-client landscape-common
}

main(){
	fix_network_interfaces_name
	firewall_setting
	delete_route_to_169_254_0_0
	install_softwares
	install_chrome_browser
	fix_too_many_authentication_failures
	echo -e "now you should reboot your computer for configurations take affect.\n"
	echo -e "RUN 'reboot' in your prompt # symbol\n"
}

echo -e "This script will do the following tasks for your Raspberry Pi 2, including: \n"
echo -e "  1.Fix network interfaces name (To conventional 'eth0' and 'wlan0') \n"
echo -e "  2.Firewall rule setting (Write firewall rules in /etc/network/if-up.d/firewall)\n"
echo -e "  3.delete route to 169.254.0.0\n"
echo -e "  4.install softwares you need\n"
echo -e "  5.install chrome browser\n"
echo -e "  6.fix too many authentication failures problem\n"

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

