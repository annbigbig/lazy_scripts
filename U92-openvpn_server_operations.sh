#!/bin/bash
# This script will do some operations on your Ubuntu 22.04 machine (Used as OpenVPN Server)
# before you run this script , please specify some parameters here ;
# 
#######################################################################################################################################
SUDO_USER="labasky"                                    # The user who own sudo priviledge on this (CA) server
COMMON_NAME="server"                                   # Common Name (CN) of OpenVPN Server , could be anything u like
EASYRSA_CERT_EXPIRE="36500"                            # server.crt valid for 100 years
PATH_TO_SERVER_REQ="/tmp/$COMMON_NAME.req"             # where is resulting server.req should be placed ?
PATH_TO_SERVER_CRT="/tmp/$COMMON_NAME.crt"             # where is signed server.crt to be import ?
PATH_TO_CA_CRT="/tmp/ca.crt"                           # where is ca.crt to be import ?
CLIENT_NAME="client1"                                  # what is your client name , this will be used as client's filename (key/cert)
PATH_TO_CLIENT_REQ="/tmp/$CLIENT_NAME.req"             # where is resulting clientXX.req should be placed ?
PATH_TO_CLIENT_CRT="/tmp/$CLIENT_NAME.crt"             # where is clientXX.crt to be import ?
LISTENING_PORT="1194"                                  # UDP port that OpenVPN service is running
SUBNET_BEHIND_THE_SERVER="192.168.251.0 255.255.255.0" # Private Subnet Behind the OpenVPN Server
YOUR_SERVER_IP="111.234.56.78"                         # Write Public IP of your OpenVPN Server here
#######################################################################################################################################
# no need to setup below , script will know it and use it automatically for u 
WIRED_INTERFACE_NAME="$(ip link show | grep '2:' | cut -d ':' -f 2 | sed 's/^ *//g')"
OPENVPN_INSTALLED="$(apt list --installed 2>/dev/null | grep openvpn | grep -v openvpn-systemd-resolved | wc -l)"
EASYRSA_INSTALLED="$(apt list --installed 2>/dev/null | grep easy-rsa | wc -l)"
#######################################################################################################################################
# useful links: 
# https://www.cyberciti.biz/faq/ubuntu-22-04-lts-set-up-openvpn-server-in-5-minutes/
# https://www.digitalocean.com/community/tutorials/how-to-set-up-and-configure-an-openvpn-server-on-ubuntu-22-04
# https://www.cyberciti.biz/open-source/command-line-hacks/linux-run-command-as-different-user/
# https://bash.cyberciti.biz/security/linux-openvpn-firewall-etc-iptables-add-openvpn-rules-sh-shell-script/
#######################################################################################################################################
#                            <<Tested on Ubuntu 22.04 Server Edition>>
#######################################################################################################################################

say_goodbye() {
        echo "see you next time"
}

