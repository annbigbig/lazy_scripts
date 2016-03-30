#!/bin/bash

#################

say_goodbye() {
        echo "goodbye everyone"
}

install_memcached() {
	# install libevent
	cd /usr/local/src
	wget http://downloads.sourceforge.net/levent/libevent-2.0.22-stable.tar.gz
	tar -zxvf ./libevent-2.0.22-stable.tar.gz
	chown -R root:root ./libevent-2.0.22-stable
	cd ./libevent-2.0.22-stable/
	./configure --prefix=/usr/local/libevent-2.0.22 --disable-static
	make
	make install
	ln -s /usr/local/libevent-2.0.22 /usr/local/libevent

	# install memcached
	cd /usr/local/src
	wget http://www.memcached.org/files/memcached-1.4.25.tar.gz
	tar -zxvf ./memcached-1.4.25.tar.gz
	chown -R root:root ./memcached-1.4.25
	cd memcached-1.4.25/
	./configure --prefix=/usr/local/memcached-1.4.25 \
                    --with-libevent=/usr/local/libevent \
                    --enable-64bit
	make
	make install
	ln -s /usr/local/memcached-1.4.25 /usr/local/memcached

	# for 'man memcached' command
	cp /usr/local/memcached/share/man/man1/memcached.1 /usr/local/man/man1/

	# create user 'memcached'
	echo -e "create memcached user\n"
        groupadd -g 700 memcached
        useradd -u 700 -g memcached -s /sbin/nologin memcached
        id memcached

	# create configuration
	mkdir -p /usr/local/memcached-1.4.25/env
	cat >> /usr/local/memcached-1.4.25/env/memcached << "EOF"
PORT="11211"
USER="memcached"
MAXCONN="2048"
CACHESIZE="512"
OPTIONS="-l 127.0.0.1"
EOF

	# create systemd service
	# https://www.subhosting.net/kb/how-to-run-multiple-memcached-processes-in-centos-7/
	cat >> /lib/systemd/system/memcached.service << "EOF"
[Unit]
Description=Memcached Daemon
After=network.target

[Service]
Type=simple
EnvironmentFile=/usr/local/memcached/env/memcached
ExecStart=/usr/local/memcached/bin/memcached -u $USER -p $PORT -m $CACHESIZE -c $MAXCONN

[Install]
WantedBy=multi-user.target
EOF

	systemctl daemon-reload
        systemctl enable memcached.service
        systemctl start memcached.service
        systemctl status memcached.service
	
}

main() {
	echo "main() was called"
	install_memcached
}

echo -e "This script will install memcached for you"
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
