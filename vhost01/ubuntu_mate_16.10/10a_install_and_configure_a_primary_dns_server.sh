#!/bin/bash
#
# This script will configure a Bind9 server as primary DNS server
# tested on Ubuntu mate 16.10
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
        listen-on { localnets; };           # ns1 private IP address - listen on private network only
        allow-transfer { localnets; };      # allow zone transfers only come from local subnets

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
    type master;
    file "/etc/bind/zones/db.dq5rocks.com";   # zone file path
    allow-transfer { 10.2.2.132; };           # ns2 private IP address - secondary
};

zone "2.2.10.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.10.2.2";         # 10.2.2.0/24 subnet
    allow-transfer { 10.2.2.132; };           # ns2 private IP address - secondary
};
EOF
        # create directory for placing zone files
        install -v -dm 755 /etc/bind/zones
        
        # forward zone
	cat > /etc/bind/zones/db.dq5rocks.com << "EOF"
$TTL    604800
@       IN      SOA     ns1.dq5rocks.com. admin.dq5rocks.com. (
                  3     ; Serial
             604800     ; Refresh
              86400     ; Retry
            2419200     ; Expire
             604800 )   ; Negative Cache TTL
;
; name servers - NS records
     IN      NS      ns1.dq5rocks.com.
     IN      NS      ns2.dq5rocks.com.

; name servers - A records
ns1.dq5rocks.com.          IN      A       10.2.2.131
ns2.dq5rocks.com.          IN      A       10.2.2.132

; 10.2.2.0/24 - A records
laptop.dq5rocks.com.       IN      A      10.2.2.90
desktop.dq5rocks.com.      IN      A      10.2.2.110
EOF

        # reverse zone
	cat > /etc/bind/zones/db.10.2.2 << "EOF"
$TTL    604800
@       IN      SOA     dq5rocks.com. admin.dq5rocks.com. (
                              3         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
; name servers
      IN      NS      ns1.dq5rocks.com.
      IN      NS      ns2.dq5rocks.com.

; PTR Records
131   IN      PTR     ns1.dq5rocks.com.        ; 10.2.2.131
132   IN      PTR     ns2.dq5rocks.com.        ; 10.2.2.132
90    IN      PTR     laptop.dq5rocks.com.     ; 10.2.2.90
110   IN      PTR     desktop.dq5rocks.com.    ; 10.2.2.110
EOF

        # set zone file permissions
        chown -R bind:bind /etc/bind/zones

        # check if there are syntax error in config files / zone files or not
        named-checkconf
        named-checkzone dq5rocks.com /etc/bind/zones/db.dq5rocks.com
        named-checkzone 2.2.10.in-addr.arpa /etc/bind/zones/db.10.2.2
}

start_bind_service() {
        systemctl daemon-reload
        systemctl enable bind9.service
        systemctl restart bind9.service
        systemctl status bind9.service
}

main() {
	install_bind_server
	edit_config_file
	start_bind_service
}

echo -e "This script will install Bind9 server (primary) on this host \n"
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

