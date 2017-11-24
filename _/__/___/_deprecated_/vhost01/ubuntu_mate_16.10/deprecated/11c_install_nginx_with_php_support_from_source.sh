#!/bin/bash
#
# This script will install nginx web server with php support from source
# (tested on Ubuntu mate 16.10/17.04)
#
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
#
# specify MYSQL_ROOT_PASSWD for generating phpmyadmin db user
#####################
MYSQL_ROOT_PASSWD="rootpass"
#####################

say_goodbye() {
	echo "goodbye everyone"
}

unlock_apt_bala_bala(){
        #
        # This function is only needed if you ever seen error messages below
        # E: Could not get lock /var/lib/dpkg/lock - open (11 Resource temporarily unavailable)
        # E: Unable to lock the administration directory (/var/lib/dpkg/) is another process using it?
        #
        rm -rf /var/lib/apt/lists/lock
        rm -rf /var/cache/apt/archives/lock
        rm -rf /var/lib/dpkg/lock
        dpkg --configure -a
}

update_system() {
        # this problem maybe occur
        # https://bugs.launchpad.net/ubuntu/+source/aptitude/+bug/1543280
        # before install/upgrade package, change directory permission number to 777 for it
        chmod 777 /var/lib/update-notifier/package-data-downloads/partial
        apt-get update
        apt-get dist-upgrade -y
        apt autoremove -y
        # after installation , change it back to its original value 755
        chmod 755 /var/lib/update-notifier/package-data-downloads/partial
}

sync_system_time() {
        NTPDATE_INSTALL="$(dpkg --get-selections | grep ntpdate)"
        if [ -z "$NTPDATE_INSTALL" ]; then
                apt-get install -y ntpdate
        fi
                ntpdate -v pool.ntp.org
}

