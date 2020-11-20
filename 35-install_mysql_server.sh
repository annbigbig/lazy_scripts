#!/bin/bash
#
# This script will install MySQL server 8.0.x on Ubuntu 20.04 LTS
#
######################################################################
MYSQL_ROOT_PASSWD="P@ssw0rd"                                         # mariadb root password you specify for first node
SERVER_ID_MANUAL=""                                                  # server id u specify here has higher priority than $SERVER_ID_AUTO
#########################################################################################################################################
SERVER_ID_AUTO="$(/sbin/ifconfig eth0 | grep -v 'inet6' | grep 'inet' | tr -s ' ' | cut -d ' ' -f 3 | cut -d ':' -f 2 | cut -d '.' -f 4)"
#########################################################################################################################################
# *** SPECIAL THANKS ***
# https://www.digitalocean.com/community/tutorials/how-to-install-mysql-on-ubuntu-20-04
# https://stackoverflow.com/questions/24270733/automate-mysql-secure-installation-with-echo-command-via-a-shell-script/35004940
# https://www.howtoforge.com/tutorial/debian_mysql/
# https://andy6804tw.github.io/2019/01/29/ubuntu-mysql-setting/
#
# *** ATTENTION ***
# extra db-users and databases and permissions would be created for webapp's requirements
# their names have been hard-coded in function 'create_users_and_db_for_webapps'
# there is no plan to extract those names here as configurable parameters
# modify them to suite your needs directly or comment out that function

say_goodbye() {
	echo "goodbye everyone"
}

remove_mysql_if_it_exists() {
	MYSQL_SERVER_INSTALLED="$(dpkg --get-selections | grep mysql-server)"
	MYSQL_CLIENT_INSTALLED="$(dpkg --get-selections | grep mysql-client)"
	MYSQL_COMMON_INSTALLED="$(dpkg --get-selections | grep mysql-common)"
	if [ -n "$MYSQL_SERVER_INSTALLED" ] || [ -n "$MYSQL_CLIENT_INSTALLED" ] || [ -n "$MYSQL_COMMON_INSTALLED" ]; then
		systemctl stop mysql > /dev/null 2>&1
		systemctl disable mysql > /dev/null 2>&1
		apt-get remove --purge -y mysql-server mysql-client mysql-common
		apt-get autoremove -y
		apt-get autoclean -y
		rm -rf /var/lib/mysql/
		rm -rf /etc/mysql/
        fi
}

install_mysql_server() {
	MYSQL_SERVER_HAS_BEEN_INSTALLED="$(dpkg --get-selections | grep mysql-server)"
	[ -n "$MYSQL_SERVER_HAS_BEEN_INSTALLED" ] && echo "mysql-server already has been installed." && exit 2 || echo "ready to install mysql-server..."
	apt-get install -y gnupg wget
	cd /tmp
	wget -q http://repo.mysql.com/mysql-apt-config_0.8.15-1_all.deb
        dpkg -i /tmp/mysql-apt-config_0.8.15-1_all.deb
	apt-get update
	apt-get install -y mysql-server mysql-client libmysqlclient-dev
        echo -e "done"
}

generate_config_file() {
        echo -e " mysqld config file lives on /etc/mysql/mysql.conf.d/mysqld.cnf \n"
        echo -e " no need to bother him if u just use it for experimental purposes \n"
}

restart_mysql_service() {
	systemctl daemon-reload
	systemctl restart mysql.service
	systemctl enable mysql.service
	systemctl is-enabled mysql.service
	systemctl status mysql.service
}

run_mysql_secure_passwd() {
            cat > /tmp/mysql_secure_passwd << "EOF"
alter user 'root'@'localhost' identified with mysql_native_password by 'MYSQL_ROOT_PASSWD';
DROP USER ''@'localhost';
DROP USER ''@'$(hostname)';
DROP DATABASE test;

FLUSH PRIVILEGES;
EOF
            sed -i -- "s|MYSQL_ROOT_PASSWD|$MYSQL_ROOT_PASSWD|g" /tmp/mysql_secure_passwd
            mysql -h localhost --port 3306 -u root -p$MYSQL_ROOT_PASSWD < /tmp/mysql_secure_passwd
}

