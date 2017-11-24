#!/bin/bash


#################

say_goodbye() {
        echo "goodbye everyone"
}

install_prerequisite() {
	apt-get install -y build-essential
	apt-get install -y openssl
	apt-get install -y libevent-2.0-5
	apt-get install -y libncurses5-dev
	apt-get install -y bison
}

install_cmake() {
	echo "ready to install cmake ..."
	cd /usr/local/src
	wget https://cmake.org/files/v3.7/cmake-3.7.0.tar.gz
	tar -zxvf ./cmake-3.7.0.tar.gz
	chown -R root:root ./cmake-3.7.0
	cd ./cmake-3.7.0
	./bootstrap
	make
	ln -s /usr/local/src/cmake-3.7.0/bin/cmake /usr/local/sbin/cmake
	ln -s /usr/local/src/cmake-3.7.0/bin/ctest /usr/local/sbin/ctest
	ln -s /usr/local/src/cmake-3.7.0/bin/cpack /usr/local/sbin/cpack
	rm -rf /usr/local/src/cmake-3.7.0.tar.gz
	echo "done."
}

remove_mysql() {
	echo "remove mysql ..."
	dpkg --get-selections | grep -v deinstall | grep mysql
	apt-get remove --purge -y mysql-server mysql-client mysql-common
	apt-get autoremove -y
	apt-get autoclean -y
	rm -rf /etc/mysql/
	echo "done."
}

add_essential_user_and_group() {
	echo "add user and group 'mysql' ... "
	groupadd -g 400 mysql
	useradd -c "MySQL Server" -d /srv/mysql -g mysql -s /bin/false -u 400 mysql
	echo "done."
}

install_mariadb() {
	echo "install mariadb ..."
	cd /usr/local/src
	wget https://downloads.mariadb.org/interstitial/mariadb-10.1.19/source/mariadb-10.1.19.tar.gz
	tar -zxvf ./mariadb-10.1.19.tar.gz
	chown -R root:root ./mariadb-10.1.19
	cd ./mariadb-10.1.19
	sed -i "s@data/test@\${INSTALL_MYSQLTESTDIR}@g" sql/CMakeLists.txt
	mkdir build
	cd build
	cmake -DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=/usr/local/mariadb-10.1.19 \
		-DINSTALL_DOCDIR=share/doc/mariadb-10.1.19 \
		-DINSTALL_DOCREADMEDIR=share/doc/mariadb-10.1.19 \
		-DINSTALL_MANDIR=share/man \
		-DINSTALL_MYSQLSHAREDIR=share/mysql \
		-DINSTALL_MYSQLTESTDIR=share/mysql/test \
		-DINSTALL_PLUGINDIR=lib/mysql/plugin \
		-DINSTALL_SBINDIR=sbin \
		-DINSTALL_SCRIPTDIR=bin \
		-DINSTALL_SQLBENCHDIR=share/mysql/bench \
		-DINSTALL_SUPPORTFILESDIR=share/mysql \
		-DMYSQL_DATADIR=/srv/mysql \
		-DMYSQL_UNIX_ADDR=/var/run/mysqld/mysqld.sock \
		-DWITH_EXTRA_CHARSETS=complex \
		-DWITH_EMBEDDED_SERVER=ON \
		-DTOKUDB_OK=0 \
		..
	make
	make test
	make install
	ln -s /usr/local/mariadb-10.1.19 /usr/local/mariadb
	echo "done."
}


generate_config_file() {
	echo "generating config file at /etc/mysql/my.cnf"
	install -v -dm 755 /etc/mysql
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
datadir         = /srv/mysql
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

# Don't listen on a TCP/IP port at all.
#skip-networking

# required unique id between 1 and 2^32 - 1
server-id       = 1

# Uncomment the following if you are using BDB tables
#bdb_cache_size = 4M
#bdb_max_lock = 10000

# InnoDB tables are now used by default
innodb_data_home_dir = /srv/mysql
innodb_data_file_path = ibdata1:10M:autoextend
innodb_log_group_home_dir = /srv/mysql
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
EOF

	echo "done."
}

post_installation() {
	echo "generating datadir"
	/usr/local/mariadb/bin/mysql_install_db --basedir=/usr/local/mariadb --datadir=/srv/mysql --user=mysql
	chown -R mysql:mysql /srv/mysql
	echo "creating directory '/var/run/mysqld'"
	install -v -m755 -o mysql -g mysql -d /var/run/mysqld
	echo "generating systemd unit file"
	cat >> /lib/systemd/system/mariadb.service << "EOF"
# http://www.certdepot.net/new-systemd-improvements/
[Unit]
Description=MariaDB database server
After=syslog.target
After=network.target

[Service]
Type=simple
User=mysql
Group=mysql

#ExecStartPre=/usr/libexec/mariadb-prepare-db-dir %n
ExecStart=/usr/local/mariadb/bin/mysqld_safe --basedir=/usr/local/mariadb
#ExecStartPost=/usr/libexec/mariadb-wait-ready $MAINPID

# Give a reasonable amount of time for the server to start up/shut down
TimeoutSec=300

# Place temp files in a secure directory, not /tmp
PrivateTmp=true

LimitNOFILE=10000

[Install]
WantedBy=multi-user.target

EOF
	systemctl daemon-reload
	systemctl enable mariadb.service
	systemctl start mariadb.service
	systemctl status mariadb.service

	echo "setting PATH environments variables"
	export PATH=/usr/local/mariadb/bin:/usr/local/mariadb/sbin:$PATH
	cat >> /etc/profile.d/mariadb_env_variables.sh << "EOF"
export PATH=/usr/local/mariadb/bin:/usr/local/mariadb/sbin:$PATH
EOF

	echo "fix problem for everytime reboot '/var/run/mysqld' is gone."
	cat >> /etc/tmpfiles.d/mysql.conf << "EOF"
# https://bugs.launchpad.net/ubuntu/+source/mysql-5.6/+bug/1435823
# systemd tmpfile settings for mysql
# See tmpfiles.d(5) for details
d /var/run/mysqld 0755 mysql mysql -
EOF

	mysql_secure_installation

}

main() {
	echo "main() was called"
	install_prerequisite
	install_cmake
	remove_mysql
	add_essential_user_and_group
	install_mariadb
	generate_config_file
	post_installation
}

echo -e "This script will install mariadb and make it as system service"
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
