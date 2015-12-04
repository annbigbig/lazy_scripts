#!/bin/sh
# This script will perform lots of work for fine tune Ubuntu 15.10 you have just flashed into micro-SD card
# plug micro-SD card into Raspberry pi 2 and turn the power on
# after first booting Raspberry pi 2 and finished username and locale settings,
# run this script on Raspberry pi 2
# before you run this script , please specify some parameters here:
#
###

say_goodbye (){
	echo "goodbye everyone"
}

fix_network_interfaces_name(){
	ETH0_MAC_ADDRESS=$(ifconfig |grep enxb | cut -d ' ' -f 6)
	WLAN0_MAC_ADDRESS=$(ifconfig |grep enxe | cut -d ' ' -f 6)
	NETWORK_RULES_FILE="/etc/udev/rules.d/70-network.rules"

	if [ ! -z "$ETH0_MAC_ADDRESS" -a "$ETH0_MAC_ADDRESS" != " " -a ! -f $NETWORK_RULES_FILE ]; then
		echo "mac address of eth0 : $ETH0_MAC_ADDRESS \n"
		echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$ETH0_MAC_ADDRESS\", NAME=\"eth0\"" >> $NETWORK_RULES_FILE
	else
		echo "mac address of eth0 not found."
	fi

	if [ ! -z "$WLAN0_MAC_ADDRESS" -a "$WLAN0_MAC_ADDRESS" != " " -a ! -f $NETWORK_RULES_FILE ]; then
		echo "mac address of wlan0 : $WLAN0_MAC_ADDRESS \n"
		echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$WLAN0_MAC_ADDRESS\", NAME=\"wlan0\"" >> $NETWORK_RULES_FILE
	else
		echo "mac address of wlan0 not found."
	fi

	if [ -f $NETWORK_RULES_FILE ]; then
		echo "$NETWORK_RULES_FILE has been created successfully."
	else
		echo "$NETWORK_RULES_FILE doesn't exist, network interface names didn't changed"
	fi

}

turn_on_tlp_power_save(){
	echo "Turn on TLP power save.\n"
	sed -i -- "s}TLP_ENABLE=1|TLP_ENABLE=0|g" /etc/default/tlp
	echo "done.\n"
}

firewall_setting(){
        FIREWALL_RULE_FILE="/tmp/test.firewall"
        if [ ! -f $FIREWALL_RULE_FILE ]; then
                echo "writing local firewall rule to $FIREWALL_RULE_FILE \n"
                cat >> $FIREWALL_RULE_FILE << EOF
#!/bin/sh
# ============ Set your network parameters here ===================================================
iptables=/sbin/iptables
loopback=127.0.0.1
local="\$(/sbin/ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"
#local=10.1.1.170
lan=10.1.1.0/24
vpn=10.8.0.0/24
# =================================================================================================
\$iptables -t filter -F
\$iptables -t filter -A INPUT -i lo -s \$loopback -d \$loopback -p all -j ACCEPT
\$iptables -t filter -A INPUT -i eth0 -s \$local -d \$local -p all -j ACCEPT
\$iptables -t filter -A INPUT -i eth0 -s \$lan -d \$local -p all -j ACCEPT
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

main(){
	fix_network_interfaces_name
	turn_on_tlp_power_save
	firewall_setting
}

echo "This script will do the following tasks for your Raspberry Pi 2, including: \n"
echo "1.Fix network interfaces name (To conventional 'eth0' and 'wlan0' \n"
echo "2.Turn on tlp power save (Set TLP_ENABLE=1 in /etc/default/tlp) \n"
echo "3.Firewall rule setting (Write firewall rules in /etc/network/if-up.d/firewall\n"

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

