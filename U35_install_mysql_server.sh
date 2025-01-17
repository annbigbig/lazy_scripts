#!/bin/bash
#
# This script will install mysql-wsrep-server 8.0.xx && galera-4  cluster on Ubuntu 24.04 LTS Server Edition
######################################################################          <<Tested on Ubuntu 24.04 Server Edition>>
INSTALL_MYSQL_AS_MULTIPLE_NODES_GALERA_CLUSTER="no"                  # 'galera.cnf' would be generated only when its value is 'yes'
######################################################################
FIRST_NODE="yes"                                                     # if this node is first node of cluster, set this value to 'yes'
MYSQL_ROOT_PASSWD="root"                                             # mysql root password you specify for first node
WSREP_CLUSTER_NAME="kashu_cluster"                                   # name of galera cluster you preffered
WSREP_CLUSTER_ADDRESS="192.168.252.240,192.168.252.241"              # IP addresses list seperated by comma of all cluster nodes
#########################################################################################################################################
# no need to setup below , script will know it and use them automatically for u
WIRED_INTERFACE_NAME="$(ip link show | grep '2:' | cut -d ':' -f 2 | sed 's/^ *//g')"
UBUNTU_CODENAME="$(cat /etc/lsb-release | grep -i codename | cut -d '=' -f 2)"
#########################################################################################################################################
# *** SPECIAL THANKS ***
# Install Galera 4 with MySQL 8 on Ubuntu 20.04
# https://galeracluster.com/2021/03/installing-galera-4-with-mysql-8-on-ubuntu-20-04/
#
# Installing Galera Cluster 4 with MySQL 8 on Ubuntu 18.04 | Galera Cluster for MySQL
# https://galeracluster.com/2020/05/installing-galera-cluster-4-with-mysql-8-on-ubuntu-18-04/
#
# galera cluster for mysql 8
# https://www.jianshu.com/p/615adddc77d7
# https://galeracluster.com/library/documentation/install-mysql.html
#
# How to install MySQL server on Ubuntu 22.04 LTS Linux
# https://www.cyberciti.biz/faq/installing-mysql-server-on-ubuntu-22-04-lts-linux/
#
# MySQL 8 optimized config my.cnf
# https://haydenjames.io/mysql-8-sample-config-tuning/
# https://gist.github.com/fevangelou/fb72f36bbe333e059b66 
#
# utf8 encoding
# https://editor.leonh.space/2022/mysql/
#
# about /etc/security/limits.conf 
# https://dannyda.com/2021/05/02/how-to-change-mysql-8-max-open-files-limit-ulimit-on-ubuntu-server-20-04-1-lts/
#
# mysqld was suddenly shutdown by AppArmor ...
# https://severalnines.com/blog/how-configure-apparmor-mysql-based-systems-mysqlmariadb-replication-galera/
# https://manpages.ubuntu.com/manpages/xenial/man5/apparmor.d.5.html
# https://bugs.launchpad.net/ubuntu/+source/clamav/+bug/585026
#
# create table and insert some data
# https://phoenixnap.com/kb/how-to-create-a-table-in-mysql
#
# unable to install mysql on linux
# https://stackoverflow.com/questions/47169028/mysql-server-cant-install-on-linux
# https://askubuntu.com/questions/1405475/unable-to-install-mysql-server-on-ubuntu-22-04-lts
#
# solution for ERROR 1698 (28000): Access denied for user 'root'@'localhost'
# https://stackoverflow.com/questions/39281594/error-1698-28000-access-denied-for-user-rootlocalhost
#
# *** ATTENTION ***
# extra db-users and databases and permissions would be created for webapp's requirements
# their names have been hard-coded in function 'create_users_and_db_for_webapps'
# there is no plan to extract those names here as configurable parameters
# modify them to suite your needs directly
#
# HINT
# the command used to bootstrap first-node if all of the nodes were shutdown accidently
# mysqld --wsrep-new-cluster --wsrep-cluster-address='gcomm://192.168.251.81,192.168.251.82' &
# second , third nodes just run
# systemctl start mysql.service

say_goodbye() {
	echo "see you next time"
}

remove_mariadb_if_it_exists() {
	MARIADB_SERVER_INSTALLED="$(dpkg --get-selections | grep mariadb-server)"
	MARIADB_CLIENT_INSTALLED="$(dpkg --get-selections | grep mariadb-client)"
	if [ -n "$MARIADB_SERVER_INSTALLED" ] || [ -n "$MARIADB_CLIENT_INSTALLED" ]; then
		systemctl stop mariadb.service > /dev/null 2>&1
		systemctl disable mariadb.service > /dev/null 2>&1
		apt-get remove --purge -y mariadb-server mariadb-client libmariadb*
		apt-get autoremove -y
		apt-get autoclean -y
		rm -rf /var/lib/mysql/
		rm -rf /etc/mysql/
        fi
}

