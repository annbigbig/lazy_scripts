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

install_libmemcached() {
	# keyword : memaslap install
	echo -e "install libmemcached for stress tool 'memaslap'"
	apt-get install -y libevent-dev
	apt-get install -y libmemcached-dev
	echo '/usr/local/libevent/lib' > /etc/ld.so.conf.d/libevent.conf
	cd /usr/local/src
	wget https://launchpad.net/libmemcached/1.0/1.0.18/+download/libmemcached-1.0.18.tar.gz
	tar -zxvf ./libmemcached-1.0.18.tar.gz
	chown -R root:root ./libmemcached-1.0.18
	cd ./libmemcached-1.0.18/
	./configure --prefix=/usr/local/libmemcached-1.0.18 --enable-memaslap
	make
	make install
	ln -s /usr/local/libmemcached-1.0.18 /usr/local/libmemcached

	# for manpage
	cp /usr/local/libmemcached/share/man/man1/mem*.1 /usr/local/man/man1/
	mkdir -p /usr/local/man/man3
	cp /usr/local/libmemcached/share/man/man3/*.3 /usr/local/man/man3/

	# for default config file in ~/.memaslap.cnf
	cat >> ~/.memaslap.cnf << "EOF"
#comments should start with '#'
#key
#start_len end_len proportion
#
#key length range from start_len to end_len
#start_len must be equal to or greater than 16
#end_len must be equal to or less than 250
#start_len must be equal to or greater than end_len
#memaslap will generate keys according to the key range
#proportion: indicates keys generated from one range accounts for the total
generated keys
#
#example1: key range 16~100 accounts for 80%
#          key range 101~200 accounts for 10%
#          key range 201~250 accounts for 10%
#          total should be 1 (0.8+0.1+0.1 = 1)
#
#          16 100 0.8
#          101 200 0.1
#          201 249 0.1
#
#example2: all keys length are 128 bytes
#
#          128 128 1
key
128 128 1
#value
#start_len end_len proportion
#
#value length range from start_len to end_len
#start_len must be equal to or greater than 1
#end_len must be equal to or less than 1M
#start_len must be equal to or greater than end_len
#memaslap will generate values according to the value range
#proportion: indicates values generated from one range accounts for the
total generated values
#
#example1: value range 1~1000 accounts for 80%
#          value range 1001~10000 accounts for 10%
#          value range 10001~100000 accounts for 10%
#          total should be 1 (0.8+0.1+0.1 = 1)
#
#          1 1000 0.8
#          1001 10000 0.1
#          10001 100000 0.1
#
#example2: all value length are 128 bytes
#
#          128 128 1
value
2048 2048 1
#cmd
#cmd_type cmd_proportion
#
#currently memaslap only testss get and set command.
#
#cmd_type
#set     0
#get     1
#
#example: set command accounts for 50%
#         get command accounts for 50%
#         total should be 1 (0.5+0.5 = 1)
#
#         cmd
#         0    0.5
#         1    0.5
cmd
0    0.1
1.0 0.9
EOF
}

main() {
	echo "main() was called"
	install_memcached
	install_libmemcached
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
