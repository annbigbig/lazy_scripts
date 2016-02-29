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
	wget http://nginx.org/download/nginx-1.9.12.tar.gz
	wget https://www.openssl.org/source/openssl-1.0.2f.tar.gz
	wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.38.tar.gz
	wget http://zlib.net/zlib-1.2.8.tar.gz

	tar -zxvf ./nginx-1.9.12.tar.gz
	tar -zxvf ./openssl-1.0.2f.tar.gz
	tar -zxvf ./pcre-8.38.tar.gz
	tar -zxvf ./zlib-1.2.8.tar.gz

	chown -R root:root ./nginx-1.9.12
	chown -R root:root ./openssl-1.0.2f
	chown -R root:root ./pcre-8.38
	chown -R root:root ./zlib-1.2.8

	cd ./nginx-1.9.12
	./configure --prefix=/usr/local/nginx-1.9.12 \
	--user=www-data \
	--group=www-data \
	--with-http_ssl_module \
	--with-pcre=/usr/local/src/pcre-8.38 \
	--with-zlib=/usr/local/src/zlib-1.2.8 \
	--with-openssl=/usr/local/src/openssl-1.0.2f \
	--with-http_stub_status_module

	make
	make install

	ln -s /usr/local/nginx-1.9.12 /usr/local/nginx

	echo "done."
}

post_installation() {
	echo "generating /lib/systemd/system/nginx.service"
cat >> /lib/systemd/system/nginx.service << "EOF"
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/usr/local/nginx/logs/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

	systemctl daemon-reload
        systemctl enable nginx.service
        systemctl start nginx.service
        systemctl status nginx.service

	echo "done."
}

main() {
	echo "main() was called"
	install_prerequisite
	remove_apache
	install_nginx
	#generate_config_file
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
