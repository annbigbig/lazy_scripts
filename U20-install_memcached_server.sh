#!/bin/bash
#
#####################################################  <<Tested on Ubuntu 24.04 Server Edition>>  ###############
#
MEMCACHED_RUNNING_IP_ADDRESS="0.0.0.0"        # 0.0.0.0 for running on all network interfaces or just Private IP
MEMCACHED_RAM_SIZE="256"                      # how many RAM size that u wanna to allocate to memcached service
#
#################################################################################################################

say_goodbye() {
	echo "see you next time"
}

install_memcached_server() {
	MEMCACHED_CONFIG_FILE="/etc/memcached.conf"
	MEMCACHED_HAS_BEEN_INSTALL="$(dpkg --get-selections | grep memcached | wc -l)"

        if [ $MEMCACHED_HAS_BEEN_INSTALL -eq 0 ] ; then
		apt-get update
		apt-get install -y memcached libmemcached-tools
		sed -i -- "s|-l ::1|#-l ::1|g" $MEMCACHED_CONFIG_FILE
		sed -i -- "s|-l 127.0.0.1|-l $MEMCACHED_RUNNING_IP_ADDRESS|g" $MEMCACHED_CONFIG_FILE
		sed -i -- "s|-m 64|-m $MEMCACHED_RAM_SIZE|g" $MEMCACHED_CONFIG_FILE
		systemctl enable memcached.service
		systemctl stop memcached.service
		systemctl start memcached.service
		systemctl status memcached.service
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

