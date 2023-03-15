#!/bin/bash
#
#####################################################  <<Tested on Ubuntu Mate 22.04 Desktop Edition>>  #########
#
MEMCACHED_RUNNING_IP_ADDRESS="0.0.0.0"       # 0.0.0.0 for running on all network interfaces or just Private IP
MEMCACHED_RAM_SIZE="256"                       # how many RAM size that u wanna to allocate to memcached service
#
#################################################################################################################

say_goodbye() {
	echo "goodbye everyone"
}

install_memcached_server() {
	       MEMCACHED_HAS_BEEN_INSTALL=$(dpkg --get-selections | grep memcached)
        if [ -z $MEMCACHED_HAS_BEEN_INSTALL ] ; then
		apt-get update
		apt-get install -y memcached
		sed -i -- "s|-l 127.0.0.1|-l $MEMCACHED_RUNNING_IP_ADDRESS|g" /etc/memcached.conf
		sed -i -- "s|-m 64|-m $MEMCACHED_RAM_SIZE|g" /etc/memcached.conf
		systemctl enable memcached
		systemctl restart memcached
		systemctl status memcached
   	fi
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