install_mysql_server() {
	MYSQL_WSREP_HAS_BEEN_INSTALLED="$(dpkg --get-selections | grep mysql-wsrep)"
	MYSQL_SERVER_HAS_BEEN_INSTALLED="$(dpkg --get-selections | grep mysql-server)"
	if [ "$INSTALL_MYSQL_AS_MULTIPLE_NODES_GALERA_CLUSTER" == "yes" ] || [ "$INSTALL_MYSQL_AS_MULTIPLE_NODES_GALERA_CLUSTER" == "YES" ] ; then
		if [ -z "$MYSQL_WSREP_HAS_BEEN_INSTALLED" ] ; then
			REPO_INFO_FILE="/etc/apt/sources.list.d/galera.list"
			rm -rf $REPO_INFO_FILE
			cat > $REPO_INFO_FILE << EOF
# Codership Repository (Galera Cluster for MySQL)
deb https://releases.galeracluster.com/galera-4/ubuntu UBUNTU_CODENAME main
deb https://releases.galeracluster.com/mysql-wsrep-8.0/ubuntu UBUNTU_CODENAME main
EOF

			REPO_PREFERENCE_FILE="/etc/apt/preferences.d/galera.pref"
			rm -rf $REPO_PREFERENCE_FILE
			cat > $REPO_PREFERENCE_FILE << EOF
# Prefer the Codership repository
Package: *
Pin: origin releases.galeracluster.com
Pin-Priority: 1001
EOF
			# replace placeholder 'UBUNTU_CODENAME' with the real $UBUNTU_CODENAME
			sed -i -- "s|UBUNTU_CODENAME|$UBUNTU_CODENAME|g" $REPO_INFO_FILE

			# import public key
			apt-key adv --keyserver keyserver.ubuntu.com --recv 8DA84635
			apt-get update
			apt-get install -y software-properties-common
			apt-get install -y galera-4 galera-arbitrator-4 mysql-wsrep-8.0
		fi
	else
		if [ -z "$MYSQL_SERVER_HAS_BEEN_INSTALLED" ] ; then
			apt-get update
			apt-get install -y mysql-server-8.0
		fi
	fi

        echo -e "done"
}

