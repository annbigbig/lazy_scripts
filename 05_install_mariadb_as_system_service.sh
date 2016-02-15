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
	wget https://cmake.org/files/v3.4/cmake-3.4.3.tar.gz
	tar -zxvf ./cmake-3.4.3.tar.gz
	chown -R root:root ./cmake-3.4.3
	cd ./cmake-3.4.3
	./bootstrap
	make
	ln -s /usr/local/src/cmake-3.4.3/bin/cmake /usr/local/sbin/cmake
	ln -s /usr/local/src/cmake-3.4.3/bin/ctest /usr/local/sbin/ctest
	ln -s /usr/local/src/cmake-3.4.3/bin/cpack /usr/local/sbin/cpack
	rm -rf /usr/local/src/cmake-3.4.3.tar.gz
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
	#wget https://downloads.mariadb.org/interstitial/mariadb-10.1.11/source/mariadb-10.1.11.tar.gz
	#tar -zxvf ./mariadb-10.1.11.tar.gz
	#chown -R root:root ./mariadb-10.1.11
	cd ./mariadb-10.1.11
	#sed -i "s@data/test@\${INSTALL_MYSQLTESTDIR}@g" sql/CMakeLists.txt
	#mkdir build
	cd build
	#cmake -DCMAKE_BUILD_TYPE=Release \
	#	-DCMAKE_INSTALL_PREFIX=/usr/local/mariadb-10.1.11 \
	#	-DINSTALL_DOCDIR=share/doc/mariadb-10.1.11 \
	#	-DINSTALL_DOCREADMEDIR=share/doc/mariadb-10.1.11 \
	#	-DINSTALL_MANDIR=share/man \
	#	-DINSTALL_MYSQLSHAREDIR=share/mysql \
	#	-DINSTALL_MYSQLTESTDIR=share/mysql/test \
	#	-DINSTALL_PLUGINDIR=lib/mysql/plugin \
	#	-DINSTALL_SBINDIR=sbin \
	#	-DINSTALL_SCRIPTDIR=bin \
	#	-DINSTALL_SQLBENCHDIR=share/mysql/bench \
	#	-DINSTALL_SUPPORTFILESDIR=share/mysql \
	#	-DMYSQL_DATADIR=/srv/mysql \
	#	-DMYSQL_UNIX_ADDR=/run/mysqld/mysqld.sock \
	#	-DWITH_EXTRA_CHARSETS=complex \
	#	-DWITH_EMBEDDED_SERVER=ON \
	#	-DTOKUDB_OK=0 \
	#	..
	make
	echo "done."
}

main() {
	echo "main() was called"
	#install_prerequisite
	#install_cmake
	#remove_mysql
	#add_essential_user_and_group
	install_mariadb
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
