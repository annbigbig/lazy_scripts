#!/bin/bash
# This script will install Modoboa on your Ubuntu 22.04 machine
# before you run this script , please specify some parameters here ;
# 
####################################################################################################################################################
YOUR_SSL_CERT_PATH="/etc/ssl/certs/certificate.crt"              # place your domain's SSL cert here , owner/group == root , permission == 0644
YOUR_SSL_KEY_PATH="/etc/ssl/private/mail.dq5rocks.com.key"       # place your domain's SSL cert key here , owner/group == root , permission == 0600
DOMAIN_NAME="dq5rocks.com"                                       # Your Domain name
FQDN_SERVER_NAME="mail.dq5rocks.com"                             # The FQDN of the mail server (this machine) , ex:  mail.<your-domain.com>
ADMIN_EMAIL_ADDRESS="admin@dq5rocks.com"                         # Your Admin e-mail address
DB_ROOT_PASSWORD="P@55w0rd"                                      # Your root password set for MariaDB
####################################################################################################################################################
# no need to setup below , script will know it and use it automatically for u 
WIRED_INTERFACE_NAME="$(ip link show | grep '2:' | cut -d ':' -f 2 | sed 's/^ *//g')"
MY_IP="$(/sbin/ifconfig $WIRED_INTERFACE_NAME | grep -v 'inet6' | grep 'inet' | tr -s ' ' | cut -d ' ' -f 3)"
####################################################################################################################################################
# useful links: 
# https://c-nergy.be/blog/?p=18611
# https://www.linuxbabe.com/mail-server/email-server-ubuntu-22-04-modoboa
# https://github.com/modoboa/modoboa-installer/issues/251
####################################################################################################################################################
#                            <<Tested on Ubuntu 22.04 Server Edition>>
####################################################################################################################################################

say_goodbye() {
        echo "see you next time"
}

install_modoboa() {
	apt-get update
	apt-get upgrade -y
	apt-get install -y git python3-virtualenv python3-pip
	cd /usr/local/src
	git clone https://github.com/modoboa/modoboa-installer
	cd modoboa-installer
	sudo ./run.py --stop-after-configfile-check $DOMAIN_NAME
	cp ./installer.cfg /root/installer.cfg.default
	INSTALL_CFG="/usr/local/src/modoboa-installer/installer.cfg"
	#sed -i -- "s|type = self-signed|type = letsencrypt|g" $INSTALL_CFG
	sed -i -- "s|type = self-signed|type = self-signed|g" $INSTALL_CFG
	sed -i -- "s|admin@example.com|$ADMIN_EMAIL_ADDRESS|g" $INSTALL_CFG
	sed -i -- "s|engine = postgres|engine = mysql|g" $INSTALL_CFG
	sed -i -- "s|charset = utf8|charset = utf8mb4|g" $INSTALL_CFG
	sed -i -- "s|collation = utf8_general_ci|collation = utf8mb4_unicode_ci|g" $INSTALL_CFG
	sed -i -- "s|^password =.*|password = $DB_ROOT_PASSWORD|g" $INSTALL_CFG

	# use FQDN as hostname
	hostnamectl set-hostname $FQDN_SERVER_NAME

	# make sure this host is called mail.$DOMAIN_NAME.com then fire command :
	sudo ./run.py --interactive $DOMAIN_NAME
	# same as above command but more verbose output during installation
	# sudo ./run.py --interactive --debug $DOMAIN_NAME

	# HINT: default modoboa login/password is admin/password
}	

replace_ssl_cert_and_key() {
	# i forgot to modify /etc/postfix/main.cf
	# smtpd_tls_cert_file = /etc/ssl/certs/certificate.crt
	# smtpd_tls_key_file = /etc/ssl/private/mail.dq5rocks.com.key

	# replace self-signed SSL cert and key with valid cert and key
	POSTFIX_SSL_CONF="/etc/postfix/main.cf"
	NGINX_SSL_CONF="/etc/nginx/sites-available/$FQDN_SERVER_NAME.conf"
	DOVECOT_SSL_CONF="/etc/dovecot/conf.d/10-ssl-keys.try"
	sed -i -- "s|/etc/ssl/certs/$FQDN_SERVER_NAME.cert|$YOUR_SSL_CERT_PATH|g" $POSTFIX_SSL_CONF
	sed -i -- "s|/etc/ssl/private/$FQDN_SERVER_NAME.key|$YOUR_SSL_KEY_PATH|g" $POSTFIX_SSL_CONF

	sed -i -- "s|/etc/ssl/certs/$FQDN_SERVER_NAME.cert|$YOUR_SSL_CERT_PATH|g" $NGINX_SSL_CONF
	sed -i -- "s|/etc/ssl/private/$FQDN_SERVER_NAME.key|$YOUR_SSL_KEY_PATH|g" $NGINX_SSL_CONF
	sudo mv $DOVECOT_SSL_CONF{,.original}
	sudo cat >> $DOVECOT_SSL_CONF << "EOF"
ssl_cert = <YOUR_SSL_CERT_PATH
ssl_key = <YOUR_SSL_KEY_PATH
EOF
	sed -i -- "s|YOUR_SSL_CERT_PATH|$YOUR_SSL_CERT_PATH|g" $DOVECOT_SSL_CONF
	sed -i -- "s|YOUR_SSL_KEY_PATH|$YOUR_SSL_KEY_PATH|g" $DOVECOT_SSL_CONF

	# restart postfix
	systemctl restart postfix.service

	# restart nginx
	systemctl restart nginx.service

	# restart dovecot
	systemctl restart dovecot.service
}

disable_greylist_and_policyd() {
	# backup main.cf
	POSTFIX_CONF="/etc/postfix/main.cf"
	cp $POSTFIX_CONF{,.original} 

	# Disable Greylisting
	sed -i -- "s|postscreen_pipelining_enable|#postscreen_pipelining_enable|g" $POSTFIX_CONF
	sed -i -- "s|postscreen_pipelining_action|#postscreen_pipelining_action|g" $POSTFIX_CONF
	sed -i -- "s|postscreen_non_smtp_command_enable|#postscreen_non_smtp_command_enable|g" $POSTFIX_CONF
	sed -i -- "s|postscreen_non_smtp_command_action|#postscreen_non_smtp_command_action|g" $POSTFIX_CONF
	sed -i -- "s|postscreen_bare_newline_enable|#postscreen_bare_newline_enable|g" $POSTFIX_CONF
	sed -i -- "s|postscreen_bare_newline_action|#postscreen_bare_newline_action|g" $POSTFIX_CONF

	# Disable Policyd
	sed -i -- "s|check_policy_service|#check_policy_service|g" $POSTFIX_CONF
	
	# Restart Postfix Service
	systemctl restart postfix.service
}

main(){
	install_modoboa
	replace_ssl_cert_and_key
	disable_greylist_and_policyd
}

echo -e "This script will install modoboa on your Ubuntu 22.04 machine \n"
echo -e "before that , please make sure your domain's SSL cert and key are placed in : \n"
echo -e "$YOUR_SSL_CERT_PATH \n"
echo -e "$YOUR_SSL_KEY_PATH \n"
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