generate_config_file() {
        MY_IP="$(/sbin/ifconfig $WIRED_INTERFACE_NAME | grep -v 'inet6' | grep 'inet' | tr -s ' ' | cut -d ' ' -f 3)"

	# backup default(original) config first
	echo -e "backup default config /etc/mysql/conf.d/mysql.cnf\n"
	cp /etc/mysql/conf.d/mysql.cnf /etc/mysql/conf.d/mysql.cnf.default
	rm -rf /etc/mysql/conf.d/mysql.cnf
	echo -e "backup default config /etc/mysql/mysql.conf.d/mysqld.cnf\n"
	cp /etc/mysql/mysql.conf.d/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf.default
	rm -rf /etc/mysql/mysql.conf.d/mysqld.cnf

	# generate mysql.cnf
	cat > /etc/mysql/conf.d/mysql.cnf << "EOF"
[mysql]
port                            = 3306
socket                          = /var/run/mysqld/mysqld.sock
default-character-set           = utf8mb4

[client]
default-character-set           = utf8mb4
EOF

	# generate mysqld.cnf
	cat > /etc/mysql/mysql.conf.d/mysqld.cnf << "EOF"
[mysqld]
# === Required Settings ===
basedir                         = /usr
bind_address                    = 0.0.0.0
datadir                         = /var/lib/mysql
default_authentication_plugin   = mysql_native_password
max_allowed_packet              = 256M
max_connect_errors              = 1000000
pid_file                        = /var/run/mysqld/mysqld.pid
port                            = 3306
skip_external_locking
skip_name_resolve
socket                          = /var/run/mysqld/mysqld.sock
tmpdir                          = /tmp
user                            = mysql

# === utf8mb4 Settings ===
collation_server = utf8mb4_unicode_ci
character-set-server = utf8mb4
character-set-client-handshake = FALSE

# === InnoDB Settings ===
default_storage_engine          = InnoDB
innodb_buffer_pool_instances    = 4
innodb_buffer_pool_size         = 2G
innodb_file_per_table           = 1
innodb_flush_log_at_trx_commit  = 0
innodb_flush_method             = O_DIRECT
innodb_flush_log_at_timeout	= 3
innodb_log_buffer_size          = 16M
innodb_log_file_size            = 1G
innodb_sort_buffer_size         = 4M
innodb_stats_on_metadata        = 0
innodb_read_io_threads          = 64
innodb_write_io_threads         = 64
innodb_autoinc_lock_mode        = 2
innodb_io_capacity              = 5000
innodb_io_capacity_max          = 10000

# === MyISAM Settings ===
key_buffer_size                 = 24M
low_priority_updates            = 1
concurrent_insert               = 2

# === Connection Settings ===
max_connections                 = 100
back_log                        = 512
thread_cache_size               = 100
thread_stack                    = 192K
interactive_timeout             = 180
wait_timeout                    = 180

# === Buffer Settings ===
join_buffer_size                = 4M
read_buffer_size                = 3M
read_rnd_buffer_size            = 4M
sort_buffer_size                = 4M

# === Table Settings ===
table_definition_cache          = 40000
table_open_cache                = 40000
open_files_limit                = 60000
max_heap_table_size             = 128M
tmp_table_size                  = 128M

# === Binary Logging ===
disable_log_bin                 = 0     # Binary logging disabled by default

# === Error & Slow Query Logging ===
log_error                       = /var/lib/mysql/mysql_error.log
log_queries_not_using_indexes   = 0
long_query_time                 = 5
slow_query_log                  = 0
slow_query_log_file             = /var/lib/mysql/mysql_slow.log

[mysqldump]
quick
quote_names
max_allowed_packet              = 1024M

EOF

	if [ $INSTALL_MYSQL_AS_MULTIPLE_NODES_GALERA_CLUSTER == "yes" ] || [ $INSTALL_MYSQL_AS_MULTIPLE_NODES_GALERA_CLUSTER == "YES" ]; then
	cat > /etc/mysql/mysql.conf.d/galera.cnf << "EOF"
[mysqld]
binlog_format=ROW
wsrep_on=ON
wsrep_provider=/usr/lib/galera/libgalera_smm.so
wsrep_node_name="this_node_name"
wsrep_node_address="this_node_ip"
wsrep_cluster_name="test_cluster"
wsrep_cluster_address="gcomm://first_ip,second_ip,third_ip"
wsrep_provider_options="gcache.size=128M; gcache.page_size=128M"
wsrep_slave_threads=4
wsrep_sst_method=rsync
EOF
	else
	cat > /etc/mysql/mysql.conf.d/galera.cnf << "EOF"
##[mysqld]
##binlog_format=ROW
##wsrep_on=ON
##wsrep_provider=/usr/lib/galera/libgalera_smm.so
##wsrep_node_name="this_node_name"
##wsrep_node_address="this_node_ip"
##wsrep_cluster_name="test_cluster"
##wsrep_cluster_address="gcomm://first_ip,second_ip,third_ip"
##wsrep_provider_options="gcache.size=128M; gcache.page_size=128M"
##wsrep_slave_threads=4
##wsrep_sst_method=rsync
EOF
	fi

       sed -i -- "s|test_cluster|$WSREP_CLUSTER_NAME|g" /etc/mysql/mysql.conf.d/galera.cnf
       sed -i -- "s|first_ip,second_ip,third_ip|$WSREP_CLUSTER_ADDRESS|g" /etc/mysql/mysql.conf.d/galera.cnf
       sed -i -- "s|this_node_ip|$MY_IP|g" /etc/mysql/mysql.conf.d/galera.cnf
       sed -i -- "s|this_node_name|$HOSTNAME|g" /etc/mysql/mysql.conf.d/galera.cnf

       # delete /etc/mysql/my.cnf , it was point to /etc/alternatives/my.cnf as a symbolic link
       rm -rf /etc/mysql/my.cnf
       touch /etc/mysql/my.cnf
       cat > /etc/mysql/my.cnf << "EOF"
[client-server]
# Port or socket location where to connect
# port = 3306
socket = /var/run/mysqld/mysqld.sock

# Import all .cnf files from configuration directory
!includedir /etc/mysql/conf.d/
!includedir /etc/mysql/mysql.conf.d/
EOF

       echo "done."
}