install_openvpn_server() {
	# Installing OpenVPN and Easy-RSA
	apt-get update
	if [ $OPENVPN_INSTALLED == "0" ]; then
		apt-get install -y openvpn
	fi

	if [ $EASYRSA_INSTALLED == "0" ]; then
		apt-get install -y easy-rsa
	fi

	if [ ! -d /home/$SUDO_USER/easy-rsa ]; then
		mkdir /home/$SUDO_USER/easy-rsa
		ln -s /usr/share/easy-rsa/* /home/$SUDO_USER/easy-rsa/
		chmod 700 /home/$SUDO_USER/easy-rsa
		chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/easy-rsa

		# Creating a PKI for OpenVPN
		su - $SUDO_USER -c "cd /home/$SUDO_USER/easy-rsa && touch ./vars"
		cat > /home/$SUDO_USER/easy-rsa/vars << "EOF"
EASYRSA_ALGO="ec"
EASYRSA_DIGEST="sha512"
EASYRSA_CERT_EXPIRE="_EASYRSA_CERT_EXPIRE_"
EOF
		sed -i -- "s|_EASYRSA_CERT_EXPIRE_|$EASYRSA_CERT_EXPIRE|g" /home/$SUDO_USER/easy-rsa/vars
		su - $SUDO_USER -c "cd /home/$SUDO_USER/easy-rsa && ./easyrsa init-pki"
	else
		echo -e "Directory : /home/$SUDO_USER/easy-rsa \n"
		echo -e "Already existed , no need to do anything. \n"
	fi
}

generate_server_req_and_private_key() {
	# Creating an OpenVPN Server Certificate Request and Private Key
	su - $SUDO_USER -c "cd /home/$SUDO_USER/easy-rsa && ./easyrsa gen-req $COMMON_NAME nopass"
	cp /home/$SUDO_USER/easy-rsa/pki/private/$COMMON_NAME.key /etc/openvpn/server/
	chmod 400 /etc/openvpn/server/$COMMON_NAME.key
	su - $SUDO_USER -c "cp /home/labasky/easy-rsa/pki/reqs/$COMMON_NAME.req $PATH_TO_SERVER_REQ"
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
	echo -e "Congraduations !! now 2 important files for Server is ready. \n"
	echo -e "/home/$SUDO_USER/easy-rsa/pki/private/$COMMON_NAME.key already placed at /etc/openvpn/server/ \n"
	echo -e "/home/$SUDO_USER/easy-rsa/pki/reqs/$COMMON_NAME.req already copied to $PATH_TO_SERVER_REQ \n"
	echo -e "now copy $PATH_TO_SERVER_REQ to Certificat Authority (CA Server) for singing \n"
	echo -e "scp -P <CUSTOM_SSH_PORT> $PATH_TO_SERVER_REQ <USERNAME>@IP_ADDRESS_OF_CA_SERVER:/tmp \n"
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
}

copy_server_files_to_right_place() {
	cp $PATH_TO_SERVER_CRT /etc/openvpn/server
	cp $PATH_TO_CA_CRT /etc/openvpn/server
	chown root:root /etc/openvpn/server/*.crt
	chmod 400 /etc/openvpn/server/*.crt
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
	echo -e "Congraduations !! now 2 important files for Server is ready. \n"
	echo -e "$PATH_TO_SERVER_CRT already copied to /etc/openvpn/server/ \n"
	echo -e "$PATH_TO_CA_CRT already copied to /etc/openvpn/server \n"
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
}

generate_tls_crypt_key() {
	PATH_TO_TA_KEY="/etc/openvpn/server/ta.key"
	if [ ! -f $PATH_TO_TA_KEY ]; then
		su - $SUDO_USER -c "cd /home/$SUDO_USER/easy-rsa && openvpn --genkey secret ta.key"
		cp /home/$SUDO_USER/easy-rsa/ta.key /etc/openvpn/server
		chown root:root /etc/openvpn/server/ta.key
		chmod 400 /etc/openvpn/server/ta.key
		echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
		echo -e "Congraduations !! now ta.key is ready. \n"
		echo -e "/home/$SUDO_USER/easy-rsa/ta.key already copied to $PATH_TO_TA_KEY \n"
		echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
	else
		echo -e "ta.key already existed at $PATH_TO_TA_KEY \n"
		echo -e "no need to do anything else. \n"
	fi
}

create_subdirs_for_clients() {
	PATH_TO_CLIENT_KEYS="/home/$SUDO_USER/client-configs/keys"
	if [ ! -d $PATH_TO_CLIENT_KEYS ]; then
		su - $SUDO_USER -c "mkdir -p /home/$SUDO_USER/client-configs/keys"
		chmod -R 700 /home/$SUDO_USER/client-configs
		chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER
		echo -e "Directory $PATH_TO_CLIENT_KEYS now created successfully. \n"
	else
		echo -e "$PATH_TO_CLIENT_KEYS directory already esisted \n"
		echo -e "no need to do anything else. \n"
	fi
}

generate_clients_req_and_private_key() {
	su - $SUDO_USER -c "cd /home/$SUDO_USER/easy-rsa && ./easyrsa gen-req $CLIENT_NAME nopass"
	su - $SUDO_USER -c "cp /home/$SUDO_USER/easy-rsa/pki/private/$CLIENT_NAME.key /home/$SUDO_USER/client-configs/keys/"
	su - $SUDO_USER -c "cp /home/$SUDO_USER/easy-rsa/pki/reqs/$CLIENT_NAME.req $PATH_TO_CLIENT_REQ"
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
	echo -e "Congraduations !! now 2 important files for Client is ready. \n"
	echo -e "$CLIENT_NAME.key already copied to /home/$SUDO_USER/client-configs/keys/ \n"
	echo -e "$CLIENT_NAME.req already copied to $PATH_TO_CLIENT_REQ \n"
	echo -e "now copy $PATH_TO_CLIENT_REQ to ca server for signing !!! fire commands below : \n"
	echo -e "scp -P <CUSTOM_SSH_PORT> $PATH_TO_CLIENT_REQ <USERNAME>@<IP_ADDRESS_OF_CA_SERVER>:/tmp \n"
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
}

copy_client_files_to_right_place() {
	su - $SUDO_USER -c "cp $PATH_TO_CLIENT_CRT /home/$SUDO_USER/client-configs/keys/"
	cp /home/$SUDO_USER/easy-rsa/ta.key /home/$SUDO_USER/client-configs/keys/
	cp /etc/openvpn/server/ca.crt /home/$SUDO_USER/client-configs/keys/
	chmod 400 /home/$SUDO_USER/client-configs/keys/*.crt
	chmod 400 /home/$SUDO_USER/client-configs/keys/*.key
	chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/client-configs/
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
	echo -e "Congraduations !! important 3 files for Client is ready. \n"
	echo -e "ca.crt already copied to /home/$SUDO_USER/client-configs/keys/ca.crt \n"
	echo -e "ta.key already copied to /home/$SUDO_USER/client-configs/keys/ta.key \n"
	echo -e "$PATH_TO_CLIENT_CRT already copied to /home/$SUDO_USER/client-configs/keys/$CLIENT_NAME.crt \n"
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
}

configure_openvpn_server() {
	cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf /etc/openvpn/server/
	SERVER_CONFIG="/etc/openvpn/server/server.conf"
	sed -i -- '/^tls-auth.*/a tls-crypt ta.key' $SERVER_CONFIG
	sed -i -- '/tls-auth ta.key 0/c \;tls-auth ta.key 0' $SERVER_CONFIG
	sed -i -- '/^cipher AES-256-CBC/a cipher AES-256-GCM' $SERVER_CONFIG
	sed -i -- '/cipher AES-256-CBC/c \;cipher AES-256-CBC' $SERVER_CONFIG
	sed -i -- '/^cipher AES-256-GCM/a auth SHA256' $SERVER_CONFIG
	sed -i -- '/^dh dh2048.pem/a dh none' $SERVER_CONFIG
	sed -i -- '/dh dh2048.pem/c \;dh dh2048.pem' $SERVER_CONFIG
	sed -i -- 's|;user nobody|user nobody|g' $SERVER_CONFIG
	sed -i -- 's|;group nobody|group nogroup|g' $SERVER_CONFIG
	sed -i -- 's|;push "redirect-gateway def1 bypass-dhcp"|push "redirect-gateway def1 bypass-dhcp"|g' $SERVER_CONFIG
	sed -i -- 's|;push "dhcp-option|push "dhcp-option|g' $SERVER_CONFIG
	sed -i -- 's|;push "route 192.168.20.0 255.255.255.0"|push "route 192.168.20.0 255.255.255.0"|g' $SERVER_CONFIG
	sed -i -- "s|route 192.168.20.0 255.255.255.0|route $SUBNET_BEHIND_THE_SERVER|g" $SERVER_CONFIG
	sed -i -- "s|port 1194|port $LISTENING_PORT|g" $SERVER_CONFIG
	sed -i -- "s|cert server.crt|cert $COMMON_NAME.crt|g" $SERVER_CONFIG
	sed -i -- "s|key server.key|key $COMMON_NAME.key|g" $SERVER_CONFIG
	# step 8
	sed -i -- "s|#net.ipv4.ip_forward=1|net.ipv4.ip_forward=1|g" /etc/sysctl.conf
	sysctl -p
}

