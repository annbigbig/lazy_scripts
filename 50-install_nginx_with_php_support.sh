#!/bin/bash
#
# This script will install nginx web server with php support from source
# and deploy phpmyadmin/wordpress/cacti on this web server 
# before u run this script please confirm these parameters :
#
#####################################################################################################
#
SERVER_FQDN="www.dq5rocks.com"
ENABLE_HTTPS="no"
GENERATE_SELF_SIGNED_SSL_CERTIFICATE="no"
SELF_SIGNED_SSL_C="TW"
SELF_SIGNED_SSL_ST="New Taipei"
SELF_SIGNED_SSL_L="Tamsui"
SELF_SIGNED_SSL_O="Tong-Shing, Inc."
SELF_SIGNED_SSL_CN="www.dq5rocks.com"
SESSION_SAVE_PATH="172.17.205.141:11211,172.17.205.142:11211"
#
#####################################################################################################
###     use this command generate your own blowfish secret then fill in parameter values below 
###     cat /dev/urandom | tr -dc 'a-zA-Z0-9#@!' | fold -w ${1:-32} | head -n 1
DEPLOY_PHPMYADMIN="yes"
PHPMYADMIN_BLOWFISH_SECRET="HrkawpNGPOya7tMeUy!XIsL80oDaT#le"
PHPMYADMIN_DB_HOST="127.0.0.1"
PHPMYADMIN_DB_PORT="3306"
PHPMYADMIN_CONTROL_USER="pmauser"
PHPMYADMIN_CONTROL_PASS="pmapassword"
#
#####################################################################################################
#
DEPLOY_WORDPRESS="yes"
WORDPRESS_DB_HOST="127.0.0.1:3306"
WORDPRESS_DB_NAME="wpdb"
WORDPRESS_DB_USER="wpuser"
WORDPRESS_DB_PASS="wppassword"
###     use this command generate your own salt hash then fill in parameter values below 
###     cat /dev/urandom | tr -dc 'a-zA-Z0-9#@!' | fold -w ${1:-64} | head -n 1
###     i tried use command below either but it generate too many SPECIAL CHARACTERS i cannot escape in sed command :-(
###     wget -O salt.txt https://api.wordpress.org/secret-key/1.1/salt/
WORDPRESS_AUTH_KEY='30hhSvxDUokT1QaxTkXly!gsz#MsyfQCsE1#RUFAXQH3X6GUGXblUrmusADDjxxJ'
WORDPRESS_SECURE_AUTH_KEY='smQixwGo7DMmppPyipqOqP7DUloCXFS5Vg9sVbYbmep5nFnhr4ypLJXiNbbaR2KS'
WORDPRESS_LOGGED_IN_KEY='HigWCbHGVx4VgBlt5CAfx@rgmUftidr1BYYD@06I1dG6xS!PYequhVWntrvYnzzk'
WORDPRESS_NONCE_KEY='1WqNOvhrg#z#ERecoX4S@lffmmtQ4akKprvhCFTcTjQhEDok@9yuzteCgPOhyGO8'
WORDPRESS_AUTH_SALT='xc#0WhpU2ULWl#S2QqTNQMOxiNdG17lNpyLoqnOeK@!EOxy1RAuQCgeUE!W2ZgAe'
WORDPRESS_SECURE_AUTH_SALT='jn#IMx!#k1EICuL80@JOx5E6VLY0IrQbZfnNs@bmsPnAXUHoOeIS5cdlL0YcnK3Q'
WORDPRESS_LOGGED_IN_SALT='@p5SO0evgGbZsfrdt9FS6lQ7flgJIyB9TkURUHLc9@SAcv@7HYtXEtgMK04Kn06T'
WORDPRESS_NONCE_SALT='atao8LV0snpo4PXGjRm3vmJLOeWc@l@1Vl8bw2I2jTlZSpWq#YAtPwAq#Tb6kUNh'
#
#####################################################################################################
#
DEPLOY_CACTI="yes"
CACTI_DB_HOST="127.0.0.1"
CACTI_DB_PORT="3306"
CACTI_DB_NAME="cacti_db"
CACTI_DB_USER="cactiuser"
CACTI_DB_PASS="cactipass"
#
#####################################################################################################
# and please edit nginx configuration inside this function
# your settings are different with me definitely
# modify it to suite your needs :
#
#####################################################################################################
edit_nginx_config(){

        # create nginx.conf
        cat > /usr/local/nginx-1.13.5/conf/nginx.conf << "EOF"
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
        rm -rf /usr/local/nginx-1.13.5/conf/fastcgi.conf
        cat > /usr/local/nginx-1.13.5/conf/fastcgi.conf << "EOF"
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
        rm -rf /usr/local/nginx-1.13.5/conf/proxy.conf
        cat > /usr/local/nginx-1.13.5/conf/proxy.conf << "EOF"
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
	rm -rf /usr/local/nginx-1.13.5/conf/self-signed.conf
        cat > /usr/local/nginx-1.13.5/conf/self-signed.conf << "EOF"
ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
EOF

        # create ssl-params.conf
	rm -rf /usr/local/nginx-1.13.5/conf/ssl-params.conf
	cat > /usr/local/nginx-1.13.5/conf/ssl-params.conf << "EOF"
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
        cat > /usr/local/nginx-1.13.5/conf.d/localhost.conf << "EOF"
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
        cat > /usr/local/nginx-1.13.5/conf.d/$SERVER_FQDN.conf << "EOF"
server {
         listen 80 default_server;
         server_name IP_ADDRESS;
EOF

if [ "$ENABLE_HTTPS" == "yes" ] ; then
        cat >> /usr/local/nginx-1.13.5/conf.d/$SERVER_FQDN.conf << "EOF"
         return 301 https://$server_name$request_uri;
}

server {
         listen 443 ssl default_server;
         include self-signed.conf;
         include ssl-params.conf;
EOF
fi
        cat >> /usr/local/nginx-1.13.5/conf.d/$SERVER_FQDN.conf << "EOF" 
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
        IP_ADDRESS="$(/sbin/ip addr show eth0 | grep dynamic | grep -v inet6 | tr -s ' ' | cut -d ' ' -f 3 | cut -d '/' -f 1)"
        sed -i -- "s|IP_ADDRESS|$IP_ADDRESS|g" /usr/local/nginx-1.13.5/conf.d/$SERVER_FQDN.conf
        sed -i -- "s|SERVER_FQDN|$SERVER_FQDN|g" /usr/local/nginx-1.13.5/conf.d/$SERVER_FQDN.conf

        # create www.bubu.com.conf for 'www.bubu.com'
        cat > /usr/local/nginx-1.13.5/conf.d/www.bubu.com.conf << "EOF"
server {
         listen 80;
         server_name www.bubu.com;
         root /var/www/www.bubu.com;

         # Logging --
         access_log  logs/www.bubu.com.access.log;
         error_log  logs/www.bubu.com.error.log notice;

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

        # test nginx.conf to see if syntax error exist
        CONFIG_SYNTAX_ERR="$(sbin/nginx -t -c conf/nginx.conf 2>&1 | grep 'test failed' | wc -l)"
        [ "$CONFIG_SYNTAX_ERR" -eq 1 ] && echo 'SYNTAX ERROR in nginx.conf' || echo 'nginx.conf is GOOD'


        chown -R nginx:nginx /usr/local/nginx-1.13.5
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
             apt-get purge -y apache2 apache2-bin apache2-data apache2-utils libaprutil1-dbd-sqlite3 libaprutil1-ldap liblua5.1-0
             apt-get purge -y libapache2-mod-php libapache2-mod-php7.0 libmcrypt4 php php-common php-mcrypt php-mysql php7.0
             apt-get purge -y php7.0-cli php7.0-common php7.0-json php7.0-mbstring php7.0-mcrypt php7.0-mysql php7.0-opcache php7.0-readline
             apt autoremove -y
             rm -rf /var/lib/apache2/
             rm -rf /var/lib/php/
             # try to remove source installation
             rm -rf /usr/local/apache2
             rm -rf /usr/local/apache-2*
        fi

        # remove php-fpm if it has been installed
        if [ -f /lib/systemd/system/php7.0-fpm.service ]; then
             # stop/disable service
             systemctl disable php7.0-fpm.service
             systemctl stop php7.0-fpm.service
             # try to remove binary package
             apt-get purge -y php-common php7.0-cli php7.0-common php7.0-fpm php7.0-json php7.0-opcache php7.0-readline
             apt-get purge -y php-pear php-mysql php7.0-mysql
             apt autoremove -y
             rm -rf /etc/php/
             rm -rf /var/lib/php/
             # try to remove source installation
             rm -rf /usr/local/php
             rm -rf /usr/local/php-*
        fi
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
        /usr/bin/openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
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
        apt-get install -y libbz2-dev libjpeg-dev libxpm-dev libgmp-dev libgmp3-dev libxpm-dev libpspell-dev librecode-dev
        apt-get install -y libcurl3 libcurl3-gnutls libcurl4-openssl-dev pkg-config libssl-dev libgdbm-dev libpng-dev libmcrypt-dev
        apt-get install -y libpam0g-dev libkrb5-dev
	#apt-get install -y libmariadb-dev* libdb-dev libdb4.8
        #apt-get install -y libc-client2007e libc-client2007e-dev libglib2.0-dev libfcgi-dev libfcgi0ldbl libjpeg62-dbg
        # php-memcached require these
        apt-get install -y php7.0-dev git pkg-config build-essential libmemcached-dev
        # php snmp module require these
        apt-get install -y libsnmp-base libsnmp-dev
        if [ "$DEPLOY_CACTI" == "yes" ] ; then
            # cacti will require these
            apt-get install -y snmp snmpd rrdtool
        fi

        # need to to this on ubuntu 17.04
        if [ ! -e "/usr/include/curl" ] && [ -e "/usr/include/x86_64-linux-gnu/curl" ]; then
               ln -s /usr/include/x86_64-linux-gnu/curl /usr/include/curl
        fi

        # for php-imap compilation
        if [ ! -e "/usr/lib/x86_64-linux-gnu/libc-client.a" ] && [ -e "/usr/lib/libc-client.a" ]; then
               ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a
        fi
}

configure_snmpd_service(){
        [ "$DEPLOY_CACTI" != "yes" ] && echo "skip configuring snmpd" && return || echo "configure snmpd service"
        sed -i -- 's|^view   systemonly  included   .1.3.6.1.2.1.1$|view   systemonly  included   .1.3.6.1.2.1|g' /etc/snmp/snmpd.conf
        systemctl restart snmpd
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
        wget http://nginx.org/download/nginx-1.13.5.tar.gz
        wget http://nginx.org/download/nginx-1.13.5.tar.gz.asc
        PUBLIC_KEY_1="$(gpg nginx-1.13.5.tar.gz.asc 2>&1 | grep -E -i 'rsa|dsa' | tr -s ' ' | rev | cut -d ' ' -f 1 | rev)"
        IMPORT_KEY_RESULT_1="$(gpg --keyserver pgpkeys.mit.edu --recv-key $PUBLIC_KEY_1 2>&1 | grep 'mdounin@mdounin.ru' | wc -l)"
        VERIFY_SIGNATURE_RESULT_1="$(gpg ./nginx-1.13.5.tar.gz.asc 2>&1 | grep 'mdounin@mdounin.ru' | wc -l)"
        [ "$IMPORT_KEY_RESULT_1" -gt 0 ] && echo "pubkey $PUBLIC_KEY_1 imported successfuly" ||  exit 2
        [ "$VERIFY_SIGNATURE_RESULT_1" -gt 0 ] && echo "verify signature successfully" || exit 2

        wget https://www.openssl.org/source/openssl-1.1.0g.tar.gz
        wget https://www.openssl.org/source/openssl-1.1.0g.tar.gz.sha256
        SHA256SUM="$(cat ./openssl-1.1.0g.tar.gz.sha256)"
        SHA256SUM_COMPUTE="$(sha256sum ./openssl-1.1.0g.tar.gz | cut -d ' ' -f 1)"
        [ "$SHA256SUM" == "$SHA256SUM_COMPUTE" ] && echo "openssl sha256sum matched." || exit 2

        wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.41.tar.gz
        wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.41.tar.gz.sig
        PUBLIC_KEY_2="$(gpg ./pcre-8.41.tar.gz.sig 2>&1 | grep -E -i 'rsa|dsa' | tr -s ' ' | rev | cut -d ' ' -f 1 | rev)"
        IMPORT_KEY_RESULT_2="$(gpg --keyserver pgpkeys.mit.edu --recv-key $PUBLIC_KEY_2 2>&1 | grep 'ph10@hermes.cam.ac.uk' | wc -l)"
        VERIFY_SIGNATURE_RESULT_2="$(gpg ./pcre-8.41.tar.gz.sig 2>&1 | grep 'ph10@hermes.cam.ac.uk' | wc -l)"
        [ "$IMPORT_KEY_RESULT_2" -gt 0 ] && echo "pubkey $PUBLIC_KEY_2 imported successfuly" || exit 2
        [ "$VERIFY_SIGNATURE_RESULT_2" -gt 0 ] && echo "verify signature successfully" || exit 2

        wget http://zlib.net/zlib-1.2.11.tar.gz
        wget http://zlib.net/zlib-1.2.11.tar.gz.asc
        PUBLIC_KEY_3="$(gpg ./zlib-1.2.11.tar.gz.asc 2>&1 | grep -E -i 'rsa|dsa' | tr -s ' ' | rev | cut -d ' ' -f 1 | rev)"
        IMPORT_KEY_RESULT_3="$(gpg --keyserver pgpkeys.mit.edu --recv-key $PUBLIC_KEY_3 2>&1 | grep 'madler@alumni.caltech.edu' | wc -l)"
        VERIFY_SIGNATURE_RESULT_3="$(gpg ./zlib-1.2.11.tar.gz.asc 2>&1 | grep 'madler@alumni.caltech.edu' | wc -l)"
        [ "$IMPORT_KEY_RESULT_3" -gt 0 ] && echo "pubkey $PUBLIC_KEY_3 imported successfuly" || exit 2
        [ "$VERIFY_SIGNATURE_RESULT_3" -gt 0 ] && echo "verify signature successfully" || exit 2

        # extract all of tar.gz files and configure nginx
        tar -zxvf ./nginx-1.13.5.tar.gz
        tar -zxvf ./openssl-1.1.0g.tar.gz
        tar -zxvf ./pcre-8.41.tar.gz
        tar -zxvf ./zlib-1.2.11.tar.gz
        rm -rf *.tar.gz*

        # change directories owner and group
        chown -R root:root ./nginx-1.13.5
        chown -R root:root ./openssl-1.1.0g
        chown -R root:root ./pcre-8.41
        chown -R root:root ./zlib-1.2.11

        # configure then make then install
        cd ./nginx-1.13.5
	./configure --prefix=/usr/local/nginx-1.13.5 \
                    --user=nginx \
                    --group=nginx \
                    --with-http_ssl_module \
                    --with-pcre=/usr/local/src/pcre-8.41 \
                    --with-zlib=/usr/local/src/zlib-1.2.11 \
                    --with-openssl=/usr/local/src/openssl-1.1.0g \
                    --with-http_stub_status_module

        make
        make install

        # backup default nginx.conf
        if [ -f /usr/local/nginx-1.13.5/conf/nginx.conf.default ]; then
           rm -rf /usr/local/nginx-1.13.5/conf/nginx.conf
        else
           mv /usr/local/nginx-1.13.5/conf/nginx.conf /usr/local/nginx-1.13.5/conf/nginx.conf.default
        fi

        # create sub-directories
        mkdir /usr/local/nginx-1.13.5/conf.d/
        mkdir /usr/local/nginx-1.13.5/run/

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

        # create index.html for www.bubu.com
	mkdir -p /var/www/www.bubu.com
	cat > /var/www/www.bubu.com/index.html << "EOF"
<!DOCTYPE html>
<html>
<body>

<h1>www.bubu.com</h1>
<p>Hello World! bu</p>

</body>
</html>
EOF

}

install_imap2007f() {
        # change currently working directory
        cd /usr/local/src

        # remove previously downloaded tar.gz and their extracted folders
        rm -rf ./imap-2007*

        #
        ln -s /usr/lib/x86_64-linux-gnu/openssl-1.0.0/engines /usr/local/ssl
        ln -s /usr/include /usr/local/ssl/include

        # download the source tar.gz, extract it then configure it
        wget https://fossies.org/linux/misc/imap-2007f.tar.gz
        MD5SUM_SHOULD_BE="2126fd125ea26b73b20f01fcd5940369"
        MD5SUM_COMPUTED="$(/usr/bin/md5sum ./imap-2007f.tar.gz | cut -d ' ' -f 1)"
        [ "$MD5SUM_SHOULD_BE" != "$MD5SUM_COMPUTED" ] && echo "oops...md5 checksum doesnt match." && exit 2 || echo "md5 checksum matched."
        tar zxvf ./imap-2007f.tar.gz
        cd ./imap-2007f/
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
}

install_phpfpm() {
        # for linking kerberos libraries
        mkdir -p /usr/kerberos
        ln -s /usr/lib/x86_64-linux-gnu/ /usr/kerberos/lib

        # change currently working directory
        cd /usr/local/src

        # remove previously downloaded tar.gz and their extracted folders
        rm -rf ./php-*

        # download the source tar.gz, extract it then configure it
        wget -O php-7.1.11.tar.gz http://jp2.php.net/get/php-7.1.11.tar.gz/from/this/mirror
        SHA256SUM_SHOULD_BE="de41b2c166bc5ec8ea96a337d4dd675c794f7b115a8a47bb04595c03dbbdf425"
	SHA256SUM_COMPUTED="$(/usr/bin/sha256sum ./php-7.1.11.tar.gz | cut -d " " -f 1)"
	[ "$SHA256SUM_SHOULD_BE" != "$SHA256SUM_COMPUTED" ] && echo "oops...sha256 checksum doesnt match." && exit 2 || echo "sha256 checksum matched."
        tar zxvf ./php-7.1.11.tar.gz
        chown -R root:root ./php-7.1.11
        rm -rf ./php-7.1.11.tar.gz
        cd ./php-7.1.11
        ./configure --prefix=/usr/local/php-7.1.11    \
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
                    --with-gd                         \
                    --enable-gd-native-ttf            \
                    --enable-gd-jis-conv              \
                    --with-openssl                    \
                    --with-ldap                       \
                    --with-snmp                       \
                    --with-imap=/usr/local/imap-2007f \
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
        cp /usr/local/src/php-7.1.11/php.ini-production /usr/local/php-7.1.11/lib/php.ini
        cp /usr/local/php-7.1.11/etc/php-fpm.conf.default /usr/local/php-7.1.11/etc/php-fpm.conf

        # php.ini setting
        sed -i -- "/\[opcache\]/a zend_extension=/usr/local/php-7.1.11/lib/php/extensions/no-debug-non-zts-20160303/opcache.so" /usr/local/php-7.1.11/lib/php.ini
        sed -i -- "s|;opcache.enable=1|opcache.enable=1|g" /usr/local/php-7.1.11/lib/php.ini
        sed -i -- "s|;opcache.enable_cli=1|opcache.enable_cli=1|g" /usr/local/php-7.1.11/lib/php.ini
        sed -i -- "s|;opcache.memory_consumption=128|opcache.memory_consumption=128|g" /usr/local/php-7.1.11/lib/php.ini
        sed -i -- "s|;opcache.interned_strings_buffer=8|opcache.interned_strings_buffer=8|g" /usr/local/php-7.1.11/lib/php.ini
        sed -i -- "s|;opcache.max_accelerated_files=10000|opcache.max_accelerated_files=10000|g" /usr/local/php-7.1.11/lib/php.ini
        sed -i -- "s|;opcache.use_cwd=1|opcache.use_cwd=0|g" /usr/local/php-7.1.11/lib/php.ini
        sed -i -- "s|;opcache.validate_timestamps=1|opcache.validate_timestamps=0|g" /usr/local/php-7.1.11/lib/php.ini
        sed -i -- "s|;opcache.save_comments=1|opcache.save_comments=0|g" /usr/local/php-7.1.11/lib/php.ini
        sed -i -- "s|;opcache.enable_file_override=0|opcache.enable_file_override=1|g" /usr/local/php-7.1.11/lib/php.ini
        sed -i -- 's/.*;date.timezone =.*/date.timezone = \"Asia\/Taipei\"/g' /usr/local/php-7.1.11/lib/php.ini
        echo "safe_mode = Off" >> /usr/local/php-7.1.11/lib/php.ini
        sed -i -- 's|memory_limit = 128M|memory_limit = 256M|g' /usr/local/php-7.1.11/lib/php.ini

        # php-fpm.conf setting
        sed -i -- '/^include/s/include/;include/' /usr/local/php-7.1.11/etc/php-fpm.conf
        sed -i -- 's|;pid = run/php-fpm.pid|pid = run/php-fpm.pid|g' /usr/local/php-7.1.11/etc/php-fpm.conf
        echo "[www]" >> /usr/local/php-7.1.11/etc/php-fpm.conf
        echo "listen = /usr/local/php-7.1.11/var/run/php-fpm.sock" >> /usr/local/php-7.1.11/etc/php-fpm.conf
        echo "listen.backlog = -1" >> /usr/local/php-7.1.11/etc/php-fpm.conf
        echo "listen.owner = nginx" >> /usr/local/php-7.1.11/etc/php-fpm.conf
        echo "listen.group = nginx" >> /usr/local/php-7.1.11/etc/php-fpm.conf
        echo "listen.mode=0660" >> /usr/local/php-7.1.11/etc/php-fpm.conf
        echo "user = nginx" >> /usr/local/php-7.1.11/etc/php-fpm.conf
        echo "group = nginx" >> /usr/local/php-7.1.11/etc/php-fpm.conf
        echo "pm = dynamic" >> /usr/local/php-7.1.11/etc/php-fpm.conf
        echo "pm.max_children = 20" >> /usr/local/php-7.1.11/etc/php-fpm.conf
        echo "pm.start_servers = 10" >> /usr/local/php-7.1.11/etc/php-fpm.conf
        echo "pm.min_spare_servers = 5" >> /usr/local/php-7.1.11/etc/php-fpm.conf
        echo "pm.max_spare_servers = 20" >> /usr/local/php-7.1.11/etc/php-fpm.conf

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
        cat > /lib/systemd/system/php7.0-fpm.service << "EOF"
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
        chown -R nginx:nginx /usr/local/php-7.1.11
        chown root:root /etc/logrotate.d/php-fpm
        chmod 644 /etc/logrotate.d/php-fpm
        chown root:root /lib/systemd/system/php7.0-fpm.service
        chmod 644 /lib/systemd/system/php7.0-fpm.service
}

install_php-memcached() {
        cd /usr/local/src
        git clone https://github.com/php-memcached-dev/php-memcached.git
        cd php-memcached
        git checkout php7
        phpize
        ./configure --disable-memcached-sasl --with-php-config=/usr/local/php-7.1.11/bin/php-config
        make && make install
        chown nginx:nginx /usr/local/php-7.1.11/lib/php/extensions/no-debug-non-zts-20160303/memcached.so
        echo 'extension=/usr/local/php-7.1.11/lib/php/extensions/no-debug-non-zts-20160303/memcached.so' >> /usr/local/php-7.1.11/lib/php.ini
        sed -i -- 's|session.save_handler = files|session.save_handler = memcached|g' /usr/local/php-7.1.11/lib/php.ini
        sed -i -- "s|;session.save_path = \"/tmp\"|session.save_path = \"$SESSION_SAVE_PATH\"|g" /usr/local/php-7.1.11/lib/php.ini
}

deploy_phpmyadmin() {
        [ "$DEPLOY_PHPMYADMIN" != "yes" ] && echo "skip phpmyadmin deployment." && return || echo "deploy phpmyadmin ---> yes"
        [ -d "/var/www/$SERVER_FQDN/phpmyadmin/" ] && echo "seems like phpmyadmin already existed." && return || echo "ready to deploy phpmyadmin."
        cd /var/www/$SERVER_FQDN/
        wget https://files.phpmyadmin.net/phpMyAdmin/4.7.5/phpMyAdmin-4.7.5-all-languages.tar.gz.sha256
        wget https://files.phpmyadmin.net/phpMyAdmin/4.7.5/phpMyAdmin-4.7.5-all-languages.tar.gz
        SHA256SUM_IN_FILE="$(cat ./phpMyAdmin-4.7.5-all-languages.tar.gz.sha256 | cut -d " " -f 1)"
        SHA256SUM_COMPUTED="$(/usr/bin/sha256sum ./phpMyAdmin-4.7.5-all-languages.tar.gz | cut -d " " -f 1)"
        [ "$SHA256SUM_IN_FILE" != "$SHA256SUM_COMPUTED" ] && echo "oops...sha256 checksum doesnt match." && exit 2 || echo "sha256 checksum matched."
        tar zxvf ./phpMyAdmin-4.7.5-all-languages.tar.gz
        rm -rf ./phpMyAdmin-4.7.5-all-languages.tar.gz*
	mv phpMyAdmin-4.7.5-all-languages phpmyadmin
        cd ./phpmyadmin/
        cat > /var/www/$SERVER_FQDN/phpmyadmin/config.inc.php << "EOF"
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
        sed -i -- "s|PHPMYADMIN_BLOWFISH_SECRET|$PHPMYADMIN_BLOWFISH_SECRET|g" /var/www/$SERVER_FQDN/phpmyadmin/config.inc.php
        sed -i -- "s|PHPMYADMIN_DB_HOST|$PHPMYADMIN_DB_HOST|g" /var/www/$SERVER_FQDN/phpmyadmin/config.inc.php
        sed -i -- "s|PHPMYADMIN_DB_PORT|$PHPMYADMIN_DB_PORT|g" /var/www/$SERVER_FQDN/phpmyadmin/config.inc.php
        sed -i -- "s|PHPMYADMIN_CONTROL_USER|$PHPMYADMIN_CONTROL_USER|g" /var/www/$SERVER_FQDN/phpmyadmin/config.inc.php
        sed -i -- "s|PHPMYADMIN_CONTROL_PASS|$PHPMYADMIN_CONTROL_PASS|g" /var/www/$SERVER_FQDN/phpmyadmin/config.inc.php
}

deploy_wordpress() {
        [ "$DEPLOY_WORDPRESS" != "yes" ] && echo "skip wordpress deployment." && return || echo "deploy wordpress ---> yes"
        [ -d "/var/www/$SERVER_FQDN/wordpress/" ] && echo "seems like wordpress already installed." && return || echo "ready to deploy wordpress."
        cd /var/www/$SERVER_FQDN/
        wget https://wordpress.org/wordpress-4.9.tar.gz.md5
        wget https://wordpress.org/wordpress-4.9.tar.gz
        MD5SUM_IN_FILE="$(cat ./wordpress-4.9.tar.gz.md5)"
        MD5SUM_COMPUTED="$(/usr/bin/md5sum ./wordpress-4.9.tar.gz | cut -d " " -f 1)"
        [ "$MD5SUM_IN_FILE" != "$MD5SUM_COMPUTED" ] && echo "oops...md5 checksum doesnt match." && exit 2 || echo "md5 checksum matched."
        tar zxvf ./wordpress-4.9.tar.gz
        rm -rf ./wordpress-4.9.tar.gz*
        cd ./wordpress
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
}

deploy_cacti() {
        [ "$DEPLOY_CACTI" != "yes" ] && echo "skip cacti deployment." && return || echo "deploy cacti ---> yes"
        [ -d "/var/www/$SERVER_FQDN/cacti/" ] && echo "seems like cacti already existed." && return || echo "ready to deploy cacti"
        cd /var/www/$SERVER_FQDN/
        wget https://www.cacti.net/downloads/cacti-1.1.27.tar.gz
        tar zxvf ./cacti-1.1.27.tar.gz
        rm -rf ./cacti-1.1.27.tar.gz*
        cd ./cacti-1.1.27/
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
       ln -s /var/www/$SERVER_FQDN/cacti-1.1.27 /var/www/$SERVER_FQDN/cacti
       touch /var/www/$SERVER_FQDN/cacti/log/cacti.log
       # put cron job in /etc/cron.d/
       cat > /etc/cron.d/cacti << "EOF"
*/5 * * * * nginx /usr/local/php/bin/php /var/www/SERVER_FQDN/cacti/poller.php > /tmp/cacti_poller_by_nginx.log 2>&1
EOF
       sed -i -- "s|SERVER_FQDN|$SERVER_FQDN|g" /etc/cron.d/cacti
       chown root:root /etc/cron.d/cacti
       chmod 644 /etc/cron.d/cacti

        # setup logrotate
cat > /etc/logrotate.d/cacti << EOF
/var/www/SERVER_FQDN/cacti/log/*.log {
        weekly
        rotate 12
        compress
        delaycompress
        missingok
        notifempty
        create 644 nginx nginx
}
EOF
        sed -i -- "s|SERVER_FQDN|$SERVER_FQDN|g" /etc/logrotate.d/cacti
        chown root:root /etc/logrotate.d/cacti
}

deploy_cacti_spine() {
        [ "$DEPLOY_CACTI" != "yes" ] && echo "skip cacti spine deployment." && return || echo "deploy cacti spine ---> yes"
        [ -f "/usr/local/spine/bin/spine" ] && echo "seems like cacti spine already existed." && return || echo "ready to deploy cacti spine"
        apt-get update
        apt-get install libmysqlclient-dev libssl-dev libmysqlclient-dev libsnmp-dev help2man dos2unix -y

        cd /usr/local/src
        git clone https://github.com/Cacti/spine
        cd ./spine
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

start_nginx_service() {

        # set DocumentRoot owner and group
        chown -R nginx:nginx /var/www/localhost
        chown -R nginx:nginx /var/www/$SERVER_FQDN
        chown -R nginx:nginx /var/www/www.bubu.com

        systemctl daemon-reload

        # start nginx.service and make it as autostart service
        OLD_NGINX_PROCESS_EXISTED="$(netstat -anp | grep nginx | wc -l)"
        if [ "$OLD_NGINX_PROCESS_EXISTED" -gt 0 ]; then
             systemctl stop nginx.service
        fi
        if [ -L /usr/local/nginx ] && [ -d /usr/local/nginx ]; then
             rm -rf /usr/local/nginx
        fi
        ln -s /usr/local/nginx-1.13.5 /usr/local/nginx
        systemctl enable nginx.service
        systemctl start nginx.service
        systemctl status nginx.service

        # start php-fpm and make it as autostart service
        OLD_PHPFPM_PROCESS_EXISTED="$(netstat -anp | grep php-fpm | wc -l)"
        if [ "$OLD_PHPFPM_PROCESS_EXISTED" -gt 0 ]; then
             systemctl stop php7.0-fpm.service
        fi
        if [ -L /usr/local/php ] && [ -d /usr/local/php ]; then
             rm -rf /usr/local/php
        fi

        ln -s /usr/local/php-7.1.11 /usr/local/php
        systemctl enable php7.0-fpm.service
        systemctl start php7.0-fpm.service
        systemctl status php7.0-fpm.service
}

main() {
	remove_previous_install
	install_prerequisite
	configure_snmpd_service
	create_self_signed_ssl_cert_and_key
        install_nginx
        edit_nginx_config
        create_some_webpages
        install_imap2007f
	install_phpfpm
        install_php-memcached
        deploy_phpmyadmin
	deploy_wordpress
        deploy_cacti
        deploy_cacti_spine
	start_nginx_service
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

