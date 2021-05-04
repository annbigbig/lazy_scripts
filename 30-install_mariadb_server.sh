#!/bin/bash
#
# This script will install MariaDB server 10.5.x galera cluster on Ubuntu mate 20.04 LTS
#
######################################################################          <<Tested on Ubuntu Mate 20.04 Desktop Edition>>
INSTALL_MARIADB_AS_MULTIPLE_NODES_GALERA_CLUSTER="no"                # 'galera.cnf' would be generated only when its value is 'yes'
######################################################################
FIRST_NODE="yes"                                                     # if this node is first node of cluster, set this value to 'yes'
MYSQL_ROOT_PASSWD="root"                                             # mariadb root password you specify for first node
WSREP_CLUSTER_NAME="kashu_cluster"                                   # name of galera cluster you preffered
WSREP_CLUSTER_ADDRESS="192.168.21.231,192.168.21.242"                # IP addresses list seperated by comma of all cluster nodes
SERVER_ID_MANUAL="100"                                               # server id u specify here has higher priority than $SERVER_ID_AUTO
#########################################################################################################################################
SERVER_ID_AUTO="$(/sbin/ifconfig eth0 | grep -v 'inet6' | grep 'inet' | tr -s ' ' | cut -d ' ' -f 3 | cut -d ':' -f 2 | cut -d '.' -f 4)"
#########################################################################################################################################
# *** SPECIAL THANKS ***
# install mariadb 10.3/10.4 on Ubuntu 20.04 LTS
# https://www.itzgeek.com/post/how-to-install-mariadb-on-ubuntu-20-04/
#
# install mariadb 10.5 on Ubuntu 20.04 LTS
# https://computingforgeeks.com/how-to-install-mariadb-on-ubuntu-focal-fossa/
#
# workaround for strange 'Could not increase number of max_open_files to more than 16364 ' problem
# https://mariadb.com/kb/en/could-not-increase-number-of-max_open_files-to-more-than-1024-request-1835/
#
# user and privileges management after version 10.4
# https://mariadb.com/kb/en/authentication-from-mariadb-104/
# https://mariadb.com/kb/en/create-user/
#
# utf8 settings
# https://www.jianshu.com/p/61113953ceff
# https://mitblog.pixnet.net/blog/post/43827108-%5Bmysql%5D-%E7%82%BA%E4%BB%80%E9%BA%BC-mysql-%E8%A6%81%E8%A8%AD%E5%AE%9A%E7%94%A8-utf8mb4-%E7%B7%A8%E7%A2%BC-utf8mb4_
# https://matthung0807.blogspot.com/2018/05/mysql-schemacollation.html
#
# *** ATTENTION ***
# extra db-users and databases and permissions would be created for webapp's requirements
# their names have been hard-coded in function 'create_users_and_db_for_webapps'
# there is no plan to extract those names here as configurable parameters
# modify them to suite your needs directly

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

install_mariadb_server() {
	MARIADB_SERVER_HAS_BEEN_INSTALLED="$(dpkg --get-selections | grep mariadb-server)"
	[ -n "$MARIADB_SERVER_HAS_BEEN_INSTALLED" ] && echo "mariadb already has been installed." && exit 2 || echo "ready to install mariadb..."
	apt-get update
	apt-get install -y software-properties-common apt-transport-https ca-certificates gnupg-curl
	apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
	add-apt-repository 'deb [arch=amd64] http://ftp.ubuntu-tw.org/mirror/mariadb/repo/10.5/ubuntu focal main'
	apt-get install -y mariadb-server mariadb-client
        echo -e "done"
}

