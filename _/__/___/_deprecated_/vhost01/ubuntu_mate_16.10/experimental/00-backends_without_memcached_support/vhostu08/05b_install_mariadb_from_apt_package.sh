#!/bin/bash
#
# This script will install MariaDB server 10.1.x on Ubuntu mate 16.10/17.04
#
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

remove_mysql_if_it_exists() {
	MYSQL_SERVER_INSTALLED="$(dpkg --get-selections | grep mysql-server)"
	MYSQL_CLIENT_INSTALLED="$(dpkg --get-selections | grep mysql-client)"
	MYSQL_COMMON_INSTALLED="$(dpkg --get-selections | grep mysql-common)"
	if [ -n "$MYSQL_SERVER_INSTALLED" ] || [ -n "$MYSQL_CLIENT_INSTALLED" ] || [ -n "$MYSQL_COMMON_INSTALLED" ]; then
		systemctl stop mysql > /dev/null 2>&1
		systemctl disable mysql > /dev/null 2>&1
		apt-get remove --purge -y mysql-server mysql-client mysql-common
		apt-get autoremove
		apt-get autoclean
		rm -rf /var/lib/mysql/
		rm -rf /etc/mysql/
        fi
}

install_mariadb_server() {
	MARIADB_SERVER_HAS_BEEN_INSTALL="$(dpkg --get-selections | grep mariadb-server)"
	[ -n "$MARIADB_SERVER_HAS_BEEN_INSTALL" ] && echo "mariadb already has been installed." && exit 2 || echo "ready to install mariadb..."
	apt-get install -y software-properties-common
	apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8

	UBUNTU_VERSION_NAME="$a(/usr/bin/lsb_release -a 2>/dev/null | tail -1 | tr -d ' \t' | cut -d ':' -f 2)"
	if [ "$UBUNTU_VERSION_NAME" == "xenial" ] ; then
		add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://ftp.ubuntu-tw.org/mirror/mariadb/repo/10.1/ubuntu xenial main'
		cat >> /etc/apt/sources.list.d/mariadb.list << "EOF"
# MariaDB 10.1 repository list - created 2017-08-25 09:03 UTC
# http://downloads.mariadb.org/mariadb/repositories/
deb [arch=amd64,i386] http://ftp.ubuntu-tw.org/mirror/mariadb/repo/10.1/ubuntu xenial main
deb-src http://ftp.ubuntu-tw.org/mirror/mariadb/repo/10.1/ubuntu xenial main
EOF
	elif [ "$UBUNTU_VERSION_NAME" == "yakkety" ] ; then
		add-apt-repository 'deb [arch=amd64,i386] http://ftp.ubuntu-tw.org/mirror/mariadb/repo/10.1/ubuntu yakkety main'
                cat >> /etc/apt/sources.list.d/mariadb.list << "EOF"
# MariaDB 10.1 repository list - created 2017-03-25 04:18 UTC
# http://downloads.mariadb.org/mariadb/repositories/
deb [arch=amd64] http://ftp.ubuntu-tw.org/mirror/mariadb/repo/10.1/ubuntu yakkety main
deb-src http://ftp.ubuntu-tw.org/mirror/mariadb/repo/10.1/ubuntu yakkety main
EOF
	elif [ "$UBUNTU_VERSION_NAME" == "zesty" ] ; then
		add-apt-repository 'deb [arch=amd64,i386] http://ftp.ubuntu-tw.org/mirror/mariadb/repo/10.1/ubuntu zesty main'
		cat >> /etc/apt/sources.list.d/mariadb.list << "EOF"
# MariaDB 10.1 repository list - created 2017-08-25 08:59 UTC
# http://downloads.mariadb.org/mariadb/repositories/
deb [arch=amd64,i386] http://ftp.ubuntu-tw.org/mirror/mariadb/repo/10.1/ubuntu zesty main
deb-src http://ftp.ubuntu-tw.org/mirror/mariadb/repo/10.1/ubuntu zesty main
EOF
	fi

		apt update
		apt install -y mariadb-server
                echo -e "done"
}