# The commands inside this function will stop/disable HTTPD service
# and remove all related installed packages no matter it was installed from apt-get or from source
# so if you are so sure that you are upgrading NGINX from previously source installation
# and you want to upgrade NGINX seamlessly without any server downtime
# DO NOT RUN COMMANDS INSIDE THIS FUNCTION
remove_previous_install() {
        # remove nginx if it seems like been installed
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

        # remove apache2 if it seems like been installed
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

        # remove php-fpm if it seems like been installed
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

        # need to to this on ubuntu 17.04
        if [ ! -e "/usr/include/curl" ] && [ -e "/usr/include/x86_64-linux-gnu/curl" ]; then
               ln -s /usr/include/x86_64-linux-gnu/curl /usr/include/curl
        fi

        # for php-imap compilation
        if [ ! -e "/usr/lib/x86_64-linux-gnu/libc-client.a" ] && [ -e "/usr/lib/libc-client.a" ]; then
               ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a
        fi
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
        wget http://nginx.org/download/nginx-1.13.1.tar.gz
        wget http://nginx.org/download/nginx-1.13.1.tar.gz.asc
        PUBLIC_KEY_1="$(gpg nginx-1.13.1.tar.gz.asc 2>&1 | grep -E -i 'rsa|dsa' | tr -s ' ' | cut -d ' ' -f 5)"
        IMPORT_KEY_RESULT_1="$(gpg --keyserver pgpkeys.mit.edu --recv-key $PUBLIC_KEY_1 2>&1 | grep 'mdounin@mdounin.ru' | wc -l)"
        VERIFY_SIGNATURE_RESULT_1="$(gpg ./nginx-1.13.1.tar.gz.asc 2>&1 | grep 'mdounin@mdounin.ru' | wc -l)"
        [ "$IMPORT_KEY_RESULT_1" -eq 1 ] && echo "pubkey $PUBLIC_KEY_1 imported successfuly" ||  exit 2
        [ "$VERIFY_SIGNATURE_RESULT_1" -eq 1 ] && echo "verify signature successfully" || exit 2

        wget https://www.openssl.org/source/openssl-1.1.0f.tar.gz
        wget https://www.openssl.org/source/openssl-1.1.0f.tar.gz.sha256
        SHA256SUM="$(cat ./openssl-1.1.0f.tar.gz.sha256)"
        SHA256SUM_COMPUTE="$(sha256sum ./openssl-1.1.0f.tar.gz | cut -d ' ' -f 1)"
        [ "$SHA256SUM" == "$SHA256SUM_COMPUTE" ] && echo "openssl sha256sum matched." || exit 2

        wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.40.tar.gz
        wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.40.tar.gz.sig
        PUBLIC_KEY_2="$(gpg ./pcre-8.40.tar.gz.sig 2>&1 | grep -E -i 'rsa|dsa' | tr -s ' ' | cut -d ' ' -f 5)"
        IMPORT_KEY_RESULT_2="$(gpg --keyserver pgpkeys.mit.edu --recv-key $PUBLIC_KEY_2 2>&1 | grep 'ph10@hermes.cam.ac.uk' | wc -l)"
        VERIFY_SIGNATURE_RESULT_2="$(gpg ./pcre-8.40.tar.gz.sig 2>&1 | grep 'ph10@hermes.cam.ac.uk' | wc -l)"
        [ "$IMPORT_KEY_RESULT_2" -eq 1 ] && echo "pubkey $PUBLIC_KEY_2 imported successfuly" || exit 2
        [ "$VERIFY_SIGNATURE_RESULT_2" -eq 1 ] && echo "verify signature successfully" || exit 2

        wget http://zlib.net/zlib-1.2.11.tar.gz
        wget http://zlib.net/zlib-1.2.11.tar.gz.asc
        PUBLIC_KEY_3="$(gpg ./zlib-1.2.11.tar.gz.asc 2>&1 | grep -E -i 'rsa|dsa' | tr -s ' ' | cut -d ' ' -f 5)"
        IMPORT_KEY_RESULT_3="$(gpg --keyserver pgpkeys.mit.edu --recv-key $PUBLIC_KEY_3 2>&1 | grep 'madler@alumni.caltech.edu' | wc -l)"
        VERIFY_SIGNATURE_RESULT_3="$(gpg ./zlib-1.2.11.tar.gz.asc 2>&1 | grep 'madler@alumni.caltech.edu' | wc -l)"
        [ "$IMPORT_KEY_RESULT_3" -eq 1 ] && echo "pubkey $PUBLIC_KEY_3 imported successfuly" || exit 2
        [ "$VERIFY_SIGNATURE_RESULT_3" -eq 1 ] && echo "verify signature successfully" || exit 2

        # extract all of tar.gz files and configure nginx
        tar -zxvf ./nginx-1.13.1.tar.gz
        tar -zxvf ./openssl-1.1.0f.tar.gz
        tar -zxvf ./pcre-8.40.tar.gz
        tar -zxvf ./zlib-1.2.11.tar.gz
        rm -rf *.tar.gz*

        # change directories owner and group
        chown -R root:root ./nginx-1.13.1
        chown -R root:root ./openssl-1.1.0f
        chown -R root:root ./pcre-8.40
        chown -R root:root ./zlib-1.2.11

        # configure then make then install
        cd ./nginx-1.13.1
	./configure --prefix=/usr/local/nginx-1.13.1 \
                    --user=nginx \
                    --group=nginx \
                    --with-http_ssl_module \
                    --with-pcre=/usr/local/src/pcre-8.40 \
                    --with-zlib=/usr/local/src/zlib-1.2.11 \
                    --with-openssl=/usr/local/src/openssl-1.1.0f \
                    --with-http_stub_status_module

        make
        make install

        # create a fine-tuned nginx.conf
        if [ -f /usr/local/nginx-1.13.1/conf/nginx.conf.default ]; then
           rm -rf /usr/local/nginx-1.13.1/conf/nginx.conf
        else
           mv /usr/local/nginx-1.13.1/conf/nginx.conf /usr/local/nginx-1.13.1/conf/nginx.conf.default
        fi

        # create sub-directories
        mkdir /usr/local/nginx-1.13.1/conf.d/
        mkdir /usr/local/nginx-1.13.1/run/

        # create nginx.conf
        cat > /usr/local/nginx-1.13.1/conf/nginx.conf << "EOF"
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
        rm -rf /usr/local/nginx-1.13.1/conf/fastcgi.conf
        cat > /usr/local/nginx-1.13.1/conf/fastcgi.conf << "EOF"
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
        rm -rf /usr/local/nginx-1.13.1/conf/proxy.conf
        cat > /usr/local/nginx-1.13.1/conf/proxy.conf << "EOF"
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
        
        # create localhost.conf for 'localhost'
        cat > /usr/local/nginx-1.13.1/conf.d/localhost.conf << "EOF"
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

        # create www.dq5rocks.com.conf for 'www.dq5rocks.com'
        cat > /usr/local/nginx-1.13.1/conf.d/www.dq5rocks.com.conf << "EOF"
server {
         listen 80;
         server_name dq5rocks.com;
         return 301 http://www.dq5rocks.com$request_uri;
}

server {
         listen 80;
         server_name www.dq5rocks.com default_server;
         root /var/www/www.dq5rocks.com;

         # Logging --
         access_log  logs/www.dq5rocks.com.access.log;
         error_log  logs/www.dq5rocks.com.error.log notice;

         # serve static files directly
         location ~* ^.+.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt)$ {
               access_log        off;
               expires           max;
         }

         location ~ \.php$ {
               try_files $uri $uri/ =404;
               fastcgi_pass unix:/usr/local/php/var/run/php-fpm.sock;
         }

         # i have a webapp called test008 deployed on backend tomcat
         location ^~ /api/ {
               rewrite ^/api/(.*) /test008/$1  break;
               proxy_pass         http://localhost:8080;
         }

} 
EOF
        # test nginx.conf to see if syntax error exist
        CONFIG_SYNTAX_ERR="$(sbin/nginx -t -c conf/nginx.conf 2>&1 | grep 'test failed' | wc -l)"
        [ "$CONFIG_SYNTAX_ERR" -eq 1 ] && echo 'SYNTAX ERROR in nginx.conf' || echo 'nginx.conf is GOOD'

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
        create 644 root root
}
EOF

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
phpinfo();
?>
EOF

        # create index.html for www.dq5rocks.com
        mkdir -p /var/www/www.dq5rocks.com
        cat > /var/www/www.dq5rocks.com/index.html << "EOF"