generate_config_file() {
        MY_IP="$(/sbin/ifconfig eth0 | grep -v 'inet6' | grep 'inet' | tr -s ' ' | cut -d ' ' -f 3)"

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
default-character-set=utf8mb4

# The MySQL server
[mysqld]
#bind-address    = 127.0.0.1
port            = 3306
socket          = /var/run/mysqld/mysqld.sock
datadir         = /var/lib/mysql
skip-external-locking
skip-name-resolve
key_buffer_size = 16M
sort_buffer_size = 512K
net_buffer_length = 16K
myisam_sort_buffer_size = 8M
# meet cacti needs
max_heap_table_size = 256M
max_allowed_packet = 16M
tmp_table_size = 256M
join_buffer_size = 512M

# utf8 settings
collation-server=utf8mb4_unicode_ci
init_connect='SET collation_connection = utf8mb4_unicode_ci'
init_connect='SET NAMES utf8mb4'
character_set_server=utf8mb4
skip-character-set-client-handshake

# log settings
log_bin = /var/log/mysql/mariadb-bin
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
server-id = 1

# Uncomment the following if you are using BDB tables
#bdb_cache_size = 4M
#bdb_max_lock = 10000

# InnoDB tables are now used by default
innodb_data_home_dir = /var/lib/mysql
innodb_data_file_path = ibdata1:10M:autoextend
innodb_file_format = "Barracuda"
innodb_large_prefix = 1
innodb_log_group_home_dir = /var/lib/mysql
innodb_log_file_size = 5M
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 1
innodb_lock_wait_timeout = 50
innodb_doublewrite = on
innodb_flush_log_at_timeout = 3
innodb_read_io_threads = 32
innodb_write_io_threads = 16
innodb_flush_method = O_DIRECT
#innodb_buffer_pool_instances = 9
# You can set .._buffer_pool_size up to 50 - 80 %
# of RAM but beware of setting memory usage too high
innodb_buffer_pool_size = 4G
innodb_io_capacity = 5000
innodb_io_capacity_max = 10000

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
default-character-set=utf8mb4
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
        ###

        if [ -n "$SERVER_ID_MANUAL" ] ; then
             sed -i -- "s|server-id = 1|server-id = $SERVER_ID_MANUAL|g" /etc/mysql/my.cnf
        else
             sed -i -- "s|server-id = 1|server-id = $SERVER_ID_AUTO|g" /etc/mysql/my.cnf
        fi


        if [ "$INSTALL_MARIADB_AS_MULTIPLE_NODES_GALERA_CLUSTER" == "yes" ] ; then
        ###
cat > /etc/mysql/conf.d/galera.cnf << "EOF"
[mysqld]
binlog_format=ROW
default-storage-engine=innodb
innodb_autoinc_lock_mode=2
bind-address=0.0.0.0

# Galera Provider Configuration
wsrep_on=ON
wsrep_provider=/usr/lib/galera/libgalera_smm.so

# Galera Cluster Configuration
wsrep_cluster_name="test_cluster"
wsrep_cluster_address="gcomm://first_ip,second_ip,third_ip"

# Galera Synchronization Configuration
wsrep_sst_method=rsync

# Galera Node Configuration
wsrep_node_address="this_node_ip"
wsrep_node_name="this_node_name"
EOF
       else
       ###
cat > /etc/mysql/conf.d/galera.cnf << "EOF"
##[mysqld]
##binlog_format=ROW
##default-storage-engine=innodb
##innodb_autoinc_lock_mode=2
##bind-address=0.0.0.0

# Galera Provider Configuration
##wsrep_on=ON
##wsrep_provider=/usr/lib/galera/libgalera_smm.so

# Galera Cluster Configuration
##wsrep_cluster_name="test_cluster"
##wsrep_cluster_address="gcomm://first_ip,second_ip,third_ip"

# Galera Synchronization Configuration
##wsrep_sst_method=rsync

# Galera Node Configuration
##wsrep_node_address="this_node_ip"
##wsrep_node_name="this_node_name"
EOF
       ###
       fi

       sed -i -- "s|test_cluster|$WSREP_CLUSTER_NAME|g" /etc/mysql/conf.d/galera.cnf
       sed -i -- "s|first_ip,second_ip,third_ip|$WSREP_CLUSTER_ADDRESS|g" /etc/mysql/conf.d/galera.cnf
       sed -i -- "s|this_node_ip|$MY_IP|g" /etc/mysql/conf.d/galera.cnf
       sed -i -- "s|this_node_name|$HOSTNAME|g" /etc/mysql/conf.d/galera.cnf

       echo "done."
}

restart_mariadb_service() {
	sed -i -- "s|LimitNOFILE=16364|LimitNOFILE=infinity|g" /lib/systemd/system/mariadb.service
	systemctl daemon-reload

	if [ "$FIRST_NODE" == "yes" ] && [ "$INSTALL_MARIADB_AS_MULTIPLE_NODES_GALERA_CLUSTER" == "yes" ]; then
                systemctl stop mariadb.service
                /usr/bin/galera_new_cluster

	else
		systemctl restart mariadb.service
	fi
        
		systemctl enable mariadb.service
		systemctl status mariadb.service

}