allow_permissions_for_apparmor() {
	# install apparmor profiles and tools
	apt-get update
	apt-get install -y apparmor-profiles apparmor-utils

	# delete default profile and generate a new one for mysqld
	rm -rf /etc/apparmor.d/usr.sbin.mysqld
	cat > /etc/apparmor.d/usr.sbin.mysqld << "EOF"
#include <tunables/global>

/usr/sbin/mysqld {
  #include <abstractions/base>
  #include <abstractions/nameservice>
  #include <abstractions/user-tmp>
  #include <abstractions/mysql>
  #include <abstractions/winbind>

# Allow system resource access
  /sys/devices/system/cpu/ r,
  /sys/devices/system/node/ r,
  /sys/devices/system/node/** r,
  /proc/*/status r,
  capability sys_resource,
  capability dac_override,
  capability setuid,
  capability setgid,
  capability sys_nice,

# Allow network access
  network tcp,

  /etc/hosts.allow r,
  /etc/hosts.deny r,

# Allow config access
  /etc/mysql/** r,

# Allow pid, socket, socket lock and other file access
  /run/mysqld/* rw,
  /var/run/mysqld/* rw,

# Allow systemd notify messages
  /{,var/}run/systemd/notify w,

# Allow execution of server binary
  /usr/sbin/mysqld mr,
  /usr/sbin/mysqld-debug mr,

# Allow plugin access
  /usr/lib/mysql/plugin/ r,
  /usr/lib/mysql/plugin/*.so* mr,

# Allow error msg and charset access
  /usr/share/mysql/ r,
  /usr/share/mysql/** r,
  /usr/share/mysql-8.0/ r,
  /usr/share/mysql-8.0/** r,

# Allow data dir access
  /var/lib/mysql/ r,
  /var/lib/mysql/** rwk,

# Allow data files dir access
  /var/lib/mysql-files/ r,
  /var/lib/mysql-files/** rwk,

# Allow keyring dir access
  /var/lib/mysql-keyring/ r,
  /var/lib/mysql-keyring/** rwk,

# Allow log file access
  /var/log/mysql/ r,
  /var/log/mysql/** rw,

# Allow access to openssl config
  /etc/ssl/openssl.cnf r,

#####################################
# Allow these that not mention above
  /usr/sbin/ifconfig ixr,
  /usr/bin/** ixr,
  /proc/** r,
  /proc/ r,
  /dev/tty rw,
  / r,
#####################################

  # Site-specific additions and overrides. See local/README for details.
  #include <local/usr.sbin.mysqld>
}
EOF
	chown root:root /etc/apparmor.d/usr.sbin.mysqld
	chmod 644 /etc/apparmor.d/usr.sbin.mysqld

	# reload profile changes into Kernel , that's done
	apparmor_parser -r -T /etc/apparmor.d/usr.sbin.mysqld
}

restart_mysql_service() {
	echo "mysql            hard          nofile        65535" >> /etc/security/limits.conf
	echo "mysql            soft          nofile        65535" >> /etc/security/limits.conf
	sed -i -- "s|LimitNOFILE = 10000|LimitNOFILE = 65535|g" /lib/systemd/system/mysql.service
	sed -i '/LimitNOFILE = 65535/a LimitMEMLOCK=infinity' /lib/systemd/system/mysql.service
	systemctl daemon-reload

	if [ "$FIRST_NODE" == "yes" ] && [ "$INSTALL_MYSQL_AS_MULTIPLE_NODES_GALERA_CLUSTER" == "yes" ]; then
                systemctl stop mysql.service
		/usr/bin/mysqld_bootstrap

	else
		systemctl restart mysql.service
	fi
        
		systemctl enable mysql.service
		systemctl status mysql.service

}

set_mysql_root_passwd() {
        if [ "$FIRST_NODE" == "yes" ] || [ "$INSTALL_MYSQL_AS_MULTIPLE_NODES_GALERA_CLUSTER" != "yes" ]; then
	    # no need to do mysql_secure_installation anymore
            # just change root password on first-node
            cat > /tmp/set_mysql_root_passwd.sql << "EOF"
ALTER USER 'root'@'localhost' IDENTIFIED BY 'MYSQL_ROOT_PASSWD';
FLUSH PRIVILEGES;
EOF
            sed -i -- "s|MYSQL_ROOT_PASSWD|$MYSQL_ROOT_PASSWD|g" /tmp/set_mysql_root_passwd.sql

            # change root@localhost Plugin from 'auth_socket' to 'mysql_native_password'
            cat > /tmp/let_normal_system_user_login.sql << "EOF"
USE mysql;
UPDATE user SET plugin='mysql_native_password' WHERE User='root';
FLUSH PRIVILEGES;
EOF
            
            # run xxx.sql in command line	    
            mysql -u root < /tmp/let_normal_system_user_login.sql
	    sleep 1
            mysql -u root < /tmp/set_mysql_root_passwd.sql
        else
            echo " only set root password for mysql on the first node."
        fi
}

setup_logrotate_config() {
        rm -rf /etc/logrotate.d/mysql* /etc/logrorate.d/mariadb*
	cat > /etc/logrotate.d/mysql << "EOF"
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
	chown root:root /etc/logrotate.d/mysql
	chmod 644 /etc/logrotate.d/mysql
}

create_users_and_db_for_webapps() {

if [ "$FIRST_NODE" == "yes" ] || [ "$INSTALL_MYSQL_AS_MULTIPLE_NODES_GALERA_CLUSTER" != "yes" ]; then

# create superuser who has the same permission with root
mysql -u root -p$MYSQL_ROOT_PASSWD << "EOF"
create user 'superuser'@'localhost' identified by 'superpassword';
create user 'superuser'@'127.0.0.1' identified by 'superpassword';
create user 'superuser'@'192.168.251.%' identified by 'superpassword';
create user 'superuser'@'192.168.252.%' identified by 'superpassword';
grant all on *.* to 'superuser'@'localhost' with grant option;
grant all on *.* to 'superuser'@'127.0.0.1' with grant option;
grant all on *.* to 'superuser'@'192.168.251.%' with grant option;
grant all on *.* to 'superuser'@'192.168.252.%' with grant option;
flush privileges;
EOF

# create users and database for phpmyadmin
mysql -u root -p$MYSQL_ROOT_PASSWD << "EOF"
drop database if exists phpmyadmin;
create database phpmyadmin;
create user 'pmauser'@'localhost' identified by 'pmapassword';
create user 'pmauser'@'127.0.0.1' identified by 'pmapassword';
create user 'pmauser'@'192.168.251.%' identified by 'pmapassword';
create user 'pmauser'@'192.168.252.%' identified by 'pmapassword';
grant all on phpmyadmin.* to 'pmauser'@'localhost';
grant all on phpmyadmin.* to 'pmauser'@'127.0.0.1';
grant all on phpmyadmin.* to 'pmauser'@'192.168.251.%';
grant all on phpmyadmin.* to 'pmauser'@'192.168.252.%';
flush privileges;
EOF

# create users and database for wordpress
mysql -u root -p$MYSQL_ROOT_PASSWD << "EOF"
drop database if exists wpdb;
create database wpdb;
create user 'wpuser'@'localhost' identified by 'wppassword';
create user 'wpuser'@'127.0.0.1' identified by 'wppassword';
create user 'wpuser'@'192.168.251.%' identified by 'wppassword';
create user 'wpuser'@'192.168.252.%' identified by 'wppassword';
grant all on wpdb.* to 'wpuser'@'localhost';
grant all on wpdb.* to 'wpuser'@'127.0.0.1';
grant all on wpdb.* to 'wpuser'@'192.168.251.%';
grant all on wpdb.* to 'wpuser'@'192.168.252.%';
flush privileges;
EOF

# create users and database for cacti
        cd /tmp
        wget --no-check-certificate https://files.cacti.net/cacti/linux/cacti-1.2.28.tar.gz
        tar zxvf /tmp/cacti-1.2.28.tar.gz
mysql -u root -p$MYSQL_ROOT_PASSWD << "EOF"
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
source /tmp/cacti-1.2.28/cacti.sql;
EOF
        # populate timezone data from /usr/share/zoneinfo to mysql time_zone_name table
        /usr/bin/mysql_tzinfo_to_sql /usr/share/zoneinfo/ | mysql -u root -p$MYSQL_ROOT_PASSWD mysql

# create users and database for my personal JavaEE webapp
mysql -u root -p$MYSQL_ROOT_PASSWD << "EOF"
drop database if exists db_spring;
create database db_spring;
create user 'spring'@'localhost' identified by 'spring';
create user 'spring'@'127.0.0.1' identified by 'spring';
create user 'spring'@'192.168.251.%' identified by 'spring';
create user 'spring'@'192.168.252.%' identified by 'spring';
grant all on db_spring.* to 'spring'@'localhost';
grant all on db_spring.* to 'spring'@'127.0.0.1';
grant all on db_spring.* to 'spring'@'192.168.251.%';
grant all on db_spring.* to 'spring'@'192.168.252.%';
flush privileges;
EOF

        else
              echo "do nothing on the remain nodes"
        fi
}

main() {
	remove_mariadb_if_it_exists
	install_mysql_server
	generate_config_file
	allow_permissions_for_apparmor
	set_mysql_root_passwd
	restart_mysql_service
	setup_logrotate_config
       	create_users_and_db_for_webapps
}

echo -e "This script will install MySQL 8 on this host \n"
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

