#!/bin/bash
#
# This script will install MariaDB server 10.1.x on Ubuntu mate 16.10
#
#####################

say_goodbye() {
	echo "goodbye everyone"
}

install_mariadb_server() {
	MARIADB_SERVER_HAS_BEEN_INSTALL=$(dpkg --get-selections | grep mariadb-server)
	if [ -z $MARIADB_SERVER_HAS_BEEN_INSTALL ] ; then
		echo -e "install mariadb-server ... \n"
		apt-get install software-properties-common
		apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
		add-apt-repository 'deb [arch=amd64] http://ftp.ubuntu-tw.org/mirror/mariadb/repo/10.1/ubuntu yakkety main'
		cat >> /etc/apt/sources.list.d/mariadb.list << EOF
# MariaDB 10.1 repository list - created 2017-03-25 04:18 UTC
# http://downloads.mariadb.org/mariadb/repositories/
deb [arch=amd64] http://ftp.ubuntu-tw.org/mirror/mariadb/repo/10.1/ubuntu yakkety main
deb-src http://ftp.ubuntu-tw.org/mirror/mariadb/repo/10.1/ubuntu yakkety main
EOF
		apt update
		apt install mariadb-server
                echo -e "done"
	fi
	#systemctl status mariadb.service
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
#bind-address    = 127.0.0.1
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

        echo "done."
}

restart_maraidb_service() {
	systemctl restart mariadb.service
	systemctl status mariadb.service
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

main() {
	install_mariadb_server
	generate_config_file
	restart_maraidb_service
	run_mysql_secure_installation
	setup_logrotate_config
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