start_openvpn_server() {
	systemctl -f enable openvpn-server@server.service
	systemctl start openvpn-server@server.service
	systemctl status openvpn-server@server.service
}

prepare_base_conf() {
	BASE_CONFIG="/home/$SUDO_USER/client-configs/base.conf"
	rm -rf $BASE_CONFIG
	su - $SUDO_USER -c "mkdir -p /home/$SUDO_USER/client-configs/files"
	su - $SUDO_USER -c "cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf $BASE_CONFIG"
	sed -i -- "s|remote my-server-1 1194|remote $YOUR_SERVER_IP $LISTENING_PORT|g" $BASE_CONFIG
	sed -i -- "s|;user nobody|user nobody|g" $BASE_CONFIG
	sed -i -- "s|;group nobody|group nogroup|g" $BASE_CONFIG
	sed -i -- "s|ca ca.crt|;ca ca.crt|g" $BASE_CONFIG
	sed -i -- "s|cert client.crt|;cert client.crt|g" $BASE_CONFIG
	sed -i -- "s|key client.key|;key client.key|g" $BASE_CONFIG
	sed -i -- "s|tls-auth ta.key 1|;tls-auth ta.key 1|g" $BASE_CONFIG
	sed -i -- '/^cipher AES-256-CBC/a auth SHA256' $BASE_CONFIG
	sed -i -- 's|cipher AES-256-CBC|cipher AES-256-GCM|g' $BASE_CONFIG
	cat >> $BASE_CONFIG << "EOF"
key-direction 1

;1;script-security 2
;1;up /etc/openvpn/update-resolv-conf
;1;down /etc/openvpn/update-resolv-conf

;2;script-security 2
;2;up /etc/openvpn/update-systemd-resolved
;2;down /etc/openvpn/update-systemd-resolved
;2;down-pre
;2;dhcp-option DOMAIN-ROUTE .
EOF
	echo -e "$BASE_CONFIG now created successfully. \n"
}

