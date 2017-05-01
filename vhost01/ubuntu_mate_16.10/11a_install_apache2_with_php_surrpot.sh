#!/bin/bash
#
# This script will install apache2 web server with php support
# (tested on Ubuntu mate 16.10/17.04)
#
# All of the commands used here were inspired by this article : 
# https://www.digitalocean.com/community/tutorials/how-to-install-linux-apache-mysql-php-lamp-stack-on-ubuntu-16-04
#
# specify MYSQL_ROOT_PASSWD for generating phpmyadmin db user
#####################
MYSQL_ROOT_PASSWD="rootpass"
#####################

say_goodbye() {
	echo "goodbye everyone"
}

sync_system_time() {
        NTPDATE_INSTALL="$(dpkg --get-selections | grep ntpdate)"
        if [ -z "$NTPDATE_INSTALL" ]; then
                apt-get update
                apt-get install -y ntpdate
        fi
	        ntpdate -v pool.ntp.org
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

edit_config_file() {
        # /etc/apache2/apache2.conf
        if [ ! -f /etc/apache2/apache2.conf.default ]; then
               cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.default
        fi
        SERVER_IP="$(/sbin/ifconfig eth0 | grep -A 1 'inet' | head -1 | cut -d ' ' -f 10)"
        echo "ServerName $SERVER_IP" >> /etc/apache2/apache2.conf
        echo "#Listen 0.0.0.0:80" >> /etc/apache2/apache2.conf
        echo "Listen $SERVER_IP:80" >> /etc/apache2/apache2.conf

        # /etc/apache2/mods-enabled/dir.conf is a symbolic link to /etc/apache2/mods-available/dir.conf
        sed -i -- 's|index.html index.cgi index.pl index.php|index.php index.html index.cgi index.pl|g' /etc/apache2/mods-available/dir.conf

        # virtual host config for phpmyadmin
        cat > /etc/apache2/sites-available/dq5rocks.com.conf << "EOF"
<VirtualHost *:80>
    ServerAdmin admin@dq5rocks.com
    ServerName dq5rocks.com
    ServerAlias www.dq5rocks.com
    DocumentRoot /var/www/dq5rocks.com
    <Directory /var/www/dq5rocks.com/phpmyadmin>
     <RequireAll>
        Require ip 127.0.0.1 10.2.2
     </RequireAll>
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
        # create empty directories
        mkdir -p /var/www/dq5rocks.com

        # turn on virtual host dq5rocks.com
        a2ensite dq5rocks.com.conf

        # virtual host config for wordpress

        # uncomment this line if you want disable default site
        #a2dissite 000-default.conf

        # test to see if any syntax error in config file
        apache2ctl configtest

        # leave a info.php and index.html at root directory of website
        cat > /var/www/dq5rocks.com/info.php << "EOF"
<?php
phpinfo();
?>
EOF

        cat > /var/www/dq5rocks.com/index.html << "EOF"
<!DOCTYPE html>
<html>
<body>

<h1>www.dq5rocks.com</h1>
<p>Hello World!</p>

</body>
</html>
EOF
}

install_phpmyadmin() {
        [ -d "/var/www/dq5rocks.com/phpmyadmin/" ] && echo "seems like phpmyadmin already installed." && exit 1 || echo "ready to install phpmyadmin."
        cd /var/www/dq5rocks.com/
        wget https://files.phpmyadmin.net/phpMyAdmin/4.7.0/phpMyAdmin-4.7.0-all-languages.tar.gz.sha256
        wget https://files.phpmyadmin.net/phpMyAdmin/4.7.0/phpMyAdmin-4.7.0-all-languages.tar.gz
        SHA256SUM_IN_FILE="$(cat ./phpMyAdmin-4.7.0-all-languages.tar.gz.sha256 | cut -d " " -f 1)"
        SHA256SUM_COMPUTED="$(/usr/bin/sha256sum ./phpMyAdmin-4.7.0-all-languages.tar.gz | cut -d " " -f 1)"
        [ "$SHA256SUM_IN_FILE" != "$SHA256SUM_COMPUTED" ] && echo "oops...sha256 checksum doesnt match." && exit 2 || echo "sha256 checksum matched."
        tar zxvf ./phpMyAdmin-4.7.0-all-languages.tar.gz
        rm -rf ./phpMyAdmin-4.7.0-all-languages.tar.gz*
	mv phpMyAdmin-4.7.0-all-languages phpmyadmin
        cd ./phpmyadmin/
        cat > /var/www/dq5rocks.com/phpmyadmin/config.inc.php << "EOF"
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
        chown root:root /var/www/dq5rocks.com/
        chown -R www-data:www-data /var/www/dq5rocks.com/phpmyadmin/
}

install_wordpress() {
        [ -d "/var/www/dq5rocks.com/wordpress/" ] && echo "seems like wordpress already installed." && exit 1 || echo "ready to install wordpress."
        cd /var/www/dq5rocks.com/
        wget https://wordpress.org/wordpress-4.7.4.tar.gz.md5
        wget https://wordpress.org/wordpress-4.7.4.tar.gz
        MD5SUM_IN_FILE="$(cat ./wordpress-4.7.4.tar.gz.md5)"
        MD5SUM_COMPUTED="$(/usr/bin/md5sum ./wordpress-4.7.4.tar.gz | cut -d " " -f 1)"
        [ "$MD5SUM_IN_FILE" != "$MD5SUM_COMPUTED" ] && echo "oops...md5 checksum doesnt match." && exit 2 || echo "md5 checksum matched."
        tar zxvf ./wordpress-4.7.4.tar.gz
        rm -rf ./wordpress-4.7.4.tar.gz*
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
        chown -R www-data:www-data /var/www/dq5rocks.com/wordpress/
}

restart_apache2_service() {
        systemctl enable apache2
        systemctl restart apache2
        systemctl status apache2
}

main() {
	sync_system_time
	#unlock_apt_bala_bala
	install_apache2_and_php
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

