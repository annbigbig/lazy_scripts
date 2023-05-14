#!/bin/bash
# This script will install IKEv2 VPN Client on your Ubuntu 22.04 machine 
# before you run this script , please specify some parameters here ;
# 
#######################################################################################################################################
SUDOER_USER_MANUAL=""                                  # Write a sudoer username here , usually UID 1000 that user or leave it blank
YOUR_SERVER_IP="49.159.111.111"                        # Write Public IP of your IKEv2 VPN Server here
SSH_CUSTOM_PORT_SERVER="36000"                         # The SSH Service port on IKEv2 VPN Server
IKEV2_USERNAME="tony"                                  # write username here
IKEV2_PASSWORD="tony55667788"                          # write password here
#######################################################################################################################################
# no need to setup below , script will know it and use it automatically for u 
WIRED_INTERFACE_NAME="$(ip link show | grep '2:' | cut -d ':' -f 2 | sed 's/^ *//g')"
SUDOER_USER_AUTO="$(cat /etc/passwd | grep 1000 | cut -d ':' -f 1 | tr -s ' ')"
[[ -z $SUDOER_USER_MANUAL ]] && SUDOER_USER="$SUDOER_USER_AUTO" || SUDOER_USER="$SUDOER_USER_MANUAL"
CHARON_CMD_PID="$(ps aux | grep charon-cmd | grep ca-cert.pem | tr -s ' '|cut -d ' ' -f 2)"
#######################################################################################################################################
# useful links: 
#
#######################################################################################################################################
#                            <<Tested on Ubuntu 22.04 Server Edition>>
# https://www.digitalocean.com/community/tutorials/how-to-set-up-an-ikev2-vpn-server-with-strongswan-on-ubuntu-22-04
#######################################################################################################################################

say_goodbye() {
        echo "see you next time"
}

install_strongswan() {
	apt-get update
	apt-get install -y strongswan libcharon-extra-plugins charon-cmd
	systemctl disable --now strongswan-starter
	systemctl stop strongswan-starter
}

copy_file_to_client() {
	echo -e "Please copy /etc/ipsec.d/cacerts/ca-cert.pem from remote IKEv2 VPN Server to Local (as VPN client) \n"
	echo -e "place it at the same path /etc/ipsec.d/cacerts/ca-cert.pem \n"
	echo -e "and change its owner/group to root:root , file permission -rw-r--r-- (644) \n"
	echo -e "There may be security concerns about Exposing SSH port on the Internet     \n"
	echo -e "[Hint] related commands as follow : \n"
	echo -e "請手動複製遠端Server的/etc/ipsec.d/cacerts/ca-cert.pem到本地Client端同一路徑上\n"
	echo -e "並將其owner group都變更為root用戶，權限644\n"
	echo -e "曝露遠端Server的SSH port於公網有安全上的顧慮\n"
	echo -e "指令會是: \n"
	echo -e "ssh -p<SSH_CUSTOM_PORT_SERVER> <SUDO_USER>@<YOUR_SERVER_IP>:/etc/ipsec.d/cacerts/ca-cert.pem /tmp \n"
	echo -e "sudo cp /tmp/ca-cert.pem /etc/ipsec.d/cacerts/ca-cert.pem \n"
	echo -e "sudo chown root:root /etc/ipsec.d/cacerts/ca-cert.pem \n"
	echo -e "sudo chmod 644 /etc/ipsec.d/cacerts/ca-cert.pem \n"
	#CA_CERT_PATH="/etc/ipsec.d/cacerts/ca-cert.pem"
	#scp -p$SSH_CUSTOM_PORT_SERVER $SUDO_USER@$YOUR_SERVER_IP:$CA_CERT_PATH $CA_CERT_PATH
}

configuring_vpn_authentication() {
        PASSWORD_FILE="/etc/ipsec.secrets"
        sudo mv $PASSWORD_FILE{,.original}
        sudo cat >> $PASSWORD_FILE << "EOF"
IKEV2_USERNAME : EAP "IKEV2_PASSWORD"
EOF
	sed -i -- "s|IKEV2_USERNAME|$IKEV2_USERNAME|g" $PASSWORD_FILE
	sed -i -- "s|IKEV2_PASSWORD|$IKEV2_PASSWORD|g" $PASSWORD_FILE
}

configuring_strongswan() {
	CONF_FILE="/etc/ipsec.conf"
        sudo mv $CONF_FILE{,.original}
        sudo cat >> $CONF_FILE << "EOF"
config setup

conn ikev2-rw
    right=YOUR_SERVER_IP
    # This should match the `leftid` value on your server's configuration
    rightid=YOUR_SERVER_IP
    rightsubnet=0.0.0.0/0
    rightauth=pubkey
    leftsourceip=%config
    leftid=IKEV2_USERNAME
    leftauth=eap-mschapv2
    eap_identity=%identity
    auto=start
EOF
	sed -i -- "s|YOUR_SERVER_IP|$YOUR_SERVER_IP|g" $CONF_FILE
	sed -i -- "s|IKEV2_USERNAME|$IKEV2_USERNAME|g" $CONF_FILE
}

start_ikev2_client() {
	CA_CERT_PATH="/etc/ipsec.d/cacerts/ca-cert.pem"
	if [ -z "$CHARON_CMD_PID" ]; then
		sudo charon-cmd --cert $CA_CERT_PATH --host $YOUR_SERVER_IP --identity $IKEV2_USERNAME
	else
		echo -e "IKEv2 VPN seems already connected , no need to start it again , Done. \n"
	fi
}	

stop_ikev2_client() {
	if [ -n "$CHARON_CMD_PID" ]; then
		sudo kill $CHARON_CMD_PID
	else
		echo -e "charon-cmd related PID not found , no need to stop it again , Done. \n"
	fi
}

echo -e "This script will do some operations on your Ubuntu 22.04 machine (used as IKEv2 VPN Client)\n"
echo -e "[0] Do nothing and Exit \n"
echo -e "[1] Install Strongswan \n"
echo -e "[2] Copy /etc/ipsec.d/cacerts/ca-cert.pem file (From IKEv2 VPN Server) to local computer (as VPN Client) \n"
echo -e "[3] Configuring VPN authentication \n"
echo -e "[4] Configuring Strongswan (as VPN Client) \n"
echo -e "[5] Start IKEv2 VPN client \n"
echo -e "[6] Stop IKEv2 VPN client \n"
read -p "Please Enter Your Choice : " choice

case $choice in
        1)
                install_strongswan
                ;;
        2)
                copy_file_to_client
                ;;
        3)
                configuring_vpn_authentication
                ;;
        4)
                configuring_strongswan
                ;;
	5)
		start_ikev2_client
		;;
	6)
		stop_ikev2_client
		;;
        0)
                say_goodbye
                exit 1
                ;;
        *) echo -e "Please Enter Number 0 to 6 \n"
esac
