#!/bin/bash
# This script will install IKEv2 VPN Server on your Ubuntu 22.04 machine 
# before you run this script , please specify some parameters here ;
# 
#######################################################################################################################################
SUDOER_USER_MANUAL=""                                  # Write a sudoer username here , usually UID 1000 that user or leave it blank
YOUR_SERVER_IP="49.159.111.111"                        # Write Public IP of your IKEv2 VPN Server here
CERTIFICATE_LIFE_TIME="3650"                           # How long cerfiticate will be valid , 3650 means 10 years , that's good
# User Credentials , each line represent a user and his/her password , seperate with : (username:password)
read -r -d '' USER_CREDENTIALS << EOV
labasky:P@55w0rd
tony:tony55667788
lorra:lorra11223344
EOV
#######################################################################################################################################
# no need to setup below , script will know it and use it automatically for u 
WIRED_INTERFACE_NAME="$(ip link show | grep '2:' | cut -d ':' -f 2 | sed 's/^ *//g')"
SUDOER_USER_AUTO="$(cat /etc/passwd | grep 1000 | cut -d ':' -f 1 | tr -s ' ')"
[[ -z $SUDOER_USER_MANUAL ]] && SUDOER_USER="$SUDOER_USER_AUTO" || SUDOER_USER="$SUDOER_USER_MANUAL"
UNAME_M="$(/usr/bin/uname -m)"
#######################################################################################################################################
# useful links: 
# https://www.digitalocean.com/community/tutorials/how-to-set-up-an-ikev2-vpn-server-with-strongswan-on-ubuntu-22-04
# https://www.cnblogs.com/shaoyang0123/p/16477379.html
# https://devpress.csdn.net/linux/62e799e9907d7d59d1c8cfdc.html
# (fix TPM 2.0 - could not load "libtss2-tcti-tabrmd.so.0" problem)
#
# Need do extra command 'apt install linux-modules-extra-raspi' if you use Raspberry Pi
# for fix error message : (00[LIB] failed to load 1 critical plugin feature) when try to let StrongSwan Service start
# https://github.com/strongswan/strongswan/discussions/1210
#
# full tunnel / split tunnel ???
# https://www.watchguard.com/help/docs/help-center/en-US/Content/en-US/Fireware/mvpn/ikev2/mvpn_ikev2_config_edit.html#Split
# 
# vpn client settings on Ubuntu Desktop
# https://thesafety.us/vpn-setup-ikev2-ubuntu21
# https://docs.netgate.com/pfsense/en/latest/recipes/ipsec-mobile-ikev2-client-ubuntu.html
#
# subject certificate invalid ??? (don't let LIFETIME 100 years)
# https://lists.strongswan.org/pipermail/users/2012-October/003853.html
# https://userapps.support.sap.com/sap/support/knowledge/en/2922845
# 
# Received AUTHENTICATION_FAILED notify error
# https://github.com/strongswan/strongswan/discussions/1205
#
# Behind NAT
# https://forum.netgate.com/topic/126173/can-t-get-ipsec-to-connect-been-trying-for-days
#######################################################################################################################################
#                            <<Tested on Ubuntu 22.04 Server Edition>>
#######################################################################################################################################

say_goodbye() {
        echo "see you next time"
}

install_ikev2_server() {
	apt-get update
	apt-get install -y strongswan strongswan-pki libcharon-extra-plugins libcharon-extauth-plugins libstrongswan-extra-plugins
	apt-get install -y libtss2-tcti-tabrmd0
	if [ $UNAME_M == "armv7l" ]; then
		apt-get install -y linux-modules-extra-raspi
	fi
}

create_certificate_authority() {
	su - $SUDOER_USER -c "mkdir -p ~/pki/{cacerts,certs,private}"
	su - $SUDOER_USER -c "chmod 700 ~/pki"
	su - $SUDOER_USER -c "pki --gen --type rsa --size 4096 --outform pem > ~/pki/private/ca-key.pem"
	su - $SUDOER_USER -c "pki --self --ca --lifetime $CERTIFICATE_LIFE_TIME --in ~/pki/private/ca-key.pem \
		--type rsa --dn 'CN=VPN root CA' --outform pem > ~/pki/cacerts/ca-cert.pem"
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
	echo -e "Congraduations !! now 2 important files for IKEv2 Server is ready. \n"
	su - $SUDOER_USER -c "ls -al ~/pki/private/ca-key.pem"
	su - $SUDOER_USER -c "ls -al ~/pki/cacerts/ca-cert.pem"
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
}

