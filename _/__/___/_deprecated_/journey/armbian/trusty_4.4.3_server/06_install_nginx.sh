#!/bin/bash

#################

say_goodbye() {
        echo "goodbye everyone"
}

install_prerequisite() {
	apt-get install -y build-essential
	apt-get install -y libtool
}

remove_apache() {
	echo "remove apache ..."
	dpkg --get-selections | grep -v deinstall | grep apache2
	apt-get remove --purge -y apache2
	apt-get autoremove -y
	echo "done."
}

install_nginx() {
	echo "install nginx ..."
	cd /usr/local/src
	wget http://nginx.org/download/nginx-1.9.15.tar.gz
	wget https://www.openssl.org/source/openssl-1.0.2g.tar.gz
	wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.38.tar.gz
	wget http://zlib.net/zlib-1.2.8.tar.gz

	tar -zxvf ./nginx-1.9.15.tar.gz
	tar -zxvf ./openssl-1.0.2g.tar.gz
	tar -zxvf ./pcre-8.38.tar.gz
	tar -zxvf ./zlib-1.2.8.tar.gz

	chown -R root:root ./nginx-1.9.15
	chown -R root:root ./openssl-1.0.2g
	chown -R root:root ./pcre-8.38
	chown -R root:root ./zlib-1.2.8

	cd ./nginx-1.9.15
	./configure --prefix=/usr/local/nginx-1.9.15 \
	--user=www-data \
	--group=www-data \
	--with-http_ssl_module \
	--with-pcre=/usr/local/src/pcre-8.38 \
	--with-zlib=/usr/local/src/zlib-1.2.8 \
	--with-openssl=/usr/local/src/openssl-1.0.2g \
	--with-http_stub_status_module

	make
	make install

	ln -s /usr/local/nginx-1.9.15 /usr/local/nginx

	echo "done."
}

generate_config_file() {
	echo "generating config file at /usr/local/nginx/conf/nginx.conf"
	rm -rf /usr/local/nginx/conf/nginx.conf
	cat >> /usr/local/nginx/conf/nginx.conf << "EOF"
user www-data;
worker_processes 4;
pid logs/nginx.pid;

events {
        worker_connections 768;
        # multi_accept on;
}

http {

    ##
    # Basic Settings
    ##

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    # server_tokens off;

    # server_names_hash_bucket_size 64;
    # server_name_in_redirect off;

    include mime.types;
    default_type application/octet-stream;

    ##
    # Logging Settings
    ##

    access_log logs/access.log;
    error_log logs/error.log;

    ##
    # Gzip Settings
    ##

    gzip on;
    gzip_disable "msie6";

    include /usr/local/nginx/conf.d/http.*.conf;
}

EOF

	mkdir /usr/local/nginx/conf.d
	cat >> /usr/local/nginx/conf.d/http.localhost.conf << "EOF"
server {
        listen 80 default_server;
        #listen 127.0.0.1:80 default_server;
        #listen [::]:80 default_server ipv6only=on;

        access_log logs/localhost.access.log;
        error_log logs/localhost.error.log;

        root /usr/local/nginx/html;
        index index.html index.htm;

        # Make site accessible from http://localhost/
        server_name localhost;

        location / {
                # First attempt to serve request as file, then
                # as directory, then fall back to displaying a 404.
                try_files $uri $uri/ /index.html;
                # Uncomment to enable naxsi on this location
                # include /etc/nginx/naxsi.rules
        }
}

EOF
	/usr/local/nginx/sbin/nginx -t -c /usr/local/nginx/conf/nginx.conf
}

post_installation() {
	echo "generating /etc/init/nginx.conf"
cat >> /etc/init/nginx.conf << "EOF"
# nginx

description "nginx http daemon"
author "George Shammas <georgyo@gmail.com>"

start on (filesystem and net-device-up IFACE=lo)
stop on runlevel [!2345]

env DAEMON=/usr/local/nginx/sbin/nginx
env PID=/usr/local/nginx/logs/nginx.pid

expect fork
respawn
respawn limit 10 5
#oom never

pre-start script
        $DAEMON -t
        if [ $? -ne 0 ]
                then exit $?
        fi
end script

exec $DAEMON
EOF
	initctl reload-configuration
	initctl list | grep nginx
	initctl start nginx
	initctl status nginx
	initctl list | grep nginx
	echo "done."
}

main() {
	echo "main() was called"
	install_prerequisite
	remove_apache
	install_nginx
	generate_config_file
	post_installation
}

echo -e "This script will install nginx and make it as system service"
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