create_users_and_db_for_webapps() {


# create superuser who has the same permission with root
mysql -h localhost --port 3306 -u root -p$MYSQL_ROOT_PASSWD << "EOF"
create user 'superuser'@'localhost' identified by 'superpassword';
create user 'superuser'@'127.0.0.1' identified by 'superpassword';
create user 'superuser'@'172.25.169.%' identified by 'superpassword';
grant all on *.* to 'superuser'@'localhost' with grant option;
grant all on *.* to 'superuser'@'127.0.0.1' with grant option;
grant all on *.* to 'superuser'@'172.25.169.%' with grant option;
flush privileges;
EOF

# create users and database for phpmyadmin
mysql -h localhost --port 3306 -u root -p$MYSQL_ROOT_PASSWD << "EOF"
drop database if exists phpmyadmin;
create user 'pmauser'@'localhost' identified by 'pmapassword';
create user 'pmauser'@'127.0.0.1' identified by 'pmapassword';
create user 'pmauser'@'172.25.169.%' identified by 'pmapassword';
grant all on phpmyadmin.* to 'pmauser'@'localhost';
grant all on phpmyadmin.* to 'pmauser'@'127.0.0.1';
grant all on phpmyadmin.* to 'pmauser'@'172.25.169.%';
flush privileges;
EOF

# create users and database for wordpress
mysql -h localhost --port 3306 -u root -p$MYSQL_ROOT_PASSWD << "EOF"
drop database if exists wpdb;
create database wpdb;
create user 'wpuser'@'localhost' identified by 'wppassword';
create user 'wpuser'@'127.0.0.1' identified by 'wppassword';
create user 'wpuser'@'172.25.169.%' identified by 'wppassword';
grant all on wpdb.* to 'wpuser'@'localhost';
grant all on wpdb.* to 'wpuser'@'127.0.0.1';
grant all on wpdb.* to 'wpuser'@'172.25.169.%';
flush privileges;
EOF

# create users and database for cacti
        cd /tmp
        wget https://www.cacti.net/downloads/cacti-1.2.14.tar.gz
        tar zxvf /tmp/cacti-1.2.14.tar.gz
mysql -h localhost --port 3306 -u root -p$MYSQL_ROOT_PASSWD << "EOF"
drop database if exists cacti_db;
create database cacti_db;
create user 'cactiuser'@'localhost' identified by 'cactipass';
create user 'cactiuser'@'127.0.0.1' identified by 'cactipass';
grant all on cacti_db.* to 'cactiuser'@'localhost';
grant all on cacti_db.* to 'cactiuser'@'127.0.0.1';
grant select on mysql.time_zone_name to 'cactiuser'@'localhost';
grant select on mysql.time_zone_name to 'cactiuser'@'127.0.0.1';
flush privileges;
use cacti_db;
source /tmp/cacti-1.2.14/cacti.sql;
EOF
        # populate timezone data from /usr/share/zoneinfo to mysql time_zone_name table
        /usr/bin/mysql_tzinfo_to_sql /usr/share/zoneinfo/ | mysql -h localhost --port 3306 -u root -p$MYSQL_ROOT_PASSWD mysql

# create users and database for my personal JavaEE webapp
mysql -h localhost --port 3306 -u root -p$MYSQL_ROOT_PASSWD << "EOF"
drop database if exists db_spring;
create database db_spring;
create user 'spring'@'localhost' identified by 'spring';
create user 'spring'@'127.0.0.1' identified by 'spring';
create user 'spring'@'172.25.169.%' identified by 'spring';
grant all on db_spring.* to 'spring'@'localhost';
grant all on db_spring.* to 'spring'@'127.0.0.1';
grant all on db_spring.* to 'spring'@'172.25.169.%';
flush privileges;
EOF

}

main() {
	remove_mysql_if_it_exists
	install_mysql_server
	generate_config_file
	restart_mysql_service
	run_mysql_secure_passwd
        create_users_and_db_for_webapps
}

echo -e "This script will install MariaDB on this host \n"
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

