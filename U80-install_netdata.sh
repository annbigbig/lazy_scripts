#!/bin/bash
# This script will install Netdata on your Ubuntu 22.04 machine
# 
#######################################################################################################################################
# no need to setup below , script will know it and use it automatically for u 
WIRED_INTERFACE_NAME="$(ip link show | grep '2:' | cut -d ':' -f 2 | sed 's/^ *//g')"
YOUR_SERVER_IP="$(/sbin/ip addr show $WIRED_INTERFACE_NAME | grep 'inet' | grep -v 'inet6' | tr -s ' ' | cut -d ' ' -f 3 | cut -d '/' -f 1)"
NETDATA_INSTALLED="$(apt list --installed 2>/dev/null | grep netdata | wc -l)"
#######################################################################################################################################
# useful links: 
# https://wiki.crowncloud.net/?how_to_Install_netdata_monitoring_tool_ubuntu_22_04
# https://sysadminxpert.com/monitor-mysql-or-mariadb-databases-using-netdata-on-centos-7/
# https://learn.netdata.cloud/docs/data-collection/monitor-anything/Databases/MySQL
# https://www.linuxbabe.com/monitoring/linux-server-performance-monitoring-with-netdata
# https://learn.netdata.cloud/docs/data-collection/monitor-anything/Databases/MySQL
# https://github.com/netdata/go.d.plugin/blob/master/modules/mysql/README.md
# https://answers.launchpad.net/ubuntu/+source/netdata/+question/701962
# https://itsfoss.com/debian-vs-ubuntu/
#######################################################################################################################################
#                            <<Tested on Ubuntu 22.04 Server Edition>>
# Hint : Netdata uses /usr/lib/netdata/python.d/nginx.chart.py to get metric data
#######################################################################################################################################

say_goodbye() {
        echo "see you next time"
}

install_netdata() {
	if [ $NETDATA_INSTALLED -le 0 ]; then
		echo -e "Begin to install netdata ... \n"
		apt-get update
		apt-get install netdata -y
		echo -e "done. \n"
	
	else
		echo -e "Netdata has alreadly installed , \n"
		echo -e "no need to do anything else. \n"
	fi
}

edit_config_file() {
	CONFIG_FILE="/etc/netdata/netdata.conf"
	sed -i -- "s|127.0.0.1|$YOUR_SERVER_IP|g" $CONFIG_FILE
}

restart_netdata_service() {
	systemctl enable netdata.service
	systemctl restart netdata.service
	systemctl status netdata.service
}

main(){
	install_netdata
	edit_config_file
	restart_netdata_service
}

echo -e "This script will install netdata monitoring tool on this Machine \n"
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