<!DOCTYPE html>
<html>
<body>

<h1>www.dq5rocks.com</h1>
<p>Hello World!</p>

</body>
</html>
EOF

        # change files/directories onwer and group
        chown -R nginx:nginx /usr/local/nginx-1.13.1
        chown root:root /lib/systemd/system/nginx.service
        chown root:root /etc/logrotate.d/nginx 
        chown -R root:root /var/www

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
        wget -O php-7.1.5.tar.gz http://tw2.php.net/get/php-7.1.5.tar.gz/from/this/mirror
        MD5SUM_SHOULD_BE="b2ac302120d2eefd6cd9449790c45412"
        MD5SUM_COMPUTED="$(/usr/bin/md5sum ./php-7.1.5.tar.gz | cut -d ' ' -f 1)"
        [ "$MD5SUM_SHOULD_BE" != "$MD5SUM_COMPUTED" ] && echo "oops...md5 checksum doesnt match." && exit 2 || echo "md5 checksum matched."
        tar zxvf ./php-7.1.5.tar.gz
        chown -R root:root ./php-7.1.5
        rm -rf ./php-7.1.5.tar.gz
        cd ./php-7.1.5
        ./configure --prefix=/usr/local/php-7.1.5     \
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
                    --enable-wddx                     \
                    --enable-intl                     \
                    --with-curl                       \
                    --with-mcrypt                     \
                    --with-iconv                      \
                    --with-pspell                     \
                    --with-gd                         \
                    --enable-gd-native-ttf            \
                    --enable-gd-jis-conv              \
                    --with-openssl                    \
                    --with-ldap                       \
                    --with-imap=/usr/local/imap-2007f \
                    --with-imap-ssl                   \
                    --with-kerberos                   \
                    --with-mysqli=mysqlnd             \
                    --with-pdo-mysql=mysqlnd          \
                    --with-mysql-sock=/var/run/mysqld/mysqld.sock \
                    --with-libdir=/lib/x86_64-linux-gnu
        make
        #make test
        make install
        cp /usr/local/src/php-7.1.5/php.ini-production /usr/local/php-7.1.5/lib/php.ini
        cp /usr/local/php-7.1.5/etc/php-fpm.conf.default /usr/local/php-7.1.5/etc/php-fpm.conf

        # php.ini setting
        sed -i -- "/\[opcache\]/a zend_extension=/usr/local/php-7.1.5/lib/php/extensions/no-debug-non-zts-20160303/opcache.so" /usr/local/php-7.1.5/lib/php.ini
        sed -i -- "s|;opcache.enable=1|opcache.enable=1|g" /usr/local/php-7.1.5/lib/php.ini
        sed -i -- "s|;opcache.enable_cli=1|opcache.enable_cli=1|g" /usr/local/php-7.1.5/lib/php.ini
        sed -i -- "s|;opcache.memory_consumption=128|opcache.memory_consumption=128|g" /usr/local/php-7.1.5/lib/php.ini
        sed -i -- "s|;opcache.interned_strings_buffer=8|opcache.interned_strings_buffer=8|g" /usr/local/php-7.1.5/lib/php.ini
        sed -i -- "s|;opcache.max_accelerated_files=10000|opcache.max_accelerated_files=10000|g" /usr/local/php-7.1.5/lib/php.ini
        sed -i -- "s|;opcache.use_cwd=1|opcache.use_cwd=0|g" /usr/local/php-7.1.5/lib/php.ini
        sed -i -- "s|;opcache.validate_timestamps=1|opcache.validate_timestamps=0|g" /usr/local/php-7.1.5/lib/php.ini
        sed -i -- "s|;opcache.save_comments=1|opcache.save_comments=0|g" /usr/local/php-7.1.5/lib/php.ini
        sed -i -- "s|;opcache.enable_file_override=0|opcache.enable_file_override=1|g" /usr/local/php-7.1.5/lib/php.ini

        # php-fpm.conf setting
        sed -i -- '/^include/s/include/;include/' /usr/local/php-7.1.5/etc/php-fpm.conf
        sed -i -- 's|;pid = run/php-fpm.pid|pid = run/php-fpm.pid|g' /usr/local/php-7.1.5/etc/php-fpm.conf
        echo "[www]" >> /usr/local/php-7.1.5/etc/php-fpm.conf
        echo "listen = /usr/local/php-7.1.5/var/run/php-fpm.sock" >> /usr/local/php-7.1.5/etc/php-fpm.conf
        echo "listen.backlog = -1" >> /usr/local/php-7.1.5/etc/php-fpm.conf
        echo "listen.owner = nginx" >> /usr/local/php-7.1.5/etc/php-fpm.conf
        echo "listen.group = nginx" >> /usr/local/php-7.1.5/etc/php-fpm.conf
        echo "listen.mode=0660" >> /usr/local/php-7.1.5/etc/php-fpm.conf
        echo "user = nginx" >> /usr/local/php-7.1.5/etc/php-fpm.conf
        echo "group = nginx" >> /usr/local/php-7.1.5/etc/php-fpm.conf
        echo "pm = dynamic" >> /usr/local/php-7.1.5/etc/php-fpm.conf
        echo "pm.max_children = 20" >> /usr/local/php-7.1.5/etc/php-fpm.conf
        echo "pm.start_servers = 10" >> /usr/local/php-7.1.5/etc/php-fpm.conf
        echo "pm.min_spare_servers = 5" >> /usr/local/php-7.1.5/etc/php-fpm.conf
        echo "pm.max_spare_servers = 20" >> /usr/local/php-7.1.5/etc/php-fpm.conf

        # setup logrotate
