#!/bin/bash
# This script will do some operations on your Ubuntu 22.04 machine (Used as Certificate Authority)
# before you run this script , please specify some parameters here ;
# 
############################################################################################################
SUDO_USER="labasky"                     # The user who own sudo priviledge on this (CA) server
COMMON_NAME="server-contabo"            # Common Name (CN) of OpenVPN Server , could be anything u like
############################################################################################################
EASYRSA_REQ_COUNTRY="TW"                # These parameters for building CA
EASYRSA_REQ_PROVINCE="Taiwan"           # change it to suit your situation
EASYRSA_REQ_CITY="New Taipei"
EASYRSA_REQ_ORG="TonShin"
EASYRSA_REQ_EMAIL="admin@dq5rocks.com"
EASYRSA_REQ_OU="Community"
EASYRSA_ALGO="ec"                       # don't change it
EASYRSA_DIGEST="sha512"                 # don't change it
EASYRSA_CA_EXPIRE="36500"               # ca.crt valid for 100 years
EASYRSA_CERT_EXPIRE="36500"             # server.crt valid for 100 years
############################################################################################################
PATH_TO_SERVER_REQ="/tmp/$COMMON_NAME.req"         # where is server.req file to be sign ? 
PATH_TO_SERVER_CRT="/tmp/$COMMON_NAME.crt"         # where is resulting server.crt should be placed ?
PATH_TO_CA_CRT="/tmp/ca.crt"                       # where is ca.crt should be placed ?
#CLIENT_NAME="client1"                             # what is your client name ? 
CLIENT_NAME="client-contabo"                       # what is your client name ? 
PATH_TO_CLIENT_REQ="/tmp/$CLIENT_NAME.req"         # where is clientXX.req file to be sign ? 
PATH_TO_CLIENT_CRT="/tmp/$CLIENT_NAME.crt"         # where is resulting clientXX.crt file to be placed ? 
############################################################################################################
# no need to setup below , script will know it and use it automatically for u 
WIRED_INTERFACE_NAME="$(ip link show | grep '2:' | cut -d ':' -f 2 | sed 's/^ *//g')"
############################################################################################################
# useful links: 
# https://www.cyberciti.biz/faq/ubuntu-22-04-lts-set-up-openvpn-server-in-5-minutes/
# https://www.digitalocean.com/community/tutorials/how-to-set-up-and-configure-an-openvpn-server-on-ubuntu-22-04
# https://www.cyberciti.biz/open-source/command-line-hacks/linux-run-command-as-different-user/
############################################################################################################
#                            <<Tested on Ubuntu 22.04 Server Edition>>
############################################################################################################

say_goodbye() {
        echo "see you next time"
}

