#!/bin/bash
# This script will do some operations on your Ubuntu 22.04 machine (Used as OpenVPN Client) 
# before you run this script , please specify some parameters here ;
# 
#######################################################################################################################################
CLIENT_OS_TYPE="Linux"                                 # possible values are 'Linux' / 'Windows' / 'Android' / 'iOS'
SUDO_USER_SERVER="labasky"                             # The user who own sudo priviledge on openvpn server
SUDO_USER_CLIENT="labasky"                             # The user who own sudo priviledge on openvpn client
CLIENT_NAME="client1"                                  # what is your client name , this will be used as client's filename (.ovpn)
YOUR_SERVER_IP="111.234.56.78"                         # Write Public IP of your OpenVPN Server here
SSH_CUSTOM_PORT_SERVER="36000"                         # The SSH Service port on OpenVPN Server
PATH_TO_OPENVPN_LOG="/tmp/openvpn.log"                 # The path to (Client side's) openvpn log
#######################################################################################################################################
# no need to setup below , script will know it and use it automatically for u 
WIRED_INTERFACE_NAME="$(ip link show | grep '2:' | cut -d ':' -f 2 | sed 's/^ *//g')"
PATH_TO_OVPN_FILE_ON_SERVER="/home/$SUDO_USER_SERVER/client-configs/files/$CLIENT_NAME.ovpn"
USE_SYSTEMD_RESOLVED="$(cat /etc/resolv.conf | grep 'nameserver 127.0.0.53' | wc -l)"
OPENVPN_SYSTEMD_RESOLVED_INSTALLED="$(apt list --installed 2>/dev/null | grep openvpn-systemd-resolved | wc -l)"
OPENVPN_INSTALLED="$(apt list --installed 2>/dev/null | grep openvpn | grep -v openvpn-systemd-resolved | wc -l)"
OPENVPN_CLIENT_PID="$(/usr/bin/ps aux | grep openvpn | grep root | head -1 | tr -s ' ' | cut -d ' ' -f 2 | sed 's/^[ \t]*//')"
TUN0_IS_RUNNING="$(ifconfig tun0 2>/dev/null | wc -l)"
#######################################################################################################################################
# useful links: 
# https://www.cyberciti.biz/faq/ubuntu-22-04-lts-set-up-openvpn-server-in-5-minutes/
# https://www.digitalocean.com/community/tutorials/how-to-set-up-and-configure-an-openvpn-server-on-ubuntu-22-04
# https://www.cyberciti.biz/open-source/command-line-hacks/linux-run-command-as-different-user/
# https://bash.cyberciti.biz/security/linux-openvpn-firewall-etc-iptables-add-openvpn-rules-sh-shell-script/
#######################################################################################################################################
#                            <<Tested on Ubuntu 22.04 Desktop Edition>>
#######################################################################################################################################

say_goodbye() {
        echo "see you next time"
}

copy_client_ovpn_file_to_local() {
	scp -P $SSH_CUSTOM_PORT_SERVER $SUDO_USER_SERVER@$YOUR_SERVER_IP:$PATH_TO_OVPN_FILE_ON_SERVER /home/$SUDO_USER_CLIENT/ \
	&& echo -e "Congraduations !!! $CLIENT_NAME.ovpn already copied to /home/$SUDO_USER_CLIENT/ \n" \
	|| echo -e "Oops ... $CLIENT_NAME.ovpn copied failed , please check : \n \
	   1. $CLIENT_NAME.ovpn file path on server is correct , it should be : $PATH_TO_OVPN_FILE_ON_SERVER \n \
	   2. Your OpenVPN Server IP is $YOUR_SERVER_IP \n \
	   3. SSH Service is running on CUSTOM PORT $SSH_CUSTOM_PORT_SERVER on OpenVPN Server \n \
	   4. You type in correct username '$SUDO_USER_SERVER' on OpenVPN Server \n \
	   5. is your SSH service on OpenVPN Server denied password login ?"
	chown $SUDO_USER_CLIENT:$SUDO_USER_CLIENT /home/$SUDO_USER_CLIENT/$CLIENT_NAME.ovpn
	chmod 600 /home/$SUDO_USER_CLIENT/$CLIENT_NAME.ovpn
}

install_openvpn_client() {

	if [ $OPENVPN_INSTALLED == "0" ]; then
		apt-get update
		apt-get install openvpn -y
	fi

	if [ $CLIENT_OS_TYPE == "Linux" ] && [ $USE_SYSTEMD_RESOLVED == "1" ] && [ $OPENVPN_SYSTEMD_RESOLVED_INSTALLED == "0" ]; then
		# install openvpn-systemd-resolved package , if client OS type is Linux and it uses systemd resolved as DNS resolver
		apt-get install openvpn-systemd-resolved -y
	fi

	if [ $USE_SYSTEMD_RESOLVED == "1" ] && [ $CLIENT_OS_TYPE == "Linux" ] && [ -f /home/$SUDO_USER_CLIENT/$CLIENT_NAME.ovpn ]; then
		# delete ;2; pattern in $CLIENT.opvn file , this will uncomment 5 lines in $CLIENT.ovpn file
		sed -i -- 's|;2;||g' /home/$SUDO_USER_CLIENT/$CLIENT_NAME.ovpn
	fi

	if [ $USE_SYSTEMD_RESOLVED == "0" ] && [ $CLIENT_OS_TYPE == "Linux" ] && [ -f /etc/openvpn/update-resolv-conf ] && [ -f /home/$SUDO_USER_CLIENT/$CLIENT_NAME.ovpn ]; then
		# delete ;1; pattern in $CLIENT.ovpn file , this will uncomment 3 lines in $CLIENT.ovpn file
		sed -i -- 's|;1;||g' /home/$SUDO_USER_CLIENT/$CLIENT_NAME.ovpn
	fi	
}

start_openvpn_client() {
	if [ $TUN0_IS_RUNNING -eq 0 ]; then
		echo -e "start openvpn client ... \n"
		sudo openvpn --config /home/$SUDO_USER_CLIENT/$CLIENT_NAME.ovpn | tee -a $PATH_TO_OPENVPN_LOG &
		echo -e "done. \n"
	else
		echo -e "interface tun0 already up and running , \n"
		echo -e "no need to start again. \n"
	fi
}

stop_openvpn_client() {
	# find openvpn clients PID and kill it 
	if [ $TUN0_IS_RUNNING -gt 0 ]; then
		echo -e " stop openvpn client ... \n"
		sudo kill $OPENVPN_CLIENT_PID | tee -a $PATH_TO_OPENVPN_LOG &
		echo -e "done. \n"
	else
		echo -e "interface tun0 is not up and running , \n"
		echo -e "no need to stop it again. \n"
	fi
}	

echo -e "This script will do some operations on your Ubuntu 22.04 machine (used as OpenVPN Client)\n"
echo -e "[0] Do nothing and Exit \n"
echo -e "[1] Copy client .ovpn file (From OpenVPN Server) to local computer \n"
echo -e "[2] Install openvpn client \n"
echo -e "[3] Start openvpn client \n"
echo -e "[4] Stop openvpn client \n"
read -p "Please Enter Your Choice : " choice
case $choice in
	1)
		copy_client_ovpn_file_to_local
		;;
	2)
		install_openvpn_client
		;;
	3)
		start_openvpn_client
		;;
	4)
		stop_openvpn_client
		;;
        0)
                say_goodbye
                exit 1
                ;;
        *) echo -e "Please Enter Number 0 to 4 \n"
esac
