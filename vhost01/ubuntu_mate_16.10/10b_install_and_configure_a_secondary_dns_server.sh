#!/bin/bash
#
# This script will configure a Bind9 server as secondary DNS server
# tested on Ubuntu mate 17.04
#
#####################

say_goodbye() {
	echo "goodbye everyone"
}

install_bind_server() {
        BIND9_INSTALL="$(dpkg-query -l bind9 | grep bind9 | cut -d " " -f 1)"
        if [ "$BIND9_INSTALL" == "un" ]; then
                echo -e "install bind9 server ... \n"
                apt-get update
                apt-get install -y bind9 bind9utils bind9-doc
		apt autoremove
                echo -e "done"
        fi
}

sync_system_time() {
        NTPDATE_INSTALL="$(dpkg --get-selections | grep ntpdate)"
        if [ -z "$NTPDATE_INSTALL" ]; then
                apt-get update
                apt-get install -y ntpdate
        fi
        ntpdate -v pool.ntp.org
}

edit_config_file() {
        # ipv4 mode
	sed -i -- 's/-u bind/-4 -u bind/g' /lib/systemd/system/bind9.service

	# options
	mv /etc/bind/named.conf.options /etc/bind/named.conf.options.default
	cat > /etc/bind/named.conf.options << "EOF"
acl "trusted" {
        10.2.2.0/24;	# local subnet
	10.8.0.0/24;    # vpn subnet
};

options {
        directory "/var/cache/bind";
        recursion yes;                      # enables resursive queries
        allow-recursion { trusted; };       # allows recursive queries from "trusted" clients
        listen-on { localnets; };           # ns2 private IP address - listen on private network only
        allow-transfer { none; };           # do not allow zone transfers

        forwarders {
                8.8.8.8;
                8.8.4.4;
        };

        dnssec-validation auto;
        auth-nxdomain no;    # conform to RFC1035
        listen-on-v6 { none; };
};
EOF

        # configure Local file
	mv /etc/bind/named.conf.local /etc/bind/named.conf.local.default
        cat > /etc/bind/named.conf.local << "EOF"
zone "dq5rocks.com" {
    type slave;
    file "/var/cache/bind/db.dq5rocks.com";
    masters { 10.2.2.131; };           # ns1 private IP address
};

zone "2.2.10.in-addr.arpa" {
    type slave;
    file "/var/cache/bind/db.10.2.2";
    masters { 10.2.2.131; };           # ns1 private IP address
};
EOF

        # check if there are syntax error in config files or not
        named-checkconf
}

start_bind_service() {
        systemctl daemon-reload
        systemctl enable bind9.service
        systemctl restart bind9.service
        systemctl status bind9.service
}

main() {
	install_bind_server
	sync_system_time
	edit_config_file
	start_bind_service
}

echo -e "This script will install Bind9 server (secondary) on this host \n"
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