setup_certificate_authority() {
	# check if ca.crt and ca.key existed , if so , no need to generate them again
	if [ -f /home/$SUDO_USER/easy-rsa/pki/ca.crt ] && [ -f /home/$SUDO_USER/easy-rsa/pki/private/ca.key ]; then
		echo -e "/home/$SUDO_USER/easy-rsa/pki/ca.crt  \n"
		echo -e "/home/$SUDO_USER/easy-rsa/pki/private/ca.key \n"
		echo -e "already existed , no need to generate them again \n"
		return
	fi

	# Installing Easy-RSA
	apt-get update
	apt-get install -y easy-rsa

	# Preparing a Public Key Infrastructure Directory
	mkdir /home/$SUDO_USER/easy-rsa
	ln -s /usr/share/easy-rsa/* /home/$SUDO_USER/easy-rsa/
	chmod 700 /home/$SUDO_USER/easy-rsa
	chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/easy-rsa
	su - $SUDO_USER -c "cd /home/$SUDO_USER/easy-rsa && ./easyrsa init-pki"

	# Creating a Certificate Authority
	su - $SUDO_USER -c "cd /home/$SUDO_USER/easy-rsa && touch ./vars"
	cat > /home/$SUDO_USER/easy-rsa/vars << "EOF"
set_var EASYRSA_REQ_COUNTRY    "_EASYRSA_REQ_COUNTRY_"
set_var EASYRSA_REQ_PROVINCE   "_EASYRSA_REQ_PROVINCE_"
set_var EASYRSA_REQ_CITY       "_EASYRSA_REQ_CITY_"
set_var EASYRSA_REQ_ORG        "_EASYRSA_REQ_ORG_"
set_var EASYRSA_REQ_EMAIL      "_EASYRSA_REQ_EMAIL_"
set_var EASYRSA_REQ_OU         "_EASYRSA_REQ_OU_"
set_var EASYRSA_ALGO           "_EASYRSA_ALGO_"
set_var EASYRSA_DIGEST         "_EASYRSA_DIGEST_"
set_var EASYRSA_CA_EXPIRE      "_EASYRSA_CA_EXPIRE_"
set_var EASYRSA_CERT_EXPIRE    "_EASYRSA_CERT_EXPIRE_"
EOF
	sed -i -- "s|_EASYRSA_REQ_COUNTRY_|$EASYRSA_REQ_COUNTRY|g" /home/$SUDO_USER/easy-rsa/vars
	sed -i -- "s|_EASYRSA_REQ_PROVINCE_|$EASYRSA_REQ_PROVINCE|g" /home/$SUDO_USER/easy-rsa/vars
	sed -i -- "s|_EASYRSA_REQ_CITY_|$EASYRSA_REQ_CITY|g" /home/$SUDO_USER/easy-rsa/vars
	sed -i -- "s|_EASYRSA_REQ_ORG_|$EASYRSA_REQ_ORG|g" /home/$SUDO_USER/easy-rsa/vars
	sed -i -- "s|_EASYRSA_REQ_EMAIL_|$EASYRSA_REQ_EMAIL|g" /home/$SUDO_USER/easy-rsa/vars
	sed -i -- "s|_EASYRSA_REQ_OU_|$EASYRSA_REQ_OU|g" /home/$SUDO_USER/easy-rsa/vars
	sed -i -- "s|_EASYRSA_ALGO_|$EASYRSA_ALGO|g" /home/$SUDO_USER/easy-rsa/vars
	sed -i -- "s|_EASYRSA_DIGEST_|$EASYRSA_DIGEST|g" /home/$SUDO_USER/easy-rsa/vars
	sed -i -- "s|_EASYRSA_CA_EXPIRE_|$EASYRSA_CA_EXPIRE|g" /home/$SUDO_USER/easy-rsa/vars
	sed -i -- "s|_EASYRSA_CERT_EXPIRE_|$EASYRSA_CERT_EXPIRE|g" /home/$SUDO_USER/easy-rsa/vars
	chmod 644 /home/$SUDO_USER/easy-rsa/vars
	chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/easy-rsa/vars
	su - $SUDO_USER -c "cd /home/$SUDO_USER/easy-rsa && ./easyrsa build-ca nopass"
	
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
	echo -e "Congraduations !! now 2 important files for CA is ready. \n"
	echo -e "/home/$SUDO_USER/easy-rsa/pki/ca.crt \n"
	echo -e " and \n"
	echo -e "/home/$SUDO_USER/easy-rsa/pki/private/ca.key \n"
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
}

signing_server_certificate_request() {
	su - $SUDO_USER -c "cd /home/$SUDO_USER/easy-rsa && ./easyrsa import-req $PATH_TO_SERVER_REQ $COMMON_NAME"
	su - $SUDO_USER -c "cd /home/$SUDO_USER/easy-rsa && ./easyrsa sign-req server $COMMON_NAME"
	su - $SUDO_USER -c "cp /home/$SUDO_USER/easy-rsa/pki/issued/$COMMON_NAME.crt $PATH_TO_SERVER_CRT"
	su - $SUDO_USER -c "cp /home/$SUDO_USER/easy-rsa/pki/ca.crt $PATH_TO_CA_CRT"
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
	echo -e "Congraduations !! now 2 important files for Server is ready. \n"
	echo -e "$PATH_TO_SERVER_CRT \n"
	echo -e " and \n"
	echo -e "$PATH_TO_CA_CRT \n"
	echo -e "copy them back to openvpn server !!! fire commands below : \n"
	echo -e "scp -P <CUSTOM_SSH_PORT> $PATH_TO_CA_CRT <USERNAME>@<IP_ADDRESS_OF_OPENVPN_SERVER>:/tmp\n"
	echo -e "scp -P <CUSTOM_SSH_PORT> $PATH_TO_SERVER_CRT <USERNAME>@<IP_ADDRESS_OF_OPENVPN_SERVER>:/tmp\n"
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
}

signing_client_certificate_request() {
	su - $SUDO_USER -c "cd /home/$SUDO_USER/easy-rsa && ./easyrsa import-req $PATH_TO_CLIENT_REQ $CLIENT_NAME"
	su - $SUDO_USER -c "cd /home/$SUDO_USER/easy-rsa && ./easyrsa sign-req client $CLIENT_NAME"
	su - $SUDO_USER -c "cp /home/$SUDO_USER/easy-rsa/pki/issued/$CLIENT_NAME.crt $PATH_TO_CLIENT_CRT"
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
	echo -e "Congraduations !! now important file for Client is ready. \n"
	echo -e "/home/$SUDO_USER/easy-rsa/pki/issued/$CLIENT_NAME.crt is copied to $PATH_TO_CLIENT_CRT \n"
	echo -e "copy it back to openvpn server !!! fire commands below : \n"
	echo -e "scp -P <CUSTOM_SSH_PORT> $PATH_TO_CLIENT_CRT <USERNAME>@<IP_ADDRESS_OF_OPENVPN_SERVER>:/tmp\n"
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
}

echo -e "This script will do some operations on your Ubuntu 22.04 machine (used as certificate authority) \n"
echo -e "[0] Do nothing and Exit \n"
echo -e "[1] Setup Certificate Authority \n"
echo -e "[2] Signing server certificate request (turn serverXX.req to serverXX.crt) \n"
echo -e "[3] Signing client certificate request (turn clientXX.req to clientXX.crt) \n"
read -p "Please Enter Your Choice : " choice
case $choice in
	1*)
		setup_certificate_authority
		;;
	2*)
		signing_server_certificate_request
		;;
	3*)
		signing_client_certificate_request
		;;
        0*)
                say_goodbye
                exit 1
                ;;
        *) echo -e "Please Enter Number 0 to 3 \n"
esac
