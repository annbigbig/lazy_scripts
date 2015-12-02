#!/bin/sh
# This script will perform lots of work for fine tune Ubuntu 15.10 you have just flashed into micro-SD card
# plug micro-SD card into Raspberry pi 2 and turn the power on
# after first booting Raspberry pi 2 and finished username and locale settings,
# run this script on Raspberry pi 2
# before you run this script , please specify some parameters here:
#
# network interface eth0
ETH0_ON="yes"
ETH0_PROTOCOL="static" # could be 'dhcp' or 'static'
# if you choose 'dhcp' for eth0 interface , leave the bellow empty.
ETH0_ADDRESS="10.1.1.173" # 10.1.1.173
ETH0_NETMASK="255.255.255.0"	# 255.255.255.0
ETH0_GATEWAY="10.1.1.1" # 10.1.1.1
# network interface wlan0
WLAN0_ON="no"
WLAN0_PROTOCOL="dhcp" # could be 'dhcp' or 'static'
# if you choose 'dhcp' for wlan0 interface , leave the bellow empty.
WLAN0_ADDRESS="" # 10.1.1.174
WLAN0_NETMASK="" # 255.255.255.0
WLAN0_GATEWAY="" # 10.1.1.1
WIFI_SSID="" # my_wifi_SSID
WIFI_PASS="" # my_wifi_PASSWORD
###
# the dns resolvers you preferred
DNS_SERVERS="8.8.8.8 8.8.4.4 168.95.192.1 168.95.1.1"
###

say_goodbye (){
	echo "goodbye everyone"
}


fix_network_interfaces_name(){
	ETH0_MAC_ADDRESS=$(ifconfig |grep enxb | cut -d ' ' -f 6)
	WLAN0_MAC_ADDRESS=$(ifconfig |grep enxe | cut -d ' ' -f 6)
	NETWORK_RULES_FILE=/etc/udev/rules.d/70-network.rules

	if [ ! -z "$ETH0_MAC_ADDRESS" -a "$ETH0_MAC_ADDRESS" != " " ]; then
		echo "mac address of eth0 : $ETH0_MAC_ADDRESS \n"
		echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$ETH0_MAC_ADDRESS\", NAME=\"eth0\"" >> $NETWORK_RULES_FILE
	else
		echo "mac address of eth0 not found."
	fi

	if [ ! -z "$WLAN0_MAC_ADDRESS" -a "$WLAN0_MAC_ADDRESS" != " " ]; then
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

network_setting(){
 ### eth0
	ETH0_CONFIG_FILE="/etc/network/interfaces.d/eth0"
	RESOLV_TAIL_FILE="/etc/resolvconf/resolv.conf.d/tail"
	if [ "$ETH0_ON" = "yes" ]; then
		echo "turn on eth0\n"
		rm -rf $ETH0_CONFIG_FILE
		echo "auto eth0" >> $ETH0_CONFIG_FILE
		echo "allow-hotplug eth0" >> $ETH0_CONFIG_FILE
		case $ETH0_PROTOCOL in
			"dhcp")
				echo "\tiface eth0 inet dhcp" >> $ETH0_CONFIG_FILE
				echo "" >> $RESOLV_TAIL_FILE
				
			;;
			"static")
				echo "iface eth0 inet static" >> $ETH0_CONFIG_FILE
				echo "\taddress $ETH0_ADDRESS" >> $ETH0_CONFIG_FILE
				echo "\tnetmask $ETH0_NETMASK" >> $ETH0_CONFIG_FILE
				echo "\tgateway $ETH0_GATEWAY" >> $ETH0_CONFIG_FILE
				echo "nameserver 8.8.8.8" >> $RESOLV_TAIL_FILE
				echo "nameserver 8.8.4.4" >> $RESOLV_TAIL_FILE
			;;

			*)
				echo "The value of ETH_PROTOCOL must be 'dhcp' or 'static'."
			;;
		esac
	else
		rm -rf $ETH0_CONFIG_FILE
	fi

 ### wlan0

}

firewall_setting(){
	echo "function firewall_setting() was called."
}

main(){
	#fix_network_interfaces_name
	network_setting
	firewall_setting
}

echo "This script will do the following tasks for your Raspberry Pi 2, including: \n"
echo "1.fix network interfaces name (to conventional 'eth0' and 'wlan0' \n"
echo "2.Network setting \n"
echo "3.Firewall rule setting \n"

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

