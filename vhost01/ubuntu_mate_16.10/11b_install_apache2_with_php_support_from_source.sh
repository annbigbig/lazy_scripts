#!/bin/bash
#
# This script will install apache2 web server with php support from source
# (tested on Ubuntu mate 16.04/16.10/17.04)
#
# All of the commands used here were inspired by these articles : 
#
# http://www.linuxfromscratch.org/blfs/view/svn/general/php.html
# https://ivopetkov.com/b/install-php-and-apache-from-source/
# https://ma.ttias.be/apache-2-4-proxypass-for-php-taking-precedence-over-filesfilesmatch-in-htaccess/
# https://github.com/phpbrew/phpbrew/issues/861
# https://www.digitalocean.com/community/tutorials/how-to-install-linux-apache-mysql-php-lamp-stack-on-ubuntu-16-04
# https://www.digitalocean.com/community/tutorials/how-to-create-a-self-signed-ssl-certificate-for-apache-in-ubuntu-16-04
# http://forum.directadmin.com/showthread.php?t=54955
# https://github.com/scottcorgan/bucket-list/issues/2
#
# specify MYSQL_ROOT_PASSWD for generating phpmyadmin db user
#####################
MYSQL_ROOT_PASSWD="root"
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
# so if you are so sure that you are upgrading APACHE2 HTTPD from previously source installation
# and you want to upgrade APACHE2 HTTPD seamlessly without any server downtime
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
        if [ -d /lib/systemd/system/apache2.service.d ]; then
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
        # apache2 httpd will require these
        apt-get update
        apt-get install -y libpcre3 libpcre3-dev
        # php-fpm will requre these
        apt-get install -y libldap2-dev libtool-bin libzip-dev lbzip2 libxml2 libxml2-dev re2c libreadline-dev libexpat1-dev
        apt-get install -y libbz2-dev libjpeg-dev libxpm-dev libgmp-dev libgmp3-dev libxpm-dev libpspell-dev librecode-dev
        apt-get install -y libcurl3 libcurl3-gnutls libcurl4-openssl-dev pkg-config libssl-dev libgdbm-dev libpng-dev libmcrypt-dev
	#apt-get install -y libmariadb-dev* libdb-dev libdb4.8

        # need to do this on ubuntu 17.04
        if [ ! -e "/usr/include/curl" ] && [ -e "/usr/include/x86_64-linux-gnu/curl" ]; then
               ln -s /usr/include/x86_64-linux-gnu/curl /usr/include/curl
        fi
}