generate_config_file() {
        echo "generating config file at /etc/mysql/my.cnf"
        install -v -dm 755 /etc/mysql
        install -v -dm 755 /etc/mysql/conf.d
	mv /etc/mysql/my.cnf /etc/mysql/my.cnf.backup
        cat > /etc/mysql/my.cnf << "EOF"
# Begin /etc/mysql/my.cnf

# The following options will be passed to all MySQL clients
[client]
#password       = your_password
port            = 3306
socket          = /var/run/mysqld/mysqld.sock
default-character-set=utf8

# The MySQL server
[mysqld]
bind-address    = 127.0.0.1
port            = 3306
socket          = /var/run/mysqld/mysqld.sock
datadir         = /var/lib/mysql
skip-external-locking
key_buffer_size = 16M
max_allowed_packet = 1M
sort_buffer_size = 512K
net_buffer_length = 16K
myisam_sort_buffer_size = 8M

# utf8 settings
collation-server=utf8_unicode_ci
init_connect='SET collation_connection = utf8_unicode_ci'
init-connect='SET NAMES utf8'
character-set-server=utf8
skip-character-set-client-handshake

# log settings
#log_bin = /var/log/mysql/mariadb-bin
log_error = /var/log/mysql/mariadb-err.log
# general log
#general_log = 1
#general_log_file = /var/log/mysql/general.log
# slow query log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/mariadb-slow.log
long_query_time = 0.05
log_slow_rate_limit = 20
log_slow_verbosity = query_plan,innodb,explain

# Don't listen on a TCP/IP port at all.
#skip-networking

# required unique id between 1 and 2^32 - 1
server-id       = 1

# Uncomment the following if you are using BDB tables
#bdb_cache_size = 4M
#bdb_max_lock = 10000

# InnoDB tables are now used by default
innodb_data_home_dir = /var/lib/mysql
innodb_data_file_path = ibdata1:10M:autoextend
innodb_log_group_home_dir = /var/lib/mysql
# You can set .._buffer_pool_size up to 50 - 80 %
# of RAM but beware of setting memory usage too high
innodb_buffer_pool_size = 16M
innodb_additional_mem_pool_size = 2M
# Set .._log_file_size to 25 % of buffer pool size
innodb_log_file_size = 5M
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 1
innodb_lock_wait_timeout = 50

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
default-character-set=utf8
no-auto-rehash
# Remove the next comment character if you are not familiar with SQL
#safe-updates

[isamchk]
key_buffer = 20M
sort_buffer_size = 20M
read_buffer = 2M
write_buffer = 2M

[myisamchk]
key_buffer_size = 20M
sort_buffer_size = 20M
read_buffer = 2M
write_buffer = 2M

[mysqlhotcopy]
interactive-timeout

# End /etc/mysql/my.cnf
!includedir /etc/mysql/conf.d/
EOF
        MY_IP="$(/sbin/ifconfig eth0 | grep 'inet addr' | tr -s ' ' | cut -d ' ' -f 3 | cut -d ':' -f 2)"
        sed -i -- "s|127.0.0.1|$MY_IP|g" /etc/mysql/my.cnf


        echo "done."
}

restart_maraidb_service() {

	UBUNTU_VERSION_NAME="$(/usr/bin/lsb_release -a 2>/dev/null | tail -1 | tr -d ' \t' | cut -d ':' -f 2)"
	if [ "$UBUNTU_VERSION_NAME" == "xenial" ] ; then
		systemctl enable mysql.service
		systemctl restart mysql.service
		systemctl status mysql.service
	else
		systemctl enable mariadb.service
		systemctl restart mariadb.service
		systemctl status mariadb.service
	fi	
}

run_mysql_secure_installation() {
	mysql_secure_installation
}

setup_logrotate_config() {
	cat > /etc/logrotate.d/mariadb << EOF
/var/log/mysql/*.log {
	weekly
	rotate 12
	compress
	delaycompress
	missingok
	notifempty
	create 644 root root
}
EOF
	chown root:root /etc/logrotate.d/mariadb
	chmod 644 /etc/logrotate.d/mariadb
}

remove_plugin_unix_socket() {
        cat > /tmp/remove_plugin_unix_socket.sql << "EOF"
use mysql;
update user set plugin='' where User='root';
flush privileges;
EOF
        mysql -h localhost --port 3306 -u root -p$MYSQL_ROOT_PASSWD < /tmp/remove_plugin_unix_socket.sql
        rm -rf /tmp/remove_plugin_unix_socket.sql
}

add_db_accounts() {
        cat > /tmp/create_pma_control_user.sql << "EOF"
drop database if exists phpmyadmin;
create user 'pmauser'@'localhost' identified by 'pmapassword';
create user 'pmauser'@'127.0.0.1' identified by 'pmapassword';
create user 'pmauser'@'172.28.117.%' identified by 'pmapassword';
grant all on phpmyadmin.* to 'pmauser'@'localhost';
grant all on phpmyadmin.* to 'pmauser'@'127.0.0.1';
grant all on phpmyadmin.* to 'pmauser'@'172.28.117.%';
flush privileges;
EOF
        chown root:root /tmp/create_pma_control_user.sql
        mysql -h localhost --port 3306 -u root -p$MYSQL_ROOT_PASSWD < /tmp/create_pma_control_user.sql
        rm -rf /tmp/create_pma_control_user.sql


        cat > /tmp/create_wp_db_and_user.sql << "EOF"
drop database if exists wpdb;
create database wpdb;
create user 'wpuser'@'localhost' identified by 'wppassword';
create user 'wpuser'@'127.0.0.1' identified by 'wppassword';
create user 'wpuser'@'172.28.117.%' identified by 'wppassword';
grant all on wpdb.* to 'wpuser'@'localhost';
grant all on wpdb.* to 'wpuser'@'127.0.0.1';
grant all on wpdb.* to 'wpuser'@'172.28.117.%';
flush privileges;
EOF
        mysql -h localhost --port 3306 -u root -p$MYSQL_ROOT_PASSWD < /tmp/create_wp_db_and_user.sql
        rm -rf /tmp/create_wp_db_and_user.sql

}

main() {
	unlock_apt_bala_bala
	update_system
	sync_system_time
	remove_mysql_if_it_exists
	install_mariadb_server
	generate_config_file
	restart_maraidb_service
	run_mysql_secure_installation
	setup_logrotate_config
        remove_plugin_unix_socket
        add_db_accounts
}

echo -e "This script will install MariaDB server on this host \n"
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