generate_server_certficate() {
	su - $SUDOER_USER -c "pki --gen --type rsa --size 4096 --outform pem > ~/pki/private/server-key.pem"
	su - $SUDOER_USER -c "pki --pub --in ~/pki/private/server-key.pem --type rsa \
		| pki --issue --lifetime $CERTIFICATE_LIFE_TIME \
		        --cacert ~/pki/cacerts/ca-cert.pem \
		        --cakey ~/pki/private/ca-key.pem \
		        --dn 'CN=$YOUR_SERVER_IP' --san @$YOUR_SERVER_IP --san $YOUR_SERVER_IP \
			--flag serverAuth --flag ikeIntermediate --outform pem \
	         >  ~/pki/certs/server-cert.pem"
	sudo cp -r /home/$SUDOER_USER/pki/* /etc/ipsec.d/
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
	echo -e "Congraduations !! All of files for IKEv2 Server is ready. \n"
	sudo ls -aR /etc/ipsec.d/
	echo -e "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * \n"
}	

configuring_strongswan() {
	CONF_FILE="/etc/ipsec.conf"
	sudo mv $CONF_FILE{,.original}
	sudo cat >> $CONF_FILE << "EOF"
config setup
    charondebug="ike 1, knl 1, cfg 0"
    uniqueids=no

conn ikev2-vpn
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=yes
    forceencaps=yes
    dpdaction=clear
    dpddelay=300s
    rekey=no
    left=%any
    leftid=@YOUR_SERVER_IP
    leftcert=server-cert.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=10.10.10.0/24
    rightdns=8.8.8.8,8.8.4.4
    rightsendcert=never
    eap_identity=%identity
    ike=chacha20poly1305-sha512-curve25519-prfsha512,aes256gcm16-sha384-prfsha384-ecp384,aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024!
    esp=chacha20poly1305-sha512,aes256gcm16-ecp384,aes256-sha256,aes256-sha1,3des-sha1!
EOF
	sed -i -- "s|YOUR_SERVER_IP|$YOUR_SERVER_IP|g" $CONF_FILE
}

configuring_vpn_authentication() {
	PASSWORD_FILE="/etc/ipsec.secrets"
	sudo mv $PASSWORD_FILE{,.original}
	sudo cat >> $PASSWORD_FILE << "EOF"
: RSA "server-key.pem"
EOF
	# set password for users
	while read -r line; do
		_USERNAME="$(/bin/echo $line | cut -d ':' -f 1)"
		_PASSWORD="$(/bin/echo $line | cut -d ':' -f 2)"
  		echo "$_USERNAME : EAP \"$_PASSWORD\"" >> $PASSWORD_FILE
	done <<< "$USER_CREDENTIALS"

	# restart service
	sudo systemctl restart strongswan-starter
}

configuring_sysctl_conf() {
	SYSCTL_CONF="/etc/sysctl.conf"
	sudo cp $SYSCTL_CONF{,.original}
	# delete all these parameters first if they existed in /etc/sysctl.conf
	sed -i '/^net.ipv4.ip_forward/d' $SYSCTL_CONF
	sed -i '/^net.ipv4.conf.all.accept_redirects/d' $SYSCTL_CONF
	sed -i '/^net.ipv4.conf.all.send_redirects/d' $SYSCTL_CONF
	sed -i '/^net.ipv4.ip_no_pmtu_disc/d' $SYSCTL_CONF

	echo "net.ipv4.ip_forward = 1" >> $SYSCTL_CONF 
	echo "net.ipv4.conf.all.accept_redirects = 0" >> $SYSCTL_CONF 
	echo "net.ipv4.conf.all.send_redirects = 0" >> $SYSCTL_CONF 
	echo "net.ipv4.ip_no_pmtu_disc = 1" >> $SYSCTL_CONF 
	sysctl -p
}

configuring_firewall() {
	echo -e "You may think that I need to configure firewall to let IKEv2 VPN Server function properly, \n"
	echo -e "about that part I've done at 'U00-optimize_ubuntu.sh'\n"
	echo -e "inside function 'firewall_setting' \n"
	echo -e "run command : sudo cat /etc/network/if-up.d/firewall \n"
	echo -e "everything is arranged well , no need to do anything else. \n"
	echo -e "關於IKEv2 VPN Server上應該要配置的iptables防火牆設定 \n"
	echo -e "在U00-optimize_ubuntu.sh這支Shell Script的firewall_setting函式裡 \n"
	echo -e "都已經設定好了，在這裡無須再做任何額外配置. \n"
}

main() {
	install_ikev2_server
	create_certificate_authority
	generate_server_certficate
	configuring_strongswan
	configuring_vpn_authentication
	configuring_sysctl_conf
	configuring_firewall
}

echo -e "This script will install IKEv2 VPN Server for you"
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