make_client_ovpn_file() {
	KEY_DIR=/home/$SUDO_USER/client-configs/keys
	OUTPUT_DIR=/home/$SUDO_USER/client-configs/files
	BASE_CONFIG=/home/$SUDO_USER/client-configs/base.conf
 
cat ${BASE_CONFIG} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/$CLIENT_NAME.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/$CLIENT_NAME.key \
    <(echo -e '</key>\n<tls-crypt>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-crypt>') \
    > ${OUTPUT_DIR}/$CLIENT_NAME.ovpn

	chown $SUDO_USER:$SUDO_USER $OUTPUT_DIR/$CLIENT_NAME.ovpn
	chmod 644 $OUTPUT_DIR/$CLIENT_NAME.ovpn

	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
	echo -e "Congraduations !! client file $OUTPUT_DIR/$CLIENT_NAME.ovpn is ready. \n"
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
}

echo -e "This script will do some operations on your Ubuntu 22.04 machine (used as OpenVPN Server) \n"
echo -e "[0] Do nothing and Exit \n"
echo -e "[1] Install OpenVPN Server \n"
echo -e "[2] Generate Server Certificate Request (.req) and Private Key (.key) \n"
echo -e "[3] Copy Server files to right place \n"
echo -e "[4] Generate TLS crypt key (ta.key) \n"
echo -e "[5] Create subdirs for clients \n"
echo -e "[6] Generate Client Certificate Request (.req) and Private Key (.key) \n"
echo -e "[7] Copy Client files to right place \n"
echo -e "[8] Configure OpenVPN Server \n"
echo -e "[9] Start OpenVPN Server \n"
echo -e "[10] Prepare base.conf (template of clientXX.ovpn) \n"
echo -e "[11] Make Client .ovpn file \n"
read -p "Please Enter Your Choice : " choice
case $choice in
	1)
		install_openvpn_server
		;;
	2)
		generate_server_req_and_private_key
		;;
	3)
		copy_server_files_to_right_place
		;;
	4)
		generate_tls_crypt_key
		;;
	5)
		create_subdirs_for_clients
		;;
	6)
		generate_clients_req_and_private_key
		;;
	7)
		copy_client_files_to_right_place
		;;
	8)
		configure_openvpn_server
		;;
	9)
		start_openvpn_server
		;;
	10)
		prepare_base_conf
		;;
	11)
		make_client_ovpn_file
		;;
        0)
                say_goodbye
                exit 1
                ;;
        *) echo -e "Please Enter 0 to 11 \n"
esac
