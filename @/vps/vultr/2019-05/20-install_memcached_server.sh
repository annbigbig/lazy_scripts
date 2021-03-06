#!/bin/bash
#
#####################

say_goodbye() {
	echo "goodbye everyone"
}

install_memcached_server() {
   apt-get update
   apt-get install -y memcached
   systemctl enable memcached
   sed -i -- "s|-l 127.0.0.1|-l 0.0.0.0|g" /etc/memcached.conf
   sed -i -- "s|-m 64|-m 256|g" /etc/memcached.conf
   systemctl restart memcached
   systemctl status memcached

}


main() {
	install_memcached_server
}

echo -e "This script will install memcached server for you \n"
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