cat > /etc/logrotate.d/php-fpm << EOF
/usr/local/php/var/log/*.log {
        weekly
        rotate 12
        compress
        delaycompress
        missingok
        notifempty
        create 644 root root
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
        chown -R nginx:nginx /usr/local/php-7.1.5
        chown root:root /etc/logrotate.d/php-fpm
        chmod 644 /etc/logrotate.d/php-fpm
        chown root:root /lib/systemd/system/php7.0-fpm.service
        chmod 644 /lib/systemd/system/php7.0-fpm.service

}

install_phpmyadmin() {
        [ -d "/var/www/localhost/phpmyadmin/" ] && echo "seems like phpmyadmin already installed." && exit 1 || echo "ready to install phpmyadmin."
        cd /var/www/localhost/
        wget https://files.phpmyadmin.net/phpMyAdmin/4.7.1/phpMyAdmin-4.7.1-all-languages.tar.gz.sha256
        wget https://files.phpmyadmin.net/phpMyAdmin/4.7.1/phpMyAdmin-4.7.1-all-languages.tar.gz
        SHA256SUM_IN_FILE="$(cat ./phpMyAdmin-4.7.1-all-languages.tar.gz.sha256 | cut -d " " -f 1)"
        SHA256SUM_COMPUTED="$(/usr/bin/sha256sum ./phpMyAdmin-4.7.1-all-languages.tar.gz | cut -d " " -f 1)"
        [ "$SHA256SUM_IN_FILE" != "$SHA256SUM_COMPUTED" ] && echo "oops...sha256 checksum doesnt match." && exit 2 || echo "sha256 checksum matched."
        tar zxvf ./phpMyAdmin-4.7.1-all-languages.tar.gz
        rm -rf ./phpMyAdmin-4.7.1-all-languages.tar.gz*
	mv phpMyAdmin-4.7.1-all-languages phpmyadmin
        cd ./phpmyadmin/
        cat > /var/www/localhost/phpmyadmin/config.inc.php << "EOF"
<?php
// use here a value of your choice at least 32 chars long
$cfg['blowfish_secret'] = 'HeAxpLA4i[gQ;E8CY2jN2}6M2.752x.K';

$i=0;
$i++;
$cfg['Servers'][$i]['auth_type'] = 'cookie';
$cfg['Servers'][$i]['host'] = 'localhost';
$cfg['Servers'][$i]['port'] = '3306';
$cfg['Servers'][$i]['controluser'] = 'pmauser';
$cfg['Servers'][$i]['controlpass'] = 'pmapassword';
?>
EOF
        cat > /tmp/create_pma_control_user.sql << "EOF"
drop database if exists phpmyadmin;
create user 'pmauser'@'localhost' identified by 'pmapassword';
create user 'pmauser'@'127.0.0.1' identified by 'pmapassword';
grant all on phpmyadmin.* to 'pmauser'@'localhost';
grant all on phpmyadmin.* to 'pmauser'@'127.0.0.1';
flush privileges;
EOF
        chown root:root /tmp/create_pma_control_user.sql
        mysql -h localhost --port 3306 -u root -p$MYSQL_ROOT_PASSWD < /tmp/create_pma_control_user.sql
        rm -rf /tmp/create_pma_control_user.sql
}

install_wordpress() {
        [ -d "/var/www/www.dq5rocks.com/wordpress/" ] && echo "seems like wordpress already installed." && exit 1 || echo "ready to install wordpress."
        cd /var/www/www.dq5rocks.com/
        wget https://wordpress.org/wordpress-4.7.5.tar.gz.md5
        wget https://wordpress.org/wordpress-4.7.5.tar.gz
        MD5SUM_IN_FILE="$(cat ./wordpress-4.7.5.tar.gz.md5)"
        MD5SUM_COMPUTED="$(/usr/bin/md5sum ./wordpress-4.7.5.tar.gz | cut -d " " -f 1)"
        [ "$MD5SUM_IN_FILE" != "$MD5SUM_COMPUTED" ] && echo "oops...md5 checksum doesnt match." && exit 2 || echo "md5 checksum matched."
        tar zxvf ./wordpress-4.7.5.tar.gz
        rm -rf ./wordpress-4.7.5.tar.gz*
        cd ./wordpress
        cat > wp-config.php << "EOF"
<?php
define('DB_NAME', 'wpdb');
define('DB_USER', 'wpuser');
define('DB_PASSWORD', 'wppassword');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');

EOF
        wget -O salt.txt https://api.wordpress.org/secret-key/1.1/salt/
        cat ./salt.txt >> wp-config.php
        rm -rf ./salt.txt
        cat >> wp-config.php << "EOF"
$table_prefix  = 'wp_';
define('WP_DEBUG', false);
if ( !defined('ABSPATH') )
	define('ABSPATH', dirname(__FILE__) . '/');
require_once(ABSPATH . 'wp-settings.php');
EOF

        cat > /tmp/create_wp_db_and_user.sql << "EOF"
drop database if exists wpdb;
create database wpdb;
create user 'wpuser'@'localhost' identified by 'wppassword';
create user 'wpuser'@'127.0.0.1' identified by 'wppassword';
grant all on wpdb.* to 'wpuser'@'localhost';
grant all on wpdb.* to 'wpuser'@'127.0.0.1';
flush privileges;
EOF
        mysql -h localhost --port 3306 -u root -p$MYSQL_ROOT_PASSWD < /tmp/create_wp_db_and_user.sql
        rm -rf /tmp/create_wp_db_and_user.sql
}

start_nginx_service() {

        # set DocumentRoot owner and group
        chown -R nginx:nginx /var/www/localhost
        chown -R nginx:nginx /var/www/www.dq5rocks.com

        systemctl daemon-reload

        # start nginx.service and make it as autostart service
        OLD_NGINX_PROCESS_EXISTED="$(netstat -anp | grep nginx | wc -l)"
        if [ "$OLD_NGINX_PROCESS_EXISTED" -gt 0 ]; then
             systemctl stop nginx.service
        fi
        if [ -L /usr/local/nginx ] && [ -d /usr/local/nginx ]; then
             rm -rf /usr/local/nginx
        fi
        ln -s /usr/local/nginx-1.13.1 /usr/local/nginx
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

        ln -s /usr/local/php-7.1.5 /usr/local/php
        systemctl enable php7.0-fpm.service
        systemctl start php7.0-fpm.service
        systemctl status php7.0-fpm.service
}

main() {
	unlock_apt_bala_bala
	update_system
	sync_system_time
	#remove_previous_install
	install_prerequisite
        install_nginx
        install_imap2007f
	install_phpfpm
        install_phpmyadmin
	install_wordpress
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

