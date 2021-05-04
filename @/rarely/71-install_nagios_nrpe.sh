#!/bin/bash
##########################################################################################################
# this script will install nagios nrpe server for you
##########################################################################################################

say_goodbye() {
        echo "goodbye everyone"
}

remove_previous_installation() {
        # stop service
        service nagios-nrpe-server stop

        # remove package
        apt-get purge -y nagios-nrpe-server nagios-plugins
        apt-get autoremove -y

}

install_nagios_nrpe() {
        apt-get update
        apt-get install nagios-nrpe-server nagios-plugins -y
        IP="$(/sbin/ifconfig eth0 | grep -v "inet6" | grep inet | tr -s ' ' | cut -d ' ' -f 3 | cut -d ':' -f 2)"
        sed -i -- "s|#server_address=127.0.0.1|server_address=$IP|g" /etc/nagios/nrpe.cfg
        service nagios-nrpe-server restart
}

main() {
        #remove_previous_installation
        install_nagios_nrpe
}

echo -e "This script will install nagios nrpe server on this host \n"
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

