#!/bin/bash
#
# This script will install apache2 web server with php support
# (tested on Ubuntu mate 16.04/16.10/17.04)
#
# All of the commands used here were inspired by these articles : 
# https://www.digitalocean.com/community/tutorials/how-to-install-linux-apache-mysql-php-lamp-stack-on-ubuntu-16-04
# https://www.digitalocean.com/community/tutorials/how-to-create-a-self-signed-ssl-certificate-for-apache-in-ubuntu-16-04
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

install_apache2_and_php() {
        apt-get update
        APACHE2_INSTALL="$(dpkg --get-selections | grep apache2)"
        if [ -z "$APACHE2_INSTALL" ]; then
               apt-get install -y apache2
        fi

        PHP_INSTALL="$(dpkg --get-selections | grep php)"
        if [ -z "$PHP_INSTALL" ]; then
               apt-get install -y php libapache2-mod-php php-mcrypt php-mysql php7.0-mbstring
        fi
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

edit_config_file() {
        # /etc/apache2/apache2.conf
        if [ ! -f /etc/apache2/apache2.conf.default ]; then
               cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.default
        fi
        ###SERVER_IP="$(/sbin/ifconfig eth0 | grep -A 1 'inet' | head -1 | cut -d ' ' -f 10)"
	SERVER_IP="$(/sbin/ip addr show eth0 | grep 'dynamic eth0' | tr -s ' ' | cut -d ' ' -f 3 | cut -d '/' -f 1)"
        echo "ServerName $SERVER_IP" >> /etc/apache2/apache2.conf
        echo "#Listen 0.0.0.0:80" >> /etc/apache2/apache2.conf
        echo "Listen $SERVER_IP:80" >> /etc/apache2/apache2.conf

        # /etc/apache2/mods-enabled/dir.conf is a symbolic link to /etc/apache2/mods-available/dir.conf
        sed -i -- 's|index.html index.cgi index.pl index.php|index.php index.html index.cgi index.pl|g' /etc/apache2/mods-available/dir.conf


        # ssl related params
        cat > /etc/apache2/conf-available/ssl-params.conf << "EOF"
# from https://cipherli.st/
# and https://raymii.org/s/tutorials/Strong_SSL_Security_On_Apache2.html

SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH
SSLProtocol All -SSLv2 -SSLv3
SSLHonorCipherOrder On
# Disable preloading HSTS for now.  You can use the commented out header line that includes
# the "preload" directive if you understand the implications.
#Header always set Strict-Transport-Security "max-age=63072000; includeSubdomains; preload"
Header always set Strict-Transport-Security "max-age=63072000; includeSubdomains"
Header always set X-Frame-Options DENY
Header always set X-Content-Type-Options nosniff
# Requires Apache >= 2.4
SSLCompression off 
SSLSessionTickets Off
SSLUseStapling off 
#SSLStaplingCache "shmcb:logs/stapling-cache(150000)"

SSLOpenSSLConfCmd DHParameters "/etc/ssl/certs/dhparam.pem"
EOF

        # redirect 80(http) to 443(https)
        cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.bak
        cat > /etc/apache2/sites-available/000-default.conf << "EOF"
<VirtualHost *:80>
   ServerName www.dq5rocks.com
   ServerAlias dq5rocks.com
   Redirect / https://www.dq5rocks.com/
</VirtualHost>
EOF

        # another virtual host www.bubu.com
       cat > /etc/apache2/sites-available/001-bubu.conf << "EOF"
<VirtualHost *:80>
    ServerAdmin admin@bubu.com
    ServerName www.bubu.com
    ServerAlias bubu.com
    DocumentRoot /var/www/www.bubu.com
    <Directory /var/www/www.bubu.com>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>

EOF

        # Modify the Default Apache SSL Virtual Host File
        cp /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf.bak
        cat > /etc/apache2/sites-available/default-ssl.conf << "EOF"
<IfModule mod_ssl.c>
        <VirtualHost _default_:443>
                ServerAdmin admin@dq5rocks.com
                ServerName www.dq5rocks.com

                DocumentRoot /var/www/www.dq5rocks.com

                ErrorLog ${APACHE_LOG_DIR}/error.log
                CustomLog ${APACHE_LOG_DIR}/access.log combined

                SSLEngine on

                SSLCertificateFile      /etc/ssl/certs/apache-selfsigned.crt
                SSLCertificateKeyFile /etc/ssl/private/apache-selfsigned.key

                <FilesMatch "\.(cgi|shtml|phtml|php)$">
                                SSLOptions +StdEnvVars
                </FilesMatch>
                <Directory /usr/lib/cgi-bin>
                                SSLOptions +StdEnvVars
                </Directory>

                <Directory /var/www/www.dq5rocks.com>
                    Options FollowSymLinks
                    AllowOverride None
                    Require all granted
                </Directory>

                <Directory /var/www/www.dq5rocks.com/phpmyadmin>
                   <RequireAll>
                      Require ip 127.0.0.1 10.2.2
                   </RequireAll>
                </Directory>

                BrowserMatch "MSIE [2-6]" \
                               nokeepalive ssl-unclean-shutdown \
                               downgrade-1.0 force-response-1.0

        </VirtualHost>
</IfModule>
EOF

        # create empty directories
        mkdir -p /var/www/www.dq5rocks.com
        mkdir -p /var/www/www.bubu.com

        # turn on the modules
        a2enmod ssl
        a2enmod headers

        # turn on config
        a2enconf ssl-params

        # turn on the sites
        a2ensite 000-default
        a2ensite 001-bubu
        a2ensite default-ssl

        # test to see if any syntax error in config file
        apache2ctl configtest

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

restart_apache2_service() {
        chown -R www-data:www-data /var/www/www.dq5rocks.com/
        chown -R www-data:www-data /var/www/www.bubu.com/
        systemctl enable apache2.service
        systemctl restart apache2.service
        systemctl status apache2.service
}

main() {
        unlock_apt_bala_bala
        update_system
        sync_system_time
        remove_previous_install
	install_apache2_and_php
	create_self_signed_ssl_cert_and_key
	edit_config_file
        install_phpmyadmin
	install_wordpress
	restart_apache2_service
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