set_mariadb_root_passwd() {
        if [ "$FIRST_NODE" == "yes" ] || [ "$INSTALL_MARIADB_AS_MULTIPLE_NODES_GALERA_CLUSTER" != "yes" ]; then
	    # no need to do mysql_secure_installation anymore after mariadb 10.4
            # just change root password on first-node
            cat > /tmp/set_mariadb_root_passwd << "EOF"
ALTER USER root@localhost IDENTIFIED VIA unix_socket OR mysql_native_password USING PASSWORD("MYSQL_ROOT_PASSWD");
FLUSH PRIVILEGES;
EOF
            sed -i -- "s|MYSQL_ROOT_PASSWD|$MYSQL_ROOT_PASSWD|g" /tmp/set_mariadb_root_passwd
            mysql -h localhost --port 3306 -u root < /tmp/set_mariadb_root_passwd
        else
            echo " only set root password for mariadb on the first node."
        fi
}

setup_logrotate_config() {
        rm -rf /etc/logrotate.d/mysql-server
	cat > /etc/logrotate.d/mariadb << "EOF"
/var/log/mysql/*.log {
	weekly
	rotate 12
	compress
	delaycompress
	missingok
	notifempty
	create 664 mysql adm
}
EOF
	chown root:root /etc/logrotate.d/mariadb
	chmod 644 /etc/logrotate.d/mariadb
}

create_users_and_db_for_webapps() {

if [ "$FIRST_NODE" == "yes" ] || [ "$INSTALL_MARIADB_AS_MULTIPLE_NODES_GALERA_CLUSTER" != "yes" ]; then

# create superuser who has the same permission with root
mysql -h localhost --port 3306 -u root -p$MYSQL_ROOT_PASSWD << "EOF"
create user 'superuser'@'localhost' identified by 'superpassword';
create user 'superuser'@'127.0.0.1' identified by 'superpassword';
create user 'superuser'@'172.25.169.%' identified by 'superpassword';
create user 'superuser'@'192.168.21.%' identified by 'superpassword';
grant all on *.* to 'superuser'@'localhost' with grant option;
grant all on *.* to 'superuser'@'127.0.0.1' with grant option;
grant all on *.* to 'superuser'@'172.25.169.%' with grant option;
grant all on *.* to 'superuser'@'192.168.21.%' with grant option;
flush privileges;
EOF

# create users and database for phpmyadmin
mysql -h localhost --port 3306 -u root -p$MYSQL_ROOT_PASSWD << "EOF"
drop database if exists phpmyadmin;
create user 'pmauser'@'localhost' identified by 'pmapassword';
create user 'pmauser'@'127.0.0.1' identified by 'pmapassword';
create user 'pmauser'@'172.25.169.%' identified by 'pmapassword';
create user 'pmauser'@'192.168.21.%' identified by 'pmapassword';
grant all on phpmyadmin.* to 'pmauser'@'localhost';
grant all on phpmyadmin.* to 'pmauser'@'127.0.0.1';
grant all on phpmyadmin.* to 'pmauser'@'172.25.169.%';
grant all on phpmyadmin.* to 'pmauser'@'192.168.21.%';
flush privileges;
EOF

# create users and database for wordpress
mysql -h localhost --port 3306 -u root -p$MYSQL_ROOT_PASSWD << "EOF"
drop database if exists wpdb;
create database wpdb;
create user 'wpuser'@'localhost' identified by 'wppassword';
create user 'wpuser'@'127.0.0.1' identified by 'wppassword';
create user 'wpuser'@'172.25.169.%' identified by 'wppassword';
create user 'wpuser'@'192.168.21.%' identified by 'wppassword';
grant all on wpdb.* to 'wpuser'@'localhost';
grant all on wpdb.* to 'wpuser'@'127.0.0.1';
grant all on wpdb.* to 'wpuser'@'172.25.169.%';
grant all on wpdb.* to 'wpuser'@'192.168.21.%';
flush privileges;
EOF

# create users and database for cacti
        cd /tmp
        wget https://www.cacti.net/downloads/cacti-1.2.16.tar.gz
        tar zxvf /tmp/cacti-1.2.16.tar.gz
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
source /tmp/cacti-1.2.16/cacti.sql;
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
create user 'spring'@'192.168.21.%' identified by 'spring';
grant all on db_spring.* to 'spring'@'localhost';
grant all on db_spring.* to 'spring'@'127.0.0.1';
grant all on db_spring.* to 'spring'@'172.25.169.%';
grant all on db_spring.* to 'spring'@'192.168.21.%';
flush privileges;
EOF

        else
              echo "do nothing on the remain nodes"
        fi
}

main() {
	remove_mysql_if_it_exists
	install_mariadb_server
	generate_config_file
	restart_mariadb_service
	set_mariadb_root_passwd
	setup_logrotate_config
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