install_apache2() {

        # create necessary user and group
        groupadd -g 150 apache
        useradd -u 150 -d /var/www/html -g apache -s /bin/false apache

        # create directories
        mkdir -p /var/www/html

        # download the source tar.gz and their md5 checksum, verify their integrity
        cd /usr/local/src
        wget http://ftp.tc.edu.tw/pub/Apache//httpd/httpd-2.4.27.tar.gz
        wget https://www.apache.org/dist/httpd/httpd-2.4.27.tar.gz.md5
        MD5SUM_1="$(cat ./httpd-2.4.27.tar.gz.md5 | cut -d ' ' -f 1)"
        MD5SUM_1_COMPUTED="$(md5sum ./httpd-2.4.27.tar.gz | cut -d ' ' -f 1)"
        [ "$MD5SUM_1" != "$MD5SUM_1_COMPUTED" ] && echo "httpd-2.4.27.tar.gz md5 checksum doesnt match." && exit 2 || echo "checksum matched."
        wget http://ftp.tc.edu.tw/pub/Apache//apr/apr-1.6.2.tar.gz
        wget http://www.apache.org/dist/apr/apr-1.6.2.tar.gz.md5
        MD5SUM_2="$(cat ./apr-1.6.2.tar.gz.md5 | cut -d ' ' -f 1)"
        MD5SUM_2_COMPUTED="$(md5sum ./apr-1.6.2.tar.gz | cut -d ' ' -f 1)"
        [ "$MD5SUM_2" != "$MD5SUM_2_COMPUTED" ] && echo "apr-1.6.2.tar.gz md5 checksum doesnt match." && exit 2 || echo "apr checksum matched."
        wget http://ftp.tc.edu.tw/pub/Apache//apr/apr-util-1.6.0.tar.gz
        wget http://www.apache.org/dist/apr/apr-util-1.6.0.tar.gz.md5
        MD5SUM_3="$(cat ./apr-util-1.6.0.tar.gz.md5 | cut -d ' ' -f 1)"
        MD5SUM_3_COMPUTED="$(md5sum ./apr-util-1.6.0.tar.gz | cut -d ' ' -f 1)"
        [ "$MD5SUM_3" != "$MD5SUM_3_COMPUTED" ] && echo "apr-util-1.6.0.tar.gz md5 checksum doesnt match." && exit 2 || echo "util checksum matched."

        # extract all of tar.gz and configure it
        tar zxvf ./httpd-2.4.27.tar.gz
        mv ./apr-1.6.2.tar.gz /usr/local/src/httpd-2.4.27/srclib
        mv ./apr-util-1.6.0.tar.gz /usr/local/src/httpd-2.4.27/srclib
        tar zxvf /usr/local/src/httpd-2.4.27/srclib/apr-1.6.2.tar.gz -C /usr/local/src/httpd-2.4.27/srclib
        mv /usr/local/src/httpd-2.4.27/srclib/apr-1.6.2 /usr/local/src/httpd-2.4.27/srclib/apr
        tar zxvf /usr/local/src/httpd-2.4.27/srclib/apr-util-1.6.0.tar.gz -C /usr/local/src/httpd-2.4.27/srclib
        mv /usr/local/src/httpd-2.4.27/srclib/apr-util-1.6.0 /usr/local/src/httpd-2.4.27/srclib/apr-util
        cd /usr/local/src
        rm -rf httpd-*.tar.gz* apr-*.tar.gz*
        cd /usr/local/src/httpd-2.4.27/srclib
        rm -rf apr-*.tar.gz*
        chown -R root:root /usr/local/src/httpd-2.4.27
        cd /usr/local/src/httpd-2.4.27
        ./configure --prefix=/usr/local/apache-2.4.27 --enable-so
        make
        make install

	# get server ip address
	###SERVER_IP="$(/sbin/ifconfig eth0 | grep -A 1 'inet' | head -1 | cut -d ' ' -f 10)"
	SERVER_IP="$(/sbin/ip addr show eth0 | grep 'dynamic eth0' | tr -s ' ' | cut -d ' ' -f 3 | cut -d '/' -f 1)"

        # configure httpd.conf
        sed -i -- "s|ServerAdmin you@example.com|ServerAdmin admin@dq5rocks.com|g" /usr/local/apache-2.4.27/conf/httpd.conf
        sed -i -- "s|#ServerName www.example.com:80|ServerName $SERVER_IP|g" /usr/local/apache-2.4.27/conf/httpd.conf
        #sed -i -- "s|DocumentRoot \"/usr/local/apache-2.4.27/htdocs\"|DocumentRoot \"/var/www/www.dq5rocks.com\"|g" /usr/local/apache-2.4.27/conf/httpd.conf
        #sed -i -- "s|<Directory \"/usr/local/apache-2.4.27/htdocs\">|<Directory \"/var/www/www.dq5rocks.com\">|g" /usr/local/apache-2.4.27/conf/httpd.conf
        sed -i -- "/^DocumentRoot \"\/usr\/local\/apache-2.4.27\/htdocs\"/,+27 s/^/#/" /usr/local/apache-2.4.27/conf/httpd.conf

        sed -i -- "s|DirectoryIndex index.html|DirectoryIndex index.php index.html index.htm|g" /usr/local/apache-2.4.27/conf/httpd.conf
        sed -i -- "/<Directory \"\/usr\/local\/apache-2.4.27\/cgi-bin\">/,+4 s/^/#/" /usr/local/apache-2.4.27/conf/httpd.conf
        sed -i -- "s|#LoadModule proxy_module modules/mod_proxy.so|LoadModule proxy_module modules/mod_proxy.so|g" /usr/local/apache-2.4.27/conf/httpd.conf
        sed -i -- "s|#LoadModule ssl_module modules/mod_ssl.so|LoadModule ssl_module modules/mod_ssl.so|g" /usr/local/apache-2.4.27/conf/httpd.conf
	sed -i -- "s|#LoadModule socache_shmcb_module modules/mod_socache_shmcb.so|LoadModule socache_shmcb_module modules/mod_socache_shmcb.so|g" /usr/local/apache-2.4.27/conf/httpd.conf
        sed -i -- "s|#LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so|LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so|g" /usr/local/apache-2.4.27/conf/httpd.conf
        sed -i -- "s|#Include conf/extra/httpd-ssl.conf|Include conf/extra/httpd-ssl.conf|g" /usr/local/apache-2.4.27/conf/httpd.conf
        sed -i -- "s|#Include conf/extra/httpd-vhosts.conf|Include conf/extra/httpd-vhosts.conf|g" /usr/local/apache-2.4.27/conf/httpd.conf
        sed -i -- "s|User daemon|User apache|g" /usr/local/apache-2.4.27/conf/httpd.conf
        sed -i -- "s|Group daemon|Group apache|g" /usr/local/apache-2.4.27/conf/httpd.conf
        echo '<FilesMatch \.php$>' >> /usr/local/apache-2.4.27/conf/httpd.conf
        echo '    SetHandler "proxy:fcgi://127.0.0.1:9000"' >> /usr/local/apache-2.4.27/conf/httpd.conf
        echo '</FilesMatch>' >> /usr/local/apache-2.4.27/conf/httpd.conf

        # configure conf/extra/httpd-ssl.conf
	cp /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf.bak
	sed -i -- "s/^SSLCipherSuite HIGH:MEDIUM:\!MD5:\!RC4:\!3DES/SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH/g" /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf
	sed -i -- "s/^SSLProxyCipherSuite HIGH:MEDIUM:\!MD5:\!RC4:\!3DES/SSLProxyCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH/g" /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf
	sed -i -- "s/^SSLProtocol all -SSLv3/SSLProtocol all -SSLv2 -SSLv3/g" /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf
	sed -i -- "s/^SSLProxyProtocol all -SSLv3/SSLProxyProtocol all -SSLv2 -SSLv3/g" /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf
	sed -i '/^SSLHonorCipherOrder on/ a \
\
# Disable preloading HSTS for now.  You can use the commented out header line that includes \
# the "preload" directive if you understand the implications. \
#Header always set Strict-Transport-Security "max-age=63072000; includeSubdomains; preload" \
Header always set Strict-Transport-Security "max-age=63072000; includeSubdomains" \
Header always set X-Frame-Options DENY \
Header always set X-Content-Type-Options nosniff \
# Requires Apache >= 2.4 \
SSLCompression off \
SSLSessionTickets Off \
SSLOpenSSLConfCmd DHParameters "/etc/ssl/certs/dhparam.pem" \
' /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf
	#sed -i -- "s/^#SSLUseStapling On/SSLUseStapling On/g" /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf
	sed -i -- "s/^#SSLUseStapling On/SSLUseStapling off/g" /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf
	#sed -i -- "s/^#SSLStaplingCache \"shmcb:\/usr\/local\/apache-2.4.27\/logs\/ssl_stapling(32768)\"/SSLStaplingCache \"shmcb:\/usr\/local\/apache-2.4.27\/logs\/ssl_stapling(150000)\"/g" /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf
	sed -i -- "s/^DocumentRoot \"\/usr\/local\/apache-2.4.27\/htdocs\"/DocumentRoot \"\/var\/www\/www.dq5rocks.com\"/g" /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf
	sed -i '/^DocumentRoot \"\/var\/www\/www.dq5rocks.com\"/ a \
<Directory "/var/www/www.dq5rocks.com"> \
    Options FollowSymLinks \
    AllowOverride None \
    Require all granted \
</Directory> \
\
<Directory "/var/www/www.dq5rocks.com/phpmyadmin"> \
    <RequireAll> \
         Require ip 127.0.0.1 10.2.2 \
    </RequireAll> \
</Directory> \
' /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf
	sed -i -- "s/^ServerName www.example.com:443/ServerName www.dq5rocks.com:443/g" /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf
	sed -i -- "s/^ServerAdmin you@example.com/ServerAdmin admin@dq5rocks.com/g" /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf
	sed -i -- "s/^#SSLEngine on/SSLEngine on/g" /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf
        sed -i -- "/^CustomLog/,+1 s/^/#/" /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf
	sed -i '/^<\/VirtualHost>/i CustomLog "/usr/local/apache-2.4.27/logs/access_log" combined' /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf
	sed -i -- "s/^SSLCertificateFile \"\/usr\/local\/apache-2.4.27\/conf\/server.crt\"/SSLCertificateFile \"\/etc\/ssl\/certs\/apache-selfsigned.crt\"/g" /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf
	sed -i -- "s/^SSLCertificateKeyFile \"\/usr\/local\/apache-2.4.27\/conf\/server.key\"/SSLCertificateKeyFile \"\/etc\/ssl\/private\/apache-selfsigned.key\"/g" /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf
	sed -i -- "s|BrowserMatch \"MSIE \[2-5\]\"|BrowserMatch \"MSIE \[2-6\]\"|g" /usr/local/apache-2.4.27/conf/extra/httpd-ssl.conf

	# configure conf/extra/httpd-vhosts.conf
	cp /usr/local/apache-2.4.27/conf/extra/httpd-vhosts.conf /usr/local/apache-2.4.27/conf/extra/httpd-vhosts.conf.bak
	cat > /usr/local/apache-2.4.27/conf/extra/httpd-vhosts.conf << "EOF"
<VirtualHost *:80>
     ServerName www.dq5rocks.com
     ServerAlias dq5rocks.com
     Redirect / https://www.dq5rocks.com/
</VirtualHost>

<VirtualHost *:80>
     ServerAdmin admin@bubu.com
     DocumentRoot "/var/www/www.bubu.com"
     <Directory "/var/www/www.bubu.com">
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
     </Directory>
     ServerName www.bubu.com
     ServerAlias bubu.com
     ErrorLog "/usr/local/apache-2.4.27/logs/error_log"
     CustomLog "/usr/local/apache-2.4.27/logs/access_log" combined
</VirtualHost>
								   
EOF

        # change owner/group for installation directory
        chown -R apache:apache /usr/local/apache-2.4.27

        # create empty directories for web-sites
	mkdir -p /var/www/www.dq5rocks.com
        mkdir -p /var/www/www.bubu.com

        # leave a info.php and index.html at root directory of website
        cat > /var/www/www.dq5rocks.com/info.php << "EOF"
<?php
phpinfo();
?>
EOF

        cat > /var/www/www.dq5rocks.com/index.html << "EOF"
<!DOCTYPE html>
<html>
<body>

<h1>www.dq5rocks.com</h1>
<p>Hello World!</p>

</body>
</html>
EOF

        cat > /var/www/www.bubu.com/info.php << "EOF"
<?php
phpinfo();
?>
EOF

        cat > /var/www/www.bubu.com/index.html << "EOF"
<!DOCTYPE html>
<html>
<body>

<h1>www.bubu.com</h1>
<p>Hello World! bu</p>

</body>
</html>
EOF

        # config test
        /usr/local/apache-2.4.27/bin/apachectl configtest

        # setup logrotate
	cat > /etc/logrotate.d/apache2 << "EOF"
/usr/local/apache2/logs/*_log {
        weekly
        rotate 12
        compress
        delaycompress
        missingok
        notifempty
        create 644 root root
}
EOF
        chown root:root /etc/logrotate.d/apache2
        chmod 644 /etc/logrotate.d/apache2

        # create systemd unit file
        cat > /lib/systemd/system/apache2.service << "EOF"
[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
Environment=APACHE_STARTED_BY_SYSTEMD=true
ExecStart=/usr/local/apache2/bin/apachectl start
ExecStop=/usr/local/apache2/bin/apachectl stop
ExecReload=/usr/local/apache2/bin/apachectl graceful
PrivateTmp=true
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

}

create_self_signed_ssl_cert_and_key() {
        /usr/bin/openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt
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
        /usr/bin/openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
}


install_phpfpm() {

        # download the source tar.gz, extract it then configure it
        cd /usr/local/src
        wget -O php-7.1.8.tar.gz http://jp2.php.net/get/php-7.1.8.tar.gz/from/this/mirror
        SHA256SUM_SHOULD_BE="63517b3264f7cb17fb58e1ce60a6cd8903160239b7cf568d52024e9cf4d6cb04"
        SHA256SUM_COMPUTED="$(/usr/bin/sha256sum ./php-7.1.8.tar.gz | cut -d " " -f 1)"
        [ "$SHA256SUM_SHOULD_BE" != "$SHA256SUM_COMPUTED" ] && echo "oops...sha256 checksum doesnt match." && exit 2 || echo "sha256 checksum matched."
        tar zxvf ./php-7.1.8.tar.gz
        chown -R root:root ./php-7.1.8
        rm -rf ./php-7.1.8.tar.gz
        cd ./php-7.1.8
        ./configure --prefix=/usr/local/php-7.1.8     \
                    --enable-fpm                      \
                    --enable-opcache                  \
                    --with-fpm-user=apache            \
                    --with-fpm-group=apache           \
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
                    --with-mysqli=mysqlnd             \
                    --with-pdo-mysql=mysqlnd          \
                    --with-mysql-sock=/var/run/mysqld/mysqld.sock \
                    --with-libdir=lib/x86_64-linux-gnu
        make
        #make test
        make install
        cp /usr/local/src/php-7.1.8/php.ini-production /usr/local/php-7.1.8/lib/php.ini
        cp /usr/local/php-7.1.8/etc/php-fpm.conf.default /usr/local/php-7.1.8/etc/php-fpm.conf

        # php.ini setting
        sed -i -- "/\[opcache\]/a zend_extension=/usr/local/php-7.1.8/lib/php/extensions/no-debug-non-zts-20160303/opcache.so" /usr/local/php-7.1.8/lib/php.ini
        sed -i -- "s|;opcache.enable=1|opcache.enable=1|g" /usr/local/php-7.1.8/lib/php.ini
        sed -i -- "s|;opcache.enable_cli=1|opcache.enable_cli=1|g" /usr/local/php-7.1.8/lib/php.ini
        sed -i -- "s|;opcache.memory_consumption=128|opcache.memory_consumption=128|g" /usr/local/php-7.1.8/lib/php.ini
        sed -i -- "s|;opcache.interned_strings_buffer=8|opcache.interned_strings_buffer=8|g" /usr/local/php-7.1.8/lib/php.ini
        sed -i -- "s|;opcache.max_accelerated_files=10000|opcache.max_accelerated_files=10000|g" /usr/local/php-7.1.8/lib/php.ini
        sed -i -- "s|;opcache.use_cwd=1|opcache.use_cwd=0|g" /usr/local/php-7.1.8/lib/php.ini
        sed -i -- "s|;opcache.validate_timestamps=1|opcache.validate_timestamps=0|g" /usr/local/php-7.1.8/lib/php.ini
        sed -i -- "s|;opcache.save_comments=1|opcache.save_comments=0|g" /usr/local/php-7.1.8/lib/php.ini
        sed -i -- "s|;opcache.enable_file_override=0|opcache.enable_file_override=1|g" /usr/local/php-7.1.8/lib/php.ini

        # php-fpm.conf setting
        sed -i -- '/^include/s/include/;include/' /usr/local/php-7.1.8/etc/php-fpm.conf
        sed -i -- 's|;pid = run/php-fpm.pid|pid = run/php-fpm.pid|g' /usr/local/php-7.1.8/etc/php-fpm.conf
        echo "[www]" >> /usr/local/php-7.1.8/etc/php-fpm.conf
        echo "user = apache" >> /usr/local/php-7.1.8/etc/php-fpm.conf
        echo "group = apache" >> /usr/local/php-7.1.8/etc/php-fpm.conf
        echo "listen = 127.0.0.1:9000" >> /usr/local/php-7.1.8/etc/php-fpm.conf
        echo "pm = dynamic" >> /usr/local/php-7.1.8/etc/php-fpm.conf
        echo "pm.max_children = 20" >> /usr/local/php-7.1.8/etc/php-fpm.conf
        echo "pm.start_servers = 10" >> /usr/local/php-7.1.8/etc/php-fpm.conf
        echo "pm.min_spare_servers = 5" >> /usr/local/php-7.1.8/etc/php-fpm.conf
        echo "pm.max_spare_servers = 20" >> /usr/local/php-7.1.8/etc/php-fpm.conf
        chown -R apache:apache /usr/local/php-7.1.8

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
        chown root:root /etc/logrotate.d/php-fpm
        chmod 644 /etc/logrotate.d/php-fpm

        # create systemd unit file
        cat > /lib/systemd/system/php7.0-fpm.service << "EOF"
[Unit]
Description=PHP FastCGI process manager
After=local-fs.target network.target apache2.service

[Service]
ExecStart=/usr/local/php/sbin/php-fpm --fpm-config /usr/local/php/etc/php-fpm.conf
Type=forking

[Install]
WantedBy=multi-user.target
EOF

}

install_phpmyadmin() {
        [ -d "/var/www/www.dq5rocks.com/phpmyadmin/" ] && echo "seems like phpmyadmin already installed." && exit 1 || echo "ready to install phpmyadmin."
        cd /var/www/www.dq5rocks.com/
        wget https://files.phpmyadmin.net/phpMyAdmin/4.7.4/phpMyAdmin-4.7.4-all-languages.tar.gz.sha256
        wget https://files.phpmyadmin.net/phpMyAdmin/4.7.4/phpMyAdmin-4.7.4-all-languages.tar.gz
        SHA256SUM_IN_FILE="$(cat ./phpMyAdmin-4.7.4-all-languages.tar.gz.sha256 | cut -d " " -f 1)"
        SHA256SUM_COMPUTED="$(/usr/bin/sha256sum ./phpMyAdmin-4.7.4-all-languages.tar.gz | cut -d " " -f 1)"
        [ "$SHA256SUM_IN_FILE" != "$SHA256SUM_COMPUTED" ] && echo "oops...sha256 checksum doesnt match." && exit 2 || echo "sha256 checksum matched."
        tar zxvf ./phpMyAdmin-4.7.4-all-languages.tar.gz
        rm -rf ./phpMyAdmin-4.7.4-all-languages.tar.gz*
	mv phpMyAdmin-4.7.4-all-languages phpmyadmin
        cd ./phpmyadmin/
        cat > /var/www/www.dq5rocks.com/phpmyadmin/config.inc.php << "EOF"
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
        wget https://wordpress.org/wordpress-4.8.1.tar.gz.md5
        wget https://wordpress.org/wordpress-4.8.1.tar.gz
        MD5SUM_IN_FILE="$(cat ./wordpress-4.8.1.tar.gz.md5)"
        MD5SUM_COMPUTED="$(/usr/bin/md5sum ./wordpress-4.8.1.tar.gz | cut -d " " -f 1)"
        [ "$MD5SUM_IN_FILE" != "$MD5SUM_COMPUTED" ] && echo "oops...md5 checksum doesnt match." && exit 2 || echo "md5 checksum matched."
        tar zxvf ./wordpress-4.8.1.tar.gz
        rm -rf ./wordpress-4.8.1.tar.gz*
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

start_apache2_service() {

        # set owner and group for DocumentRoot
        chown root:root /var/www
        chown -R apache:apache /var/www/www.dq5rocks.com
        chown -R apache:apache /var/www/www.bubu.com

        #
        systemctl daemon-reload

        # start apache2.service and make it as autostart service
        OLD_APACHE2_PROCESS_EXISTED="$(netstat -anp | grep httpd | wc -l)"
        if [ "$OLD_APACHE2_PROCESS_EXISTED" -gt 0 ]; then
             systemctl stop apache2.service
        fi
        if [ -L /usr/local/apache2 ] && [ -d /usr/local/apache2 ]; then
             rm -rf /usr/local/apache2
        fi

        ln -s /usr/local/apache-2.4.27 /usr/local/apache2
        systemctl enable apache2.service
        systemctl start apache2.service
        systemctl status apache2.service

        # start php-fpm and make it as autostart service
        OLD_PHPFPM_PROCESS_EXISTED="$(netstat -anp | grep php-fpm | wc -l)"
        if [ "$OLD_PHPFPM_PROCESS_EXISTED" -gt 0 ]; then
             systemctl stop php7.0-fpm.service
        fi
        if [ -L /usr/local/php ] && [ -d /usr/local/php ]; then
             rm -rf /usr/local/php
        fi

        ln -s /usr/local/php-7.1.8 /usr/local/php
        systemctl enable php7.0-fpm.service
        systemctl start php7.0-fpm.service
        systemctl status php7.0-fpm.service
}

main() {
        unlock_apt_bala_bala
        update_system
        sync_system_time
	remove_previous_install
	install_prerequisite
	create_self_signed_ssl_cert_and_key
	install_apache2
	install_phpfpm
        install_phpmyadmin
	install_wordpress
	start_apache2_service
}

echo -e "This script will install apache2 web server with php support \n"
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

