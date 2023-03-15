#!/bin/bash
#
# This script will install nginx web server with php support from source
# and deploy phpmyadmin/wordpress/cacti on this web server 
# before u run this script please confirm these parameters :
#
###########################################  <<Tested on Ubuntu Mate 20.04 Desktop Edition>>  ###############
#
SERVER_FQDN="www.dq5rocks.com"
ENABLE_HTTPS="yes"
GENERATE_SELF_SIGNED_SSL_CERTIFICATE="yes"
SELF_SIGNED_SSL_C="TW"
SELF_SIGNED_SSL_ST="New Taipei"
SELF_SIGNED_SSL_L="Tamsui"
SELF_SIGNED_SSL_O="Tong-Shing, Inc."
SELF_SIGNED_SSL_CN="*.dq5rocks.com"
#SESSION_SAVE_PATH="127.0.0.1:11211"
SESSION_SAVE_PATH="192.168.0.91:11211,192.168.0.92:11211"
#
#############################################################################################################
# no need to set these two variables , script will get correct values for you
WIRED_INTERFACE_NAME="$(ip link show | grep '2:' | cut -d ':' -f 2 | sed 's/^ *//g')"
MY_IP="$(/sbin/ifconfig $WIRED_INTERFACE_NAME | grep -v 'inet6' | grep 'inet' | tr -s ' ' | cut -d ' ' -f 3)"
OPENSSL_VERSION="$(/usr/bin/openssl version -a | grep -i openssl | cut -d ' ' -f 2 | head -n 1)"
#
#############################################################################################################
###     use this command to generate your own blowfish secret then fill in parameter values below 
###     cat /dev/urandom | tr -dc 'a-zA-Z0-9#@!' | fold -w ${1:-32} | head -n 1
DEPLOY_PHPMYADMIN="yes"
PHPMYADMIN_BLOWFISH_SECRET="Sn6b1p10UyQsUGwhMIPmkJn@E0BcKu2Q"
PHPMYADMIN_DB_HOST="127.0.0.1"
PHPMYADMIN_DB_PORT="3306"
PHPMYADMIN_CONTROL_USER="pmauser"
PHPMYADMIN_CONTROL_PASS="pmapassword"
#
############################################################################################################
#
DEPLOY_WORDPRESS="yes"
WORDPRESS_FQDN="blog.dq5rocks.com"
WORDPRESS_DB_HOST="127.0.0.1:3306"
WORDPRESS_DB_NAME="wpdb"
WORDPRESS_DB_USER="wpuser"
WORDPRESS_DB_PASS="wppassword"
###     use this command to generate your own salt hash then fill in parameter values below 
###     cat /dev/urandom | tr -dc 'a-zA-Z0-9#@!' | fold -w ${1:-64} | head -n 1
###     i tried use command below either but it generate too many SPECIAL CHARACTERS i cannot escape in sed command :-(
###     wget -O salt.txt https://api.wordpress.org/secret-key/1.1/salt/
WORDPRESS_AUTH_KEY='80Bg9OvoS3Icv2m9bQvV34uVw#1Uzt1hSgNzO4jdDBEDgthTiOOEdx2vPTtRwtQ@'
WORDPRESS_SECURE_AUTH_KEY='BHlms@Y7B!Ku7DeuNp!p1HGXR0jY7HIrnx1ZUUIwWyP5NqshTKchBigg2EsYDAcl'
WORDPRESS_LOGGED_IN_KEY='y1Q6V!gNQiCbaJAzKnY!GuXLdpWJrZgGQBxAIlOUDvc8ZzZz#UlJBSR3HQw@XLto'
WORDPRESS_NONCE_KEY='iZKaPGcfwwoN#r8H7a7P@L3VEeLY3GAPIvO71pWHXaLWJOx!@PF0vSAreifMfkdE'
WORDPRESS_AUTH_SALT='P2kQkCBfs6RxhKHgsnPPcPq15yNi7kzwTX45b@B2D@FCDZmFq5PW74!Pd!ci5Jup'
WORDPRESS_SECURE_AUTH_SALT='8X#ueb166nsQu@s442RE!KZUBRhEdAHkeQmbPyIpbP1nIDnWxT1fR5FT4cdWN1@o'
WORDPRESS_LOGGED_IN_SALT='3@kPwEApF8tNBfgRZpxR9O!uGPxCxKS#@uTlqs6tm6zRufYgcgz1wxz4axFvIXNI'
WORDPRESS_NONCE_SALT='g7t!b2X3zwDM!adKV0!pvkbjhqO09Ab3!7GxGjOqLiCTCm7g!d0vootIbLCJmjK8'
#
############################################################################################################
#
DEPLOY_CACTI="yes"
CACTI_DB_HOST="127.0.0.1"
CACTI_DB_PORT="3306"
CACTI_DB_NAME="cacti_db"
CACTI_DB_USER="cactiuser"
CACTI_DB_PASS="cactipass"
#
SNMPTRAPD_COMMUNITY_NAME="duruduru"
SNMPTRAPD_LISTENING_IP="$MY_IP"
SNMPTRAPD_LISTENING_PORT="162"
#
############################################################################################################
# and please edit nginx configuration inside this function
# your settings are different with me definitely
# modify it to suite your needs :
#
############################################################################################################
edit_nginx_config(){

        # create nginx.conf
        cat > /usr/local/nginx-1.23.3/conf/nginx.conf << "EOF"
user nginx nginx;
worker_processes 2;
pid run/nginx.pid;

events {
  worker_connections 1024;
  # multi_accept on;
}

http {
# Basic Settings
  sendfile on;
  tcp_nopush on;
  tcp_nodelay on;
  keepalive_timeout 65;
  types_hash_max_size 2048;
  # server_tokens off;

  server_names_hash_bucket_size 128; # this seems to be required for some vhosts
  # server_name_in_redirect off;

  include mime.types;
  include proxy.conf;
  include fastcgi.conf;
  index index.html index.htm index.php;
  default_type application/octet-stream;

# Logging Settings
log_format gzip '$remote_addr - $remote_user [$time_local]  '
          '"$request" $status $bytes_sent '
          '"$http_referer" "$http_user_agent" "$gzip_ratio"';

    access_log logs/access.log gzip buffer=32k;
    error_log logs/error.log notice;

# Gzip Settings
    gzip on;
    gzip_disable "msie6";

    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;

# Virtual Host Configs
    include /usr/local/nginx/conf.d/*.conf;
}
EOF
        # create fastcgi.conf
        rm -rf /usr/local/nginx-1.23.3/conf/fastcgi.conf
        cat > /usr/local/nginx-1.23.3/conf/fastcgi.conf << "EOF"
fastcgi_param  SCRIPT_FILENAME    $document_root$fastcgi_script_name;
fastcgi_param  QUERY_STRING       $query_string;
fastcgi_param  REQUEST_METHOD     $request_method;
fastcgi_param  CONTENT_TYPE       $content_type;
fastcgi_param  CONTENT_LENGTH     $content_length;
fastcgi_param  SCRIPT_NAME        $fastcgi_script_name;
fastcgi_param  REQUEST_URI        $request_uri;
fastcgi_param  DOCUMENT_URI       $document_uri;
fastcgi_param  DOCUMENT_ROOT      $document_root;
fastcgi_param  SERVER_PROTOCOL    $server_protocol;
fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
fastcgi_param  SERVER_SOFTWARE    nginx/$nginx_version;
fastcgi_param  REMOTE_ADDR        $remote_addr;
fastcgi_param  REMOTE_PORT        $remote_port;
fastcgi_param  SERVER_ADDR        $server_addr;
fastcgi_param  SERVER_PORT        $server_port;
fastcgi_param  SERVER_NAME        $server_name;

fastcgi_index  index.php;

fastcgi_param  REDIRECT_STATUS    200;
EOF
        # create proxy.conf
        rm -rf /usr/local/nginx-1.23.3/conf/proxy.conf
        cat > /usr/local/nginx-1.23.3/conf/proxy.conf << "EOF"
proxy_redirect          off;
proxy_set_header        Host            $host;
proxy_set_header        X-Real-IP       $remote_addr;
proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
client_max_body_size    10m;
client_body_buffer_size 128k;
proxy_connect_timeout   90;
proxy_send_timeout      90;
proxy_read_timeout      90;
proxy_buffers           32 4k;
EOF

        if [ "$ENABLE_HTTPS" == "yes" ] ; then
        # create self-signed.conf
	rm -rf /usr/local/nginx-1.23.3/conf/self-signed.conf
        cat > /usr/local/nginx-1.23.3/conf/self-signed.conf << "EOF"
ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
EOF

        # create ssl-params.conf
	rm -rf /usr/local/nginx-1.23.3/conf/ssl-params.conf
	cat > /usr/local/nginx-1.23.3/conf/ssl-params.conf << "EOF"
# from https://cipherli.st/
# and https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html

ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
ssl_prefer_server_ciphers on;
ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
ssl_ecdh_curve secp384r1;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling off;
ssl_stapling_verify off;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
# Disable preloading HSTS for now.  You can use the commented out header line that includes
# the "preload" directive if you understand the implications.
#add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
add_header Strict-Transport-Security "max-age=63072000; includeSubdomains";
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;

ssl_dhparam /etc/ssl/certs/dhparam.pem;
EOF
        fi

        # create localhost.conf for 'localhost'
        cat > /usr/local/nginx-1.23.3/conf.d/localhost.conf << "EOF"
server {
         listen 127.0.0.1:80;
         server_name localhost;
         root /var/www/localhost;

         # Logging --
         access_log  logs/localhost.access.log;
         error_log  logs/localhost.error.log notice;

         # serve static files directly
         location ~* ^.+.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt)$ {
               access_log        off;
               expires           max;
         }

         location ~ \.php$ {
               try_files $uri $uri/ =404;
               fastcgi_pass unix:/usr/local/php/var/run/php-fpm.sock;
         }
}
EOF

        # create $SERVER_FQDN.conf , this is main configuration of your website
        cat > /usr/local/nginx-1.23.3/conf.d/$SERVER_FQDN.conf << "EOF"
server {
         listen 80 default_server;
         server_name SERVER_FQDN;
EOF

if [ "$ENABLE_HTTPS" == "yes" ] ; then
        cat >> /usr/local/nginx-1.23.3/conf.d/$SERVER_FQDN.conf << "EOF"
         return 301 https://$server_name$request_uri;
}

server {
         listen 443 ssl default_server;
         server_name SERVER_FQDN;
         include self-signed.conf;
         include ssl-params.conf;
EOF
fi
        cat >> /usr/local/nginx-1.23.3/conf.d/$SERVER_FQDN.conf << "EOF" 
         root /var/www/SERVER_FQDN;

         # Logging --
         access_log  logs/SERVER_FQDN.access.log;
         error_log  logs/SERVER_FQDN.error.log notice;

         # serve static files directly
         location ~* ^.+.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt)$ {
               access_log        off;
               expires           max;
         }

         location ~ \.php$ {
               try_files $uri $uri/ =404;
               fastcgi_pass unix:/usr/local/php/var/run/php-fpm.sock;
         }

         location ~ \.(jsp|do|action)?$ {
               proxy_pass http://127.0.0.1:8080;
         }

         # i have a webapp called test008 deployed on backend tomcat
         location ^~ /api/ {
               rewrite ^/api/(.*) /test008/$1  break;
               proxy_pass         http://127.0.0.1:8080;
         }

         # i have a webapp called janjan deployed on backend tomcat
         location ^~ /janjan/ {
               proxy_pass         http://127.0.0.1:8080;
         }

}
EOF

        sed -i -- "s|SERVER_FQDN|$SERVER_FQDN|g" /usr/local/nginx-1.23.3/conf.d/$SERVER_FQDN.conf

#####
        # create $WORDPRESS_FQDN.conf, this is configuration file for wordpress blog.
        cat > /usr/local/nginx-1.23.3/conf.d/$WORDPRESS_FQDN.conf << "EOF"
server {
         listen 80;
         server_name WORDPRESS_FQDN;
EOF

if [ "$ENABLE_HTTPS" == "yes" ] ; then
        cat >> /usr/local/nginx-1.23.3/conf.d/$WORDPRESS_FQDN.conf << "EOF"
         return 301 https://$server_name$request_uri;
}

server {
         listen 443 ssl;
         server_name WORDPRESS_FQDN;
         include self-signed.conf;
         include ssl-params.conf;
EOF
fi

	cat >> /usr/local/nginx-1.23.3/conf.d/$WORDPRESS_FQDN.conf << "EOF"
         root /var/www/WORDPRESS_FQDN;

         # Logging --
         access_log  logs/WORDPRESS_FQDN.access.log;
         error_log  logs/WORDPRESS_FQDN.error.log notice;

         # serve static files directly
         location ~* ^.+.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt)$ {
               access_log        off;
               expires           max;
         }

         location ~ \.php$ {
               try_files $uri $uri/ =404;
               fastcgi_pass unix:/usr/local/php/var/run/php-fpm.sock;
         }
}
EOF
	sed -i -- "s|WORDPRESS_FQDN|$WORDPRESS_FQDN|g" /usr/local/nginx-1.23.3/conf.d/$WORDPRESS_FQDN.conf
#####

        # test nginx.conf to see if syntax error exist
        CONFIG_SYNTAX_ERR="$(sbin/nginx -t -c conf/nginx.conf 2>&1 | grep 'test failed' | wc -l)"
        [ "$CONFIG_SYNTAX_ERR" -eq 1 ] && echo 'SYNTAX ERROR in nginx.conf' || echo 'nginx.conf is GOOD'


        chown -R nginx:nginx /usr/local/nginx-1.23.3
}

#####################################################################################################
# *** SPECIAL THANKS ***
# All of the commands used here were inspired by these articles : 
#
# https://support.rackspace.com/how-to/install-nginx-and-php-fpm-running-on-unix-file-sockets/
# https://www.sitepoint.com/setting-up-php-behind-nginx-with-fastcgi/
# https://www.nginx.com/blog/creating-nginx-rewrite-rules/
# https://www.scalescale.com/tips/nginx/nginx-location-directive/
# http://www.linuxfromscratch.org/blfs/view/svn/general/php.html
# https://ivopetkov.com/b/install-php-and-apache-from-source/
# https://ma.ttias.be/apache-2-4-proxypass-for-php-taking-precedence-over-filesfilesmatch-in-htaccess/
# https://github.com/phpbrew/phpbrew/issues/861
# https://www.digitalocean.com/community/tutorials/how-to-install-an-ssl-certificate-from-a-commercial-certificate-authority
# https://www.digitalocean.com/community/tutorials/how-to-create-a-self-signed-ssl-certificate-for-nginx-in-ubuntu-16-04
# https://unix.stackexchange.com/questions/104171/create-ssl-certificate-non-interactively
# https://stackoverflow.com/questions/23929235/multi-line-string-with-extra-space-preserved-indentation
# https://gist.github.com/earthgecko/3089509
# https://www.linode.com/docs/security/ssl/install-lets-encrypt-to-create-ssl-certificates/
# https://coderwall.com/p/b443ng/generating-a-self-signed-wildcard-certificate
# https://forum.directadmin.com/threads/how-to-build-php-with-proper-imap-support.41879/
# https://docs.bitnami.com/aws/apps/wordpress/configuration/install-modules-php/#php7
# https://linuxize.com/post/how-to-install-gcc-compiler-on-ubuntu-18-04/
# https://askubuntu.com/questions/1140183/install-gcc-9-on-ubuntu-18-04
# https://askubuntu.com/questions/43345/how-to-remove-a-repository
# https://launchpad.net/~jonathonf/+archive/ubuntu/gcc
# https://askubuntu.com/questions/732985/force-update-from-unsigned-repository
# https://ubuntu.pkgs.org/18.04/ubuntu-universe-amd64/gcc-5_5.5.0-12ubuntu1_amd64.deb.html
# https://linuxconfig.org/how-to-list-and-remove-ppa-repository-on-ubuntu-18-04-bionic-beaver-linux
# https://gist.github.com/application2000/73fd6f4bf1be6600a2cf9f56315a2d91
# https://askubuntu.com/questions/1166599/install-gcc-5-under-ubuntu-19-04
# https://medium.com/make-it-easy/how-to-install-cacti-on-ubuntu-20-04-b6290c2b3158
# https://www.tecmint.com/install-different-php-versions-in-ubuntu/
# https://mitblog.pixnet.net/blog/post/43827108-%5Bmysql%5D-%E7%82%BA%E4%BB%80%E9%BA%BC-mysql-%E8%A6%81%E8%A8%AD%E5%AE%9A%E7%94%A8-utf8mb4-%E7%B7%A8%E7%A2%BC-utf8mb4_
# https://matthung0807.blogspot.com/2018/05/mysql-schemacollation.html
# https://github.com/php/php-src/blob/PHP-7.4/UPGRADING#L761-L770
# https://www.howtoforge.com/tutorial/how-to-compile-and-install-php-7.4-on-ubuntu-18-04/
# https://github.com/Cacti/cacti/issues/2831
# https://zerossl.com/help/installation/nginx/
# https://itslinuxfoss.com/install-openssl-ubuntu-22-04/
# https://blog.csdn.net/u012628581/article/details/91805295
# https://gitlab.com/gitlab-org/gitlab/-/issues/376755
# https://gist.github.com/rizalp/b5cc046bf271a2561339bea50b3505f5?permalink_comment_id=3146014
#####################

say_goodbye() {
	echo "goodbye everyone"
}

remove_previous_install() {
        # remove nginx if it has been installed
        if [ -f /lib/systemd/system/nginx.service ]; then
             # stop/disable service
             systemctl disable nginx.service
             systemctl stop nginx.service
             # try to remove binary package
             apt-get purge -y nginx* libnginx* fcgiwrap
             apt autoremove -y
             # try to remove source installation
             rm -rf /usr/local/nginx*
        fi

        # remove apache2 if it has been installed
        if [ -d /lib/systemd/system/apache2.service.d ] || [ -f /lib/systemd/system/apache2.service ]; then
             # stop/disable service
             systemctl disable apache2.service
             systemctl stop apache2.service
             # try to remove binary package
             apt-get purge -y apache2* libaprutil*
             apt-get purge -y libapache2* libmcrypt* php8.2* php8* php7.4* php7* php*
             apt autoremove -y
             rm -rf /var/lib/apache2/
             rm -rf /var/lib/php/
             # try to remove source installation
             rm -rf /usr/local/apache2
             rm -rf /usr/local/apache-2*
        fi

        # remove php-fpm if it has been installed
        if [ -f /lib/systemd/system/php7.4-fpm.service ]; then
             # stop/disable service
             systemctl disable php7.4-fpm.service
             systemctl stop php7.4-fpm.service
        elif [ -f /lib/systemd/system/php8.2-fpm.service ]; then
             # stop/disable service
             systemctl disable php8.2-fpm.service
             systemctl stop php8.2-fpm.service
	fi
             # try to remove binary package
	     apt-get purge -y php8.2* php8* php7.4* php7* php*
             apt autoremove -y
             rm -rf /etc/php/
             rm -rf /var/lib/php/
             # try to remove source installation
             rm -rf /usr/local/php
             rm -rf /usr/local/php-*
}

create_self_signed_ssl_cert_and_key() {
        [ "$GENERATE_SELF_SIGNED_SSL_CERTIFICATE" != "yes" ] && echo "no self-signed ssl cert will be generated" && return || echo "ready to generate self-signed ssl cert"
	###/usr/bin/openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt
        #
        #-----
        #Country Name (2 letter code) [AU]:TW
        #State or Province Name (full name) [Some-State]:New Taipei
        #Locality Name (eg, city) []:Tamsui
        #Organization Name (eg, company) [Internet Widgits Pty Ltd]:Tong-Shing, Inc.
        #Organizational Unit Name (eg, section) []:Development Department
        #Common Name (e.g. server FQDN or YOUR name) []:www.dq5rocks.com
        #Email Address []:annbigbig@gmail.com
        #-----
        /usr/bin/openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
                         -subj "/C=$SELF_SIGNED_SSL_C/ST=$SELF_SIGNED_SSL_ST/L=$SELF_SIGNED_SSL_L/O=$SELF_SIGNED_SSL_O/CN=$SELF_SIGNED_SSL_CN" \
                         -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt
        /usr/bin/openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
}

install_prerequisite() {
        # nginx will require these
        apt-get update
        apt-get install -y libtool
        # php-fpm will requre these
        apt-get install -y libldap2-dev libtool-bin libzip-dev lbzip2 libxml2 libxml2-dev re2c libreadline-dev libpcre3 libpcre3-dev
        apt-get install -y libbz2-dev libjpeg-dev libxpm-dev libgmp-dev libgmp3-dev libpspell-dev librecode-dev
        apt-get install -y libcurl4 libcurl4-openssl-dev pkg-config libssl-dev libgdbm-dev libpng-dev libmcrypt-dev
        apt-get install -y libpam0g-dev libkrb5-dev curl libdb-dev libdb++-dev libdb5.3++-dev libpng-dev 
	apt-get install -y sqlite3 libsqlite3-dev libonig-dev
	#
	apt-get install -y libcurl3-gnutls
	apt-get install -y libmariadb-dev* libdb-dev libdb5.3
	# for php --with-imap
        apt-get install -y libc-client2007e libc-client2007e-dev
        apt-get install -y libglib2.0-dev libfcgi-dev libfcgi0ldbl libjpeg62 libjpeg62-dev
	# php 8.2.x require this
	apt-get install -y libsystemd0 libsystemd-dev
        # php-memcached require these
        apt-get install -y git pkg-config build-essential autoconf
	apt-get install -y libmemcached-dev libmemcached11
	# imap-2007 may require this for compile it from source , package libssl1.1 is not existed in Ubuntu 22.04 apt repo
	apt-get install -y libssl1.1 libssl-dev
        # php snmp module require these
        apt-get install -y libsnmp-base libsnmp-dev
        if [ "$DEPLOY_CACTI" == "yes" ] ; then
            # cacti will require these
            apt-get install -y snmp snmpd snmptt snmptrapd snmp-mibs-downloader rrdtool libdbd-mysql-perl libnet-ip-perl
        fi

        # make a symbolic link for curl header files
        if [ ! -e "/usr/include/curl" ] && [ -e "/usr/include/x86_64-linux-gnu/curl" ]; then
               ln -s /usr/include/x86_64-linux-gnu/curl /usr/include/curl
        fi
}

configure_snmpd_service(){
	# backup config file first
	tar -zcvf /etc/snmp/snmp-config.tar.gz /etc/snmp/snmp*.*

	# modify snmpd.conf then start snmpd service
        [ "$DEPLOY_CACTI" != "yes" ] && echo "skip configuring snmpd" && return || echo "configure snmpd service"
	sed -i -- 's|agentaddress  127.0.0.1,\[::1\]|agentaddress  127.0.0.1:161|g' /etc/snmp/snmpd.conf
        sed -i -- 's|^view   systemonly  included   .1.3.6.1.2.1.1$|view   systemonly  included   .1.3.6.1.2.1|g' /etc/snmp/snmpd.conf
        systemctl restart snmpd.service

	# modify snmptrapd.conf then start snmptrad service
        cat >> /etc/snmp/snmptrapd.conf << "EOF"
authCommunity log SNMPTRAPD_COMMUNITY_NAME
snmpTrapdAddr udp:SNMPTRAPD_LISTENING_IP:SNMPTRAPD_LISTENING_PORT
traphandle default /usr/sbin/snmptthandler
disableAuthorization yes
EOF
	sed -i -- "s|SNMPTRAPD_COMMUNITY_NAME|$SNMPTRAPD_COMMUNITY_NAME|g" /etc/snmp/snmptrapd.conf
	sed -i -- "s|SNMPTRAPD_LISTENING_IP|$SNMPTRAPD_LISTENING_IP|g" /etc/snmp/snmptrapd.conf
	sed -i -- "s|SNMPTRAPD_LISTENING_PORT|$SNMPTRAPD_LISTENING_PORT|g" /etc/snmp/snmptrapd.conf
	systemctl restart snmptrapd.service

	# modify snmptt.ini then start snmptt service
	sed -i -- "s|^mysql_dbi_enable = 0$|mysql_dbi_enable = 1|g" /etc/snmp/snmptt.ini
	sed -i -- "s|^mysql_dbi_host = localhost$|mysql_dbi_host = $CACTI_DB_HOST|g" /etc/snmp/snmptt.ini
	sed -i -- "s|^mysql_dbi_port = 3306$|mysql_dbi_port = $CACTI_DB_PORT|g" /etc/snmp/snmptt.ini
	sed -i -- "s|^mysql_dbi_database = snmptt$|mysql_dbi_database = $CACTI_DB_NAME|g" /etc/snmp/snmptt.ini
	sed -i -- "s|^mysql_dbi_username = snmpttuser$|mysql_dbi_username = $CACTI_DB_USER|g" /etc/snmp/snmptt.ini
	sed -i -- "s|^mysql_dbi_password = password$|mysql_dbi_password = $CACTI_DB_PASS|g" /etc/snmp/snmptt.ini
	sed -i -- "s|^mysql_dbi_table = snmptt$|mysql_dbi_table = plugin_camm_snmptt|g" /etc/snmp/snmptt.ini
	sed -i -- "s|^mysql_dbi_table_unknown = snmptt_unknown$|mysql_dbi_table_unknown = plugin_camm_snmptt_unk|g" /etc/snmp/snmptt.ini
	sed -i -- "s|^mysql_dbi_table_statistics =|mysql_dbi_table_statistics = plugin_camm_snmptt_stat|g" /etc/snmp/snmptt.ini
	systemctl restart snmptt.service
}

install_nginx() {

        # create necessary user and group
        groupadd -g 160 nginx
        useradd -u 160 -d /var/www -g nginx -s /bin/false nginx

        # create directories
        mkdir -p /var/www

        # change currently working directory
        cd /usr/local/src

        # remove previously downloaded tar.gz and their extracted folders
        rm -rf ./nginx-*
        rm -rf ./openssl-*
        rm -rf ./pcre-*
        rm -rf ./zlib-*

        # download the source tar.gz then verify their integrity
        wget http://nginx.org/download/nginx-1.23.3.tar.gz
        wget http://nginx.org/download/nginx-1.23.3.tar.gz.asc
        PUBLIC_KEY_1="$(gpg nginx-1.23.3.tar.gz.asc 2>&1 | grep -E -i 'rsa|dsa' | tr -s ' ' | rev | cut -d ' ' -f 1 | rev)"
        IMPORT_KEY_RESULT_1="$(gpg --keyserver keyserver.ubuntu.com --recv-key $PUBLIC_KEY_1 2>&1 | grep 'thresh@nginx.com' | wc -l)"
        VERIFY_SIGNATURE_RESULT_1="$(gpg ./nginx-1.23.3.tar.gz.asc 2>&1 | tr -s ' ' | grep '13C8 2A63 B603 5761 56E3 0A4E A0EA 981B 66B0 D967' | wc -l)"
        [ "$IMPORT_KEY_RESULT_1" -gt 0 ] && echo "pubkey $PUBLIC_KEY_1 imported successfuly" ||  exit 2
        [ "$VERIFY_SIGNATURE_RESULT_1" -gt 0 ] && echo "verify signature successfully" || exit 2

        wget https://www.openssl.org/source/openssl-1.1.1t.tar.gz
        wget https://www.openssl.org/source/openssl-1.1.1t.tar.gz.sha256
        SHA256SUM="$(cat ./openssl-1.1.1t.tar.gz.sha256)"
        SHA256SUM_COMPUTE="$(sha256sum ./openssl-1.1.1t.tar.gz | cut -d ' ' -f 1)"
        [ "$SHA256SUM" == "$SHA256SUM_COMPUTE" ] && echo "openssl sha256sum matched." || exit 2

	wget https://sourceforge.net/projects/pcre/files/pcre/8.45/pcre-8.45.tar.gz
	wget https://sourceforge.net/projects/pcre/files/pcre/8.45/pcre-8.45.tar.gz.sig
        PUBLIC_KEY_2="$(gpg ./pcre-8.45.tar.gz.sig 2>&1 | grep -E -i 'rsa|dsa' | tr -s ' ' | rev | cut -d ' ' -f 1 | rev)"
	IMPORT_KEY_RESULT_2="$(gpg --keyserver keyserver.ubuntu.com --recv-key $PUBLIC_KEY_2 2>&1 | grep 'Philip.Hazel@gmail.com' | wc -l)"
        VERIFY_SIGNATURE_RESULT_2="$(gpg ./pcre-8.45.tar.gz.sig 2>&1 | tr -s ' ' | grep '45F6 8D54 BBE2 3FB3 039B 46E5 9766 E084 FB0F 43D8' | wc -l)"
        [ "$IMPORT_KEY_RESULT_2" -gt 0 ] && echo "pubkey $PUBLIC_KEY_2 imported successfuly" || exit 2
        [ "$VERIFY_SIGNATURE_RESULT_2" -gt 0 ] && echo "verify signature successfully" || exit 2

        wget http://zlib.net/zlib-1.2.13.tar.gz
        wget http://zlib.net/zlib-1.2.13.tar.gz.asc
        PUBLIC_KEY_3="$(gpg ./zlib-1.2.13.tar.gz.asc 2>&1 | grep -E -i 'rsa|dsa' | tr -s ' ' | rev | cut -d ' ' -f 1 | rev)"
        IMPORT_KEY_RESULT_3="$(gpg --keyserver keyserver.ubuntu.com --recv-key $PUBLIC_KEY_3 2>&1 | grep 'madler@alumni.caltech.edu' | wc -l)"
        VERIFY_SIGNATURE_RESULT_3="$(gpg ./zlib-1.2.13.tar.gz.asc 2>&1 | tr -s ' ' | grep '5ED4 6A67 21D3 6558 7791 E2AA 783F CD8E 58BC AFBA' | wc -l)"
        [ "$IMPORT_KEY_RESULT_3" -gt 0 ] && echo "pubkey $PUBLIC_KEY_3 imported successfuly" || exit 2
        [ "$VERIFY_SIGNATURE_RESULT_3" -gt 0 ] && echo "verify signature successfully" || exit 2

        # extract all of tar.gz files and configure nginx
        tar -zxvf ./nginx-1.23.3.tar.gz
        tar -zxvf ./openssl-1.1.1t.tar.gz
        tar -zxvf ./pcre-8.45.tar.gz
        tar -zxvf ./zlib-1.2.13.tar.gz
        rm -rf *.tar.gz*

        # change directories owner and group
        chown -R root:root ./nginx-1.23.3
        chown -R root:root ./openssl-1.1.1t
        chown -R root:root ./pcre-8.45
        chown -R root:root ./zlib-1.2.13

        # configure then make then install
        cd ./nginx-1.23.3
	./configure --prefix=/usr/local/nginx-1.23.3 \
                    --user=nginx \
                    --group=nginx \
                    --with-http_v2_module \
                    --with-http_ssl_module \
                    --with-pcre=/usr/local/src/pcre-8.45 \
                    --with-zlib=/usr/local/src/zlib-1.2.13 \
                    --with-openssl=/usr/local/src/openssl-1.1.1t \
                    --with-http_stub_status_module

        make
        make install

        # remove previously downloaded tar.gz and their extracted folders
	cd /usr/local/src
        rm -rf ./nginx-*
        rm -rf ./openssl-*
        rm -rf ./pcre-*
        rm -rf ./zlib-*

        # backup default nginx.conf
        if [ -f /usr/local/nginx-1.23.3/conf/nginx.conf.default ]; then
           rm -rf /usr/local/nginx-1.23.3/conf/nginx.conf
        else
           mv /usr/local/nginx-1.23.3/conf/nginx.conf /usr/local/nginx-1.23.3/conf/nginx.conf.default
        fi

        # create sub-directories
        mkdir /usr/local/nginx-1.23.3/conf.d/
        mkdir /usr/local/nginx-1.23.3/run/

        # create systemd unit file for nginx.service
        cat > /lib/systemd/system/nginx.service << "EOF"
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/usr/local/nginx/run/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

        # you need this file for fixing this bug
        # https://bugs.launchpad.net/ubuntu/+source/nginx/+bug/1581864
        mkdir /lib/systemd/system/nginx.service.d
        cat > /lib/systemd/system/nginx.service.d/override.conf << "EOF"
[Service]
ExecStartPost=/bin/sleep 0.1
EOF

        # setup logrotate
cat > /etc/logrotate.d/nginx << EOF
/usr/local/nginx/logs/*.log {
        weekly
        rotate 12
        compress
        delaycompress
        missingok
        notifempty
        create 644 nginx nginx
}
EOF

        # change files/directories onwer and group
        chown root:root /lib/systemd/system/nginx.service
        chown root:root /etc/logrotate.d/nginx 
        chown -R root:root /var/www
}

create_some_webpages(){

        # create index.html for localhost
        mkdir -p /var/www/localhost
        cat > /var/www/localhost/index.html << "EOF"
<!DOCTYPE html>
<html>
<body>

<h1>localhost</h1>
<p>Hello World!</p>

</body>
</html>
EOF

        # create info.php for localhost
        cat > /var/www/localhost/info.php << "EOF"
<?php
session_start();
echo session_id();
phpinfo();
?>
EOF

        # create index.html for $SERVER_FQDN
        mkdir -p /var/www/$SERVER_FQDN
        cat > /var/www/$SERVER_FQDN/index.html << "EOF"
<!DOCTYPE html>
<html>
<body>

<h1>SERVER_FQDN</h1>
<h2>HOSTNAME</h2>
<p>Hello World!</p>

</body>
</html>
EOF
        sed -i -- "s|HOSTNAME|$HOSTNAME|g" /var/www/$SERVER_FQDN/index.html   
        sed -i -- "s|SERVER_FQDN|$SERVER_FQDN|g" /var/www/$SERVER_FQDN/index.html   

        # create info.php for $SERVER_FQDN
        cat > /var/www/$SERVER_FQDN/info.php << "EOF"
<?php
session_start();
echo session_id();
phpinfo();
?>
EOF

        # create test.html for $WORDPRESS_FQDN
	mkdir -p /var/www/$WORDPRESS_FQDN
	cat > /var/www/$WORDPRESS_FQDN/test.html << "EOF"
<!DOCTYPE html>
<html>
<body>

<h1>WORDPRESS_FQDN</h1>
<p>Hello World! </p>

</body>
</html>
EOF
	sed -i -- "s|WORDPRESS_FQDN|$WORDPRESS_FQDN|g" /var/www/$WORDPRESS_FQDN/test.html

}

install_openssl_from_tar_gz() {
	# Ubuntu 22.04 use OpenSSL 3.0.2
	# Ubuntu 22.04 use OpenSSL 1.1.1f
	# check its version by this command :
	# openssl version
	cd /usr/local/src
	rm -rf ./openssl*
	wget https://www.openssl.org/source/openssl-1.1.1t.tar.gz
	wget https://www.openssl.org/source/openssl-1.1.1t.tar.gz.sha256
	SHA256SUM_SHOULD_BE="$(/usr/bin/cat ./openssl-1.1.1t.tar.gz.sha256 | tr -s ' ' | cut -d ' ' -f 1)"
	SHA256SUM_COMPUTED="$(/usr/bin/sha256sum ./openssl-1.1.1t.tar.gz | cut -d " " -f 1)"
	[ "$SHA256SUM_SHOULD_BE" != "$SHA256SUM_COMPUTED" ] && echo "oops...sha256 checksum doesnt match." && exit 2 || echo "sha256 checksum matched."
	tar zxvf ./openssl-1.1.1t.tar.gz
        cd ./openssl-1.1.1t
	./config --prefix=/usr/local/openssl-1.1.1t --openssldir=/usr/local/openssl-1.1.1t shared zlib
	make
	make install
}

install_imap2007f() {
        # change currently working directory
        cd /usr/local/src

        # remove previously downloaded tar.gz and their extracted folders
        rm -rf ./imap-2007*

        #
        #ln -s /usr/lib/x86_64-linux-gnu/openssl-1.0.0/engines /usr/local/ssl
        mkdir -p /usr/local/ssl
        ln -s /usr/include /usr/local/ssl/include

        # download the source tar.gz, extract it then configure it
	#wget https://fossies.org/linux/misc/old/imap-2007f.tar.gz
	wget https://www.mirrorservice.org/sites/ftp.cac.washington.edu/imap/imap-2007f.tar.gz
        MD5SUM_SHOULD_BE="2126fd125ea26b73b20f01fcd5940369"
        MD5SUM_COMPUTED="$(/usr/bin/md5sum ./imap-2007f.tar.gz | cut -d ' ' -f 1)"
        [ "$MD5SUM_SHOULD_BE" != "$MD5SUM_COMPUTED" ] && echo "oops...md5 checksum doesnt match." && exit 2 || echo "md5 checksum matched."
        tar zxvf ./imap-2007f.tar.gz
        # apply this patch first because u use openssl-1.1.x lib
	# https://raw.githubusercontent.com/openwrt/packages/master/libs/uw-imap/patches/010-imap-2007f-openssl-1.1.patch
        cd ./imap-2007f/
	wget https://raw.githubusercontent.com/openwrt/packages/master/libs/uw-imap/patches/010-imap-2007f-openssl-1.1.patch
	patch src/osdep/unix/ssl_unix.c < ./010-imap-2007f-openssl-1.1.patch
        sed -i -- 's|read x|x="y"|g' ./Makefile  # answer 'y' for you
        make lnp SSLTYPE=unix EXTRACFLAGS=-fPIC
        mkdir lib
        mkdir include
        cp c-client/*.c lib/
        cp c-client/*.h include/
        cp c-client/c-client.a lib/libc-client.a
        mv /usr/local/src/imap-2007f /usr/local
        rm -rf /usr/local/src/imap-2007f.tar.gz
        chown -R root:root /usr/local/imap-2007f
        # for php-imap compilation
        if [ ! -e "/usr/lib/x86_64-linux-gnu/libc-client.a" ] && [ -e "/usr/local/imap-2007f/lib/libc-client.a" ]; then
               ln -s /usr/local/imap-2007f/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a
        fi
	
        if [ ! -e "/usr/lib/libc-client.a" ] && [ -e "/usr/local/imap-2007f/lib/libc-client.a" ]; then
               ln -s /usr/local/imap-2007f/lib/libc-client.a /usr/lib/libc-client.a
        fi

	#### HINT : Or skip this function entirely , just do:
	# apt-get install install -y libc-client2007e libc-client2007e-dev
	# instead , because the codes in this function is very troublesome
}

install_phpfpm() {
	#blah 
	if [[ $OPENSSL_VERSION = 3* ]]
	then
		echo -e "OpenSSL Version starts with 3 , probably Ubuntu 22.04 \n"
		install_phpfpm82
	else
		echo -e "OpenSSL Version not starts with 3 , probably Ubuntu 20.04 \n"
		install_phpfpm74
	fi
}

install_phpfpm74() {
        # for linking kerberos libraries
        mkdir -p /usr/kerberos
        ln -s /usr/lib/x86_64-linux-gnu/ /usr/kerberos/lib

	# for linking libc-client.a
	ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a

        # change currently working directory
        cd /usr/local/src

        # remove previously downloaded tar.gz and their extracted folders
        rm -rf ./php-*

        # download the source tar.gz, extract it then configure it
        wget -O php-7.4.33.tar.gz https://www.php.net/distributions/php-7.4.33.tar.gz
        SHA256SUM_SHOULD_BE="5a2337996f07c8a097e03d46263b5c98d2c8e355227756351421003bea8f463e"
	SHA256SUM_COMPUTED="$(/usr/bin/sha256sum ./php-7.4.33.tar.gz | cut -d " " -f 1)"
	[ "$SHA256SUM_SHOULD_BE" != "$SHA256SUM_COMPUTED" ] && echo "oops...sha256 checksum doesnt match." && exit 2 || echo "sha256 checksum matched."
        tar zxvf ./php-7.4.33.tar.gz
        chown -R root:root ./php-7.4.33
        rm -rf ./php-7.4.33.tar.gz
        cd ./php-7.4.33
                    #--with-imap=/usr/local/imap-2007f \
        ./configure --prefix=/usr/local/php-7.4.33    \
                    --enable-fpm                      \
                    --enable-opcache                  \
                    --with-fpm-user=nginx             \
                    --with-fpm-group=nginx            \
                    --with-zlib                       \
                    --enable-bcmath                   \
                    --with-bz2                        \
                    --enable-calendar                 \
                    --enable-dba=shared               \
                    --with-gdbm                       \
                    --with-gmp                        \
                    --enable-ftp                      \
                    --with-gettext                    \
                    --enable-mbstring                 \
                    --with-readline                   \
                    --enable-zip                      \
                    --enable-pcntl                    \
                    --enable-exif                     \
                    --enable-sysvmsg                  \
                    --enable-sysvsem                  \
                    --enable-sysvshm                  \
                    --enable-sockets                  \
                    --enable-wddx                     \
                    --enable-intl                     \
                    --enable-session                  \
                    --with-curl                       \
                    --with-mcrypt                     \
                    --with-iconv                      \
                    --with-pspell                     \
                    --enable-gd                       \
                    --enable-gd-native-ttf            \
                    --enable-gd-jis-conv              \
                    --with-openssl                    \
                    --with-ldap                       \
                    --with-snmp                       \
                    --with-imap                       \
                    --with-imap-ssl                   \
                    --with-kerberos                   \
                    --with-mysqli=mysqlnd             \
                    --with-pdo-mysql=mysqlnd          \
                    --with-mysql-sock=/var/run/mysqld/mysqld.sock \
                    --enable-mysqlnd-compression-support \
                    --with-libdir=/lib/x86_64-linux-gnu
        make
        #make test
        make install
        cp /usr/local/src/php-7.4.33/php.ini-production /usr/local/php-7.4.33/lib/php.ini
        cp /usr/local/php-7.4.33/etc/php-fpm.conf.default /usr/local/php-7.4.33/etc/php-fpm.conf

        # php.ini setting
        sed -i -- "/\[opcache\]/a zend_extension=/usr/local/php-7.4.33/lib/php/extensions/no-debug-non-zts-20190902/opcache.so" /usr/local/php-7.4.33/lib/php.ini
        sed -i -- "s|;opcache.enable=1|opcache.enable=1|g" /usr/local/php-7.4.33/lib/php.ini
        sed -i -- "s|;opcache.enable_cli=1|opcache.enable_cli=1|g" /usr/local/php-7.4.33/lib/php.ini
        sed -i -- "s|;opcache.memory_consumption=128|opcache.memory_consumption=128|g" /usr/local/php-7.4.33/lib/php.ini
        sed -i -- "s|;opcache.interned_strings_buffer=8|opcache.interned_strings_buffer=8|g" /usr/local/php-7.4.33/lib/php.ini
        sed -i -- "s|;opcache.max_accelerated_files=10000|opcache.max_accelerated_files=10000|g" /usr/local/php-7.4.33/lib/php.ini
        sed -i -- "s|;opcache.use_cwd=1|opcache.use_cwd=0|g" /usr/local/php-7.4.33/lib/php.ini
        sed -i -- "s|;opcache.validate_timestamps=1|opcache.validate_timestamps=0|g" /usr/local/php-7.4.33/lib/php.ini
        sed -i -- "s|;opcache.save_comments=1|opcache.save_comments=0|g" /usr/local/php-7.4.33/lib/php.ini
        sed -i -- "s|;opcache.enable_file_override=0|opcache.enable_file_override=1|g" /usr/local/php-7.4.33/lib/php.ini
        sed -i -- 's/.*;date.timezone =.*/date.timezone = \"Asia\/Taipei\"/g' /usr/local/php-7.4.33/lib/php.ini
        echo "safe_mode = Off" >> /usr/local/php-7.4.33/lib/php.ini
        sed -i -- 's|memory_limit = 128M|memory_limit = 512M|g' /usr/local/php-7.4.33/lib/php.ini
        sed -i -- 's|max_execution_time = 30|max_execution_time = 60|g' /usr/local/php-7.4.33/lib/php.ini

        # php-fpm.conf setting
        sed -i -- '/^include/s/include/;include/' /usr/local/php-7.4.33/etc/php-fpm.conf
        sed -i -- 's|;pid = run/php-fpm.pid|pid = run/php-fpm.pid|g' /usr/local/php-7.4.33/etc/php-fpm.conf
        echo "[www]" >> /usr/local/php-7.4.33/etc/php-fpm.conf
        echo "listen = /usr/local/php-7.4.33/var/run/php-fpm.sock" >> /usr/local/php-7.4.33/etc/php-fpm.conf
        echo "listen.backlog = -1" >> /usr/local/php-7.4.33/etc/php-fpm.conf
        echo "listen.owner = nginx" >> /usr/local/php-7.4.33/etc/php-fpm.conf
        echo "listen.group = nginx" >> /usr/local/php-7.4.33/etc/php-fpm.conf
        echo "listen.mode=0660" >> /usr/local/php-7.4.33/etc/php-fpm.conf
        echo "user = nginx" >> /usr/local/php-7.4.33/etc/php-fpm.conf
        echo "group = nginx" >> /usr/local/php-7.4.33/etc/php-fpm.conf
        echo "pm = dynamic" >> /usr/local/php-7.4.33/etc/php-fpm.conf
        echo "pm.max_children = 20" >> /usr/local/php-7.4.33/etc/php-fpm.conf
        echo "pm.start_servers = 10" >> /usr/local/php-7.4.33/etc/php-fpm.conf
        echo "pm.min_spare_servers = 5" >> /usr/local/php-7.4.33/etc/php-fpm.conf
        echo "pm.max_spare_servers = 20" >> /usr/local/php-7.4.33/etc/php-fpm.conf

        # setup logrotate
cat > /etc/logrotate.d/php-fpm << EOF
/usr/local/php/var/log/*.log {
        weekly
        rotate 12
        compress
        delaycompress
        missingok
        notifempty
        create 644 nginx nginx
}
EOF

        # create systemd unit file
        cat > /lib/systemd/system/php7.4-fpm.service << "EOF"
[Unit]
Description=PHP FastCGI process manager
After=local-fs.target network.target nginx.service

[Service]
ExecStart=/usr/local/php/sbin/php-fpm --fpm-config /usr/local/php/etc/php-fpm.conf
Type=forking

[Install]
WantedBy=multi-user.target
EOF

        # set files/directories owner and group
        chown -R nginx:nginx /usr/local/php-7.4.33
        chown root:root /etc/logrotate.d/php-fpm
        chmod 644 /etc/logrotate.d/php-fpm
        chown root:root /lib/systemd/system/php7.4-fpm.service
        chmod 644 /lib/systemd/system/php7.4-fpm.service

	# change multiple php binaries priority
	update-alternatives --install /usr/bin/php php /usr/local/php-7.4.33/bin/php 99
	update-alternatives --display php
	# if u wanna set priority manually , use this command:
	# update-alternatives --config php
}

install_phpfpm82() {
        # for linking kerberos libraries
        mkdir -p /usr/kerberos
        ln -s /usr/lib/x86_64-linux-gnu/ /usr/kerberos/lib

	# for linking libc-client.a
	ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a

        # change currently working directory
        cd /usr/local/src

        # remove previously downloaded tar.gz and their extracted folders
        rm -rf ./php-*

        # download the source tar.gz, extract it then configure it
        wget -O php-8.2.3.tar.gz wget https://www.php.net/distributions/php-8.2.3.tar.gz
        SHA256SUM_SHOULD_BE="7c475bcbe61d28b6878604b1b6f387f39d1a63b5f21fa8156fd7aa615d43e259"
        SHA256SUM_COMPUTED="$(/usr/bin/sha256sum ./php-8.2.3.tar.gz | cut -d " " -f 1)"
        [ "$SHA256SUM_SHOULD_BE" != "$SHA256SUM_COMPUTED" ] && echo "oops...sha256 checksum doesnt match." && exit 2 || echo "sha256 checksum matched."
        tar zxvf ./php-8.2.3.tar.gz
        chown -R root:root ./php-8.2.3
        rm -rf ./php-8.2.3.tar.gz
        cd ./php-8.2.3
	
                    #--enable-opcache                  \
                    #--enable-wddx                     \
		    #--enable-session                  \
                    #--with-mcrypt                     \
                    #--with-iconv                      \
                    #--enable-gd-native-ttf            \
        ./configure --prefix=/usr/local/php-8.2.3     \
                    --enable-fpm                      \
                    --with-fpm-user=nginx             \
                    --with-fpm-group=nginx            \
                    --with-zlib                       \
                    --enable-bcmath                   \
                    --with-bz2                        \
                    --enable-calendar                 \
                    --enable-dba=shared               \
                    --with-gdbm                       \
                    --with-gmp                        \
                    --enable-ftp                      \
                    --with-gettext                    \
                    --enable-mbstring                 \
                    --with-readline                   \
                    --enable-zip                      \
                    --enable-pcntl                    \
                    --enable-exif                     \
                    --enable-sysvmsg                  \
                    --enable-sysvsem                  \
                    --enable-sysvshm                  \
                    --enable-sockets                  \
                    --enable-intl                     \
                    --with-curl                       \
                    --with-pspell                     \
                    --enable-gd                       \
                    --enable-gd-jis-conv              \
                    --with-openssl                    \
                    --with-ldap                       \
                    --with-snmp                       \
                    --with-imap                       \
                    --with-imap-ssl                   \
                    --with-kerberos                   \
		    --enable-mysqlnd                  \
                    --with-mysqli=mysqlnd             \
                    --with-pdo-mysql=mysqlnd          \
                    --with-mysql-sock=/run/mysqld/mysqld.sock \
		    --with-fpm-systemd \
                    --with-libdir=/lib/x86_64-linux-gnu
        make
	#make test
	make install

        cp /usr/local/src/php-8.2.3/php.ini-production /usr/local/php-8.2.3/lib/php.ini
        cp /usr/local/php-8.2.3/etc/php-fpm.conf.default /usr/local/php-8.2.3/etc/php-fpm.conf

        # php.ini setting
        sed -i -- "/\[opcache\]/a zend_extension=/usr/local/php-8.2.3/lib/php/extensions/no-debug-non-zts-20220829/opcache.so" /usr/local/php-8.2.3/lib/php.ini
        sed -i -- "s|;opcache.enable=1|opcache.enable=1|g" /usr/local/php-8.2.3/lib/php.ini
        sed -i -- "s|;opcache.enable_cli=0|opcache.enable_cli=1|g" /usr/local/php-8.2.3/lib/php.ini
        sed -i -- "s|;opcache.memory_consumption=128|opcache.memory_consumption=128|g" /usr/local/php-8.2.3/lib/php.ini
        sed -i -- "s|;opcache.interned_strings_buffer=8|opcache.interned_strings_buffer=8|g" /usr/local/php-8.2.3/lib/php.ini
        sed -i -- "s|;opcache.max_accelerated_files=10000|opcache.max_accelerated_files=10000|g" /usr/local/php-8.2.3/lib/php.ini
        sed -i -- "s|;opcache.use_cwd=1|opcache.use_cwd=0|g" /usr/local/php-8.2.3/lib/php.ini
        sed -i -- "s|;opcache.validate_timestamps=1|opcache.validate_timestamps=0|g" /usr/local/php-8.2.3/lib/php.ini
        sed -i -- "s|;opcache.save_comments=1|opcache.save_comments=0|g" /usr/local/php-8.2.3/lib/php.ini
        sed -i -- "s|;opcache.enable_file_override=0|opcache.enable_file_override=1|g" /usr/local/php-8.2.3/lib/php.ini
        sed -i -- 's/.*;date.timezone =.*/date.timezone = \"Asia\/Taipei\"/g' /usr/local/php-8.2.3/lib/php.ini
        echo "safe_mode = Off" >> /usr/local/php-8.2.3/lib/php.ini
        sed -i -- 's|memory_limit = 128M|memory_limit = 512M|g' /usr/local/php-8.2.3/lib/php.ini
        sed -i -- 's|max_execution_time = 30|max_execution_time = 60|g' /usr/local/php-8.2.3/lib/php.ini

        # php-fpm.conf setting
        sed -i -- '/^include/s/include/;include/' /usr/local/php-8.2.3/etc/php-fpm.conf
        sed -i -- 's|;pid = run/php-fpm.pid|pid = run/php-fpm.pid|g' /usr/local/php-8.2.3/etc/php-fpm.conf
        echo "[www]" >> /usr/local/php-8.2.3/etc/php-fpm.conf
        echo "listen = /usr/local/php-8.2.3/var/run/php-fpm.sock" >> /usr/local/php-8.2.3/etc/php-fpm.conf
        echo "listen.backlog = -1" >> /usr/local/php-8.2.3/etc/php-fpm.conf
        echo "listen.owner = nginx" >> /usr/local/php-8.2.3/etc/php-fpm.conf
        echo "listen.group = nginx" >> /usr/local/php-8.2.3/etc/php-fpm.conf
        echo "listen.mode=0660" >> /usr/local/php-8.2.3/etc/php-fpm.conf
        echo "user = nginx" >> /usr/local/php-8.2.3/etc/php-fpm.conf
        echo "group = nginx" >> /usr/local/php-8.2.3/etc/php-fpm.conf
        echo "pm = dynamic" >> /usr/local/php-8.2.3/etc/php-fpm.conf
        echo "pm.max_children = 20" >> /usr/local/php-8.2.3/etc/php-fpm.conf
        echo "pm.start_servers = 10" >> /usr/local/php-8.2.3/etc/php-fpm.conf
        echo "pm.min_spare_servers = 5" >> /usr/local/php-8.2.3/etc/php-fpm.conf
        echo "pm.max_spare_servers = 20" >> /usr/local/php-8.2.3/etc/php-fpm.conf

        # setup logrotate
cat > /etc/logrotate.d/php-fpm << EOF
/usr/local/php/var/log/*.log {
        weekly
        rotate 12
        compress
        delaycompress
        missingok
        notifempty
        create 644 nginx nginx
}
EOF

        # create systemd unit file
        cat > /lib/systemd/system/php8.2-fpm.service << "EOF"
[Unit]
Description=PHP FastCGI process manager
After=local-fs.target network.target nginx.service

[Service]
ExecStart=/usr/local/php/sbin/php-fpm --fpm-config /usr/local/php/etc/php-fpm.conf
Type=forking

[Install]
WantedBy=multi-user.target
EOF

        # set files/directories owner and group
        chown -R nginx:nginx /usr/local/php-8.2.3
        chown root:root /etc/logrotate.d/php-fpm
        chmod 644 /etc/logrotate.d/php-fpm
        chown root:root /lib/systemd/system/php8.2-fpm.service
        chmod 644 /lib/systemd/system/php8.2-fpm.service

	# change multiple php binaries priority
	update-alternatives --install /usr/bin/php php /usr/local/php-8.2.3/bin/php 99
	update-alternatives --display php
	# if u wanna set priority manually , use this command:
	# update-alternatives --config php
}

install_php-memcached() {

	cd /usr/local/src
        git clone https://github.com/php-memcached-dev/php-memcached.git
        cd php-memcached
	# dont use php7 branch, switch to master branch
        #git checkout php7
	git checkout master

	if [[ $OPENSSL_VERSION = 3* ]]
	then
        	echo -e "OpenSSL Verison Start with 3 , maybe Ubuntu 22.04 LTS \n"
        	/usr/local/php-8.2.3/bin/phpize
        	./configure --disable-memcached-sasl --with-php-config=/usr/local/php-8.2.3/bin/php-config
        	make && make install
        	chown nginx:nginx /usr/local/php-8.2.3/lib/php/extensions/no-debug-non-zts-20220829//memcached.so
        	echo 'extension=/usr/local/php-8.2.3/lib/php/extensions/no-debug-non-zts-20220829//memcached.so' >> /usr/local/php-8.2.3/lib/php.ini
        	sed -i -- 's|session.save_handler = files|session.save_handler = memcached|g' /usr/local/php-8.2.3/lib/php.ini
        	sed -i -- "s|;session.save_path = \"/tmp\"|session.save_path = \"$SESSION_SAVE_PATH\"|g" /usr/local/php-8.2.3/lib/php.ini
	else
        	echo -e "OpenSSL Not Start with 3 , maybe Ubuntu 20.04 LTS \n"
        	/usr/local/php-7.4.33/bin/phpize
        	./configure --disable-memcached-sasl --with-php-config=/usr/local/php-7.4.33/bin/php-config
        	make && make install
        	chown nginx:nginx /usr/local/php-7.4.33/lib/php/extensions/no-debug-non-zts-20190902/memcached.so
        	echo 'extension=/usr/local/php-7.4.33/lib/php/extensions/no-debug-non-zts-20190902/memcached.so' >> /usr/local/php-7.4.33/lib/php.ini
        	sed -i -- 's|session.save_handler = files|session.save_handler = memcached|g' /usr/local/php-7.4.33/lib/php.ini
        	sed -i -- "s|;session.save_path = \"/tmp\"|session.save_path = \"$SESSION_SAVE_PATH\"|g" /usr/local/php-7.4.33/lib/php.ini
	fi
}

deploy_phpmyadmin() {
        [ "$DEPLOY_PHPMYADMIN" != "yes" ] && echo "skip phpmyadmin deployment." && return || echo "deploy phpmyadmin ---> yes"
        [ -d "/var/www/localhost/phpmyadmin/" ] && echo "seems like phpmyadmin already existed." && return || echo "ready to deploy phpmyadmin."
        cd /var/www/localhost/
	wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.tar.gz
	wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.tar.gz.sha256
        SHA256SUM_IN_FILE="$(cat ./phpMyAdmin-5.2.1-all-languages.tar.gz.sha256 | cut -d " " -f 1)"
        SHA256SUM_COMPUTED="$(/usr/bin/sha256sum ./phpMyAdmin-5.2.1-all-languages.tar.gz | cut -d " " -f 1)"
        [ "$SHA256SUM_IN_FILE" != "$SHA256SUM_COMPUTED" ] && echo "oops...sha256 checksum doesnt match." && exit 2 || echo "sha256 checksum matched."
        tar zxvf ./phpMyAdmin-5.2.1-all-languages.tar.gz
        rm -rf ./phpMyAdmin-5.2.1-all-languages.tar.gz*
        mv phpMyAdmin-5.2.1-all-languages phpmyadmin
        cd ./phpmyadmin/
        cat > /var/www/localhost/phpmyadmin/config.inc.php << "EOF"
<?php
// use here a value of your choice at least 32 chars long
$cfg['blowfish_secret'] = 'PHPMYADMIN_BLOWFISH_SECRET';

$i=0;
$i++;
$cfg['Servers'][$i]['auth_type'] = 'cookie';
$cfg['Servers'][$i]['host'] = 'PHPMYADMIN_DB_HOST';
$cfg['Servers'][$i]['port'] = 'PHPMYADMIN_DB_PORT';
$cfg['Servers'][$i]['controluser'] = 'PHPMYADMIN_CONTROL_USER';
$cfg['Servers'][$i]['controlpass'] = 'PHPMYADMIN_CONTROL_PASS';
?>
EOF
        sed -i -- "s|PHPMYADMIN_BLOWFISH_SECRET|$PHPMYADMIN_BLOWFISH_SECRET|g" /var/www/localhost/phpmyadmin/config.inc.php
        sed -i -- "s|PHPMYADMIN_DB_HOST|$PHPMYADMIN_DB_HOST|g" /var/www/localhost/phpmyadmin/config.inc.php
        sed -i -- "s|PHPMYADMIN_DB_PORT|$PHPMYADMIN_DB_PORT|g" /var/www/localhost/phpmyadmin/config.inc.php
        sed -i -- "s|PHPMYADMIN_CONTROL_USER|$PHPMYADMIN_CONTROL_USER|g" /var/www/localhost/phpmyadmin/config.inc.php
        sed -i -- "s|PHPMYADMIN_CONTROL_PASS|$PHPMYADMIN_CONTROL_PASS|g" /var/www/localhost/phpmyadmin/config.inc.php

	### README parts ####
	echo -e "########################################################################################################### \n"
	echo -e "#  HOW to connect to phpMyAdmin that runs on remote host's 127.0.0.1 port 80 ?                            # \n"
	echo -e "#  Assume this remote host has a SSH service running on port 36000 just like my situation,                # \n"
	echo -e "#  You could fire this command :                                                                          # \n"
	echo -e "#     ssh -p36000 -L 8888:127.0.0.1:80 -N -f username@192.168.21.231                                      # \n"
	echo -e "#  replace <username> and <192.168.21.231> with your real username (like bobson, mary...) and IP address  # \n"
	echo -e "#  it will bind 192.168.21.231 its 127.0.0.1:80 to your local (client) machine                            # \n"
	echo -e "#  so you could open browser then go to http://127.0.0.1:8888/phpmyadmin/                                 # \n"
	echo -e "#  then you will see phpMyAdmin Login page , that's all                                                   # \n"
	echo -e "########################################################################################################### \n"
}

deploy_wordpress() {
        [ "$DEPLOY_WORDPRESS" != "yes" -o -z "$WORDPRESS_FQDN" ] && echo "skip wordpress deployment." && return || echo "deploy wordpress ---> yes"
        [ -f "/var/www/$WORDPRESS_FQDN/wp-config.php" ] && echo "seems like wordpress already installed." && return || echo "ready to deploy wordpress"
        cd /var/www/$WORDPRESS_FQDN/
        wget https://wordpress.org/wordpress-6.1.1.tar.gz.md5
        wget https://wordpress.org/wordpress-6.1.1.tar.gz
        MD5SUM_IN_FILE="$(cat ./wordpress-6.1.1.tar.gz.md5)"
        MD5SUM_COMPUTED="$(/usr/bin/md5sum ./wordpress-6.1.1.tar.gz | cut -d " " -f 1)"
        [ "$MD5SUM_IN_FILE" != "$MD5SUM_COMPUTED" ] && echo "oops...md5 checksum doesnt match." && exit 2 || echo "md5 checksum matched."
        tar zxvf ./wordpress-6.1.1.tar.gz
	mv ./wordpress/* /var/www/$WORDPRESS_FQDN/
        rm -rf ./wordpress-6.1.1.tar.gz*
	rm -rf ./wordpress/
# Hint: salt hash must the same at every backend nodes
        cat > wp-config.php << "EOF"
<?php
define('DB_NAME', 'WORDPRESS_DB_NAME');
define('DB_USER', 'WORDPRESS_DB_USER');
define('DB_PASSWORD', 'WORDPRESS_DB_PASS');
define('DB_HOST', 'WORDPRESS_DB_HOST');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');

define('AUTH_KEY',         'WORDPRESS_AUTH_KEY');
define('SECURE_AUTH_KEY',  'WORDPRESS_SECURE_AUTH_KEY');
define('LOGGED_IN_KEY',    'WORDPRESS_LOGGED_IN_KEY');
define('NONCE_KEY',        'WORDPRESS_NONCE_KEY');
define('AUTH_SALT',        'WORDPRESS_AUTH_SALT');
define('SECURE_AUTH_SALT', 'WORDPRESS_SECURE_AUTH_SALT');
define('LOGGED_IN_SALT',   'WORDPRESS_LOGGED_IN_SALT');
define('NONCE_SALT',       'WORDPRESS_NONCE_SALT');
$table_prefix  = 'wp_';
define('WP_DEBUG', false);
if ( !defined('ABSPATH') )
	define('ABSPATH', dirname(__FILE__) . '/');
require_once(ABSPATH . 'wp-settings.php');
/* SSL Settings */
define('FORCE_SSL_ADMIN', true);

/* Turn HTTPS 'on' if HTTP_X_FORWARDED_PROTO matches 'https' */
if (strpos($_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false) {
    $_SERVER['HTTPS'] = 'on';
}
EOF
        sed -i -- "s|WORDPRESS_DB_HOST|$WORDPRESS_DB_HOST|g" wp-config.php
        sed -i -- "s|WORDPRESS_DB_NAME|$WORDPRESS_DB_NAME|g" wp-config.php
        sed -i -- "s|WORDPRESS_DB_USER|$WORDPRESS_DB_USER|g" wp-config.php
        sed -i -- "s|WORDPRESS_DB_PASS|$WORDPRESS_DB_PASS|g" wp-config.php
        sed -i -- "s|WORDPRESS_AUTH_KEY|$WORDPRESS_AUTH_KEY|g" wp-config.php
        sed -i -- "s|WORDPRESS_SECURE_AUTH_KEY|$WORDPRESS_SECURE_AUTH_KEY|g" wp-config.php
        sed -i -- "s|WORDPRESS_LOGGED_IN_KEY|$WORDPRESS_LOGGED_IN_KEY|g" wp-config.php
        sed -i -- "s|WORDPRESS_NONCE_KEY|$WORDPRESS_NONCE_KEY|g" wp-config.php
        sed -i -- "s|WORDPRESS_AUTH_SALT|$WORDPRESS_AUTH_SALT|g" wp-config.php
        sed -i -- "s|WORDPRESS_SECURE_AUTH_SALT|$WORDPRESS_SECURE_AUTH_SALT|g" wp-config.php
        sed -i -- "s|WORDPRESS_LOGGED_IN_SALT|$WORDPRESS_LOGGED_IN_SALT|g" wp-config.php
        sed -i -- "s|WORDPRESS_NONCE_SALT|$WORDPRESS_NONCE_SALT|g" wp-config.php

	### README parts ####
	echo -e "########################################################################################################### \n"
	echo -e "#  HOW to see the contents of https://blog.dq5rocks.com                   ? ? ?                           # \n"
	echo -e "#  if there is no any DNS Server to resolve 'blog.dq5rocks.com' is just your 192.168.21.231 machine       # \n"
	echo -e "#  You won't see WordPress that u just installed on it (192.168.21.231)                                   # \n"
	echo -e "#  so Try to edit  /etc/hosts  file on the client machine                                                 # \n"
        echo -e "# 	( not 192.168.21.231 , i mean your client machine that u will use browser on it later )            # \n"
	echo -e "#  then put this line in it                                                                               # \n"
	echo -e "#      192.168.21.231  blog.dq5rocks.com                                                                  # \n"
	echo -e "#  after that save the file and leave the text editor                                                     # \n"
	echo -e "#  then you go back to client machine , open browser , then go to https://blog.dq5rocks.com               # \n"
	echo -e "#  u will see WordPress Installation page , that's all                                                    # \n"
	echo -e "########################################################################################################### \n"
}

deploy_cacti() {
        [ "$DEPLOY_CACTI" != "yes" ] && echo "skip cacti deployment." && return || echo "deploy cacti ---> yes"
        [ -d "/var/www/localhost/cacti/" ] && echo "seems like cacti already existed." && return || echo "ready to deploy cacti"
        cd /var/www/localhost/
        wget https://www.cacti.net/downloads/cacti-1.2.24.tar.gz
        tar zxvf ./cacti-1.2.24.tar.gz
        rm -rf ./cacti-1.2.24.tar.gz*
        cd ./cacti-1.2.24/
        mv ./include/config.php ./include/config.php.default
        cat > ./include/config.php << "EOF"
<?php
$database_type     = 'mysql';
$database_default  = 'CACTI_DB_NAME';
$database_hostname = 'CACTI_DB_HOST';
$database_username = 'CACTI_DB_USER';
$database_password = 'CACTI_DB_PASS';
$database_port     = 'CACTI_DB_PORT';
$database_ssl      = false;
$poller_id = 1;
$url_path = '/cacti/';
$cacti_session_name = 'Cacti';
$cacti_db_session = false;
EOF
       sed -i -- "s|CACTI_DB_NAME|$CACTI_DB_NAME|g" ./include/config.php
       sed -i -- "s|CACTI_DB_HOST|$CACTI_DB_HOST|g" ./include/config.php
       sed -i -- "s|CACTI_DB_USER|$CACTI_DB_USER|g" ./include/config.php
       sed -i -- "s|CACTI_DB_PASS|$CACTI_DB_PASS|g" ./include/config.php
       sed -i -- "s|CACTI_DB_PORT|$CACTI_DB_PORT|g" ./include/config.php
       ln -s /var/www/localhost/cacti-1.2.24 /var/www/localhost/cacti
       touch /var/www/localhost/cacti/log/cacti.log

       # download camm and extract it
       cd ./plugins/
       git clone https://github.com/Susanin63/plugin_camm
       #wget https://docs.cacti.net/_media/userplugin:cacti_plugin_camm_v1.5.3.zip
       #unzip ./userplugin:cacti_plugin_camm_v1.5.3.zip
       mv ./plugin_camm ./Camm
       chown -R nginx:nginx ./Camm
       #rm -rf ./userplugin\:cacti_plugin_camm_v1.5.3.zip

       # put cron job in /etc/cron.d/
       cat > /etc/cron.d/cacti << "EOF"
*/5 * * * * nginx /usr/local/php/bin/php /var/www/localhost/cacti/poller.php > /tmp/cacti_poller_by_nginx.log 2>&1
EOF
       chown root:root /etc/cron.d/cacti
       chmod 644 /etc/cron.d/cacti

        # setup logrotate
cat > /etc/logrotate.d/cacti << EOF
/var/www/localhost/cacti/log/*.log {
        weekly
        rotate 12
        compress
        delaycompress
        missingok
        notifempty
        create 644 nginx nginx
}
EOF
        chown root:root /etc/logrotate.d/cacti
	# HINT: default login/password for CACTI is admin/admin
}

deploy_cacti_spine() {
        [ "$DEPLOY_CACTI" != "yes" ] && echo "skip cacti spine deployment." && return || echo "deploy cacti spine ---> yes"
        [ -f "/usr/local/spine/bin/spine" ] && echo "seems like cacti spine already existed." && return || echo "ready to deploy cacti spine"
        apt-get update
        apt-get install libmysqlclient-dev libssl-dev libsnmp-dev help2man dos2unix -y

        cd /usr/local/src
        git clone https://github.com/Cacti/spine
        cd ./spine
	chmod +x ./bootstrap
        ./bootstrap
        ./configure
        make
        make install
        cat > /usr/local/spine/etc/spine.conf << "EOF"
DB_Host			CACTI_DB_HOST
DB_Database		CACTI_DB_NAME
DB_User			CACTI_DB_USER
DB_Pass			CACTI_DB_PASS
DB_Port			CACTI_DB_PORT
EOF
        sed -i -- "s|CACTI_DB_HOST|$CACTI_DB_HOST|g" /usr/local/spine/etc/spine.conf
        sed -i -- "s|CACTI_DB_NAME|$CACTI_DB_NAME|g" /usr/local/spine/etc/spine.conf
        sed -i -- "s|CACTI_DB_USER|$CACTI_DB_USER|g" /usr/local/spine/etc/spine.conf
        sed -i -- "s|CACTI_DB_PASS|$CACTI_DB_PASS|g" /usr/local/spine/etc/spine.conf
        sed -i -- "s|CACTI_DB_PORT|$CACTI_DB_PORT|g" /usr/local/spine/etc/spine.conf
        chmod u+s /usr/local/spine/bin/spine
        chown root:root /usr/local/spine/bin/spine
}

start_systemd_service() {

        # set DocumentRoot owner and group
        chown -R nginx:nginx /var/www/localhost
        chown -R nginx:nginx /var/www/$SERVER_FQDN
        chown -R nginx:nginx /var/www/$WORDPRESS_FQDN

        systemctl daemon-reload

        # start nginx.service and make it as autostart service
        OLD_NGINX_PROCESS_EXISTED="$(netstat -anp | grep nginx | wc -l)"
        if [ "$OLD_NGINX_PROCESS_EXISTED" -gt 0 ]; then
             systemctl stop nginx.service
        fi
	# if /usr/local/nginx is a symbolic link , delete it
        if [ -L /usr/local/nginx ] && [ -d /usr/local/nginx ]; then
             rm -rf /usr/local/nginx
        fi
        ln -s /usr/local/nginx-1.23.3 /usr/local/nginx
        systemctl enable nginx.service
        systemctl start nginx.service
        systemctl status nginx.service

        # start php-fpm and make it as autostart service
	# if /usr/local/php is a symbolic link , delete it
        if [ -L /usr/local/php ] && [ -d /usr/local/php ]; then
             rm -rf /usr/local/php
        fi
        OLD_PHPFPM_PROCESS_EXISTED="$(netstat -anp | grep php-fpm | wc -l)"
	if [[ $OPENSSL_VERSION = 3* ]]
	then
	        if [ "$OLD_PHPFPM_PROCESS_EXISTED" -gt 0 ]; then
			systemctl stop php8.2-fpm.service
		fi
	        ln -s /usr/local/php-8.2.3 /usr/local/php
		systemctl enable php8.2-fpm.service
		systemctl start php8.2-fpm.service
		systemctl status php8.2-fpm.service
	else
		if [ "$OLD_PHPFPM_PROCESS_EXISTED" -gt 0 ]; then	
			systemctl stop php7.4-fpm.service
	     	fi
	        ln -s /usr/local/php-7.4.33 /usr/local/php
		systemctl enable php7.4-fpm.service
		systemctl start php7.4-fpm.service
		systemctl status php7.4-fpm.service
	fi
	
}

main() {
	remove_previous_install
	install_prerequisite
	configure_snmpd_service
	create_self_signed_ssl_cert_and_key
        install_nginx
        edit_nginx_config
        create_some_webpages
	install_phpfpm
        install_php-memcached
        deploy_phpmyadmin
	deploy_wordpress
        deploy_cacti
        deploy_cacti_spine
	start_systemd_service
}

echo -e "This script will install nginx web server with php support \n"
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

