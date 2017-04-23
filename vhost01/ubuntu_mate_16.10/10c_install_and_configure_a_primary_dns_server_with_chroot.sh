#!/bin/bash
#
# This script will configure a Bind9 server as primary DNS server with chroot environment
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

create_necessary_directories() {
        # (directories overview) 
        #
        #   /chroot
        #     +-- named
        #          +-- dev
        #          +-- etc
        #          |    +-- namedb
        #          |         +-- slave
        #          +---usr
        #          |    +---lib
        #          |         +-- x86_64-linux-gnu
        #          |                    +-----------openssl-1.0.0
        #          |                                        +---------engines
        #          |
        #          +-- var
        #          |    +-- run
        #          +-- run
        #
        #
        mkdir -p /chroot/named
        cd /chroot/named
        mkdir -p dev etc/namedb/slave usr/lib/x86_64-linux-gnu/openssl-1.0.0/engines var/run run
        chown root:root /chroot
        chmod 700 /chroot
        chown bind:bind /chroot/named
        chmod 755 /chroot/named
        mknod /chroot/named/dev/null c 1 3
        mknod /chroot/named/dev/random c 1 8
}

edit_rsyslog_config_and_restart_it() {
        echo "\$AddUnixListenSocket /chroot/named/dev/log" > /etc/rsyslog.d/bind-chroot.conf
        systemctl restart rsyslog.service
}

edit_apparmor_config_and_restart_it() {
        rm -rf /etc/apparmor.d/usr.sbin.named
        cat > /etc/apparmor.d/usr.sbin.named << "EOF"
# vim:syntax=apparmor
# Last Modified: Sat Apr 22 17:39:22 2017
#include <tunables/global>

/usr/sbin/named {
  #include <abstractions/base>
  #include <abstractions/nameservice>

  capability net_bind_service,
  capability setgid,
  capability setuid,
  capability sys_chroot,
  capability sys_resource,

  # /etc/bind should be read-only for bind
  # /var/lib/bind is for dynamically updated zone (and journal) files.
  # /var/cache/bind is for slave/stub data, since we're not the origin of it.
  # See /usr/share/doc/bind9/README.Debian.gz
  /etc/bind/** r,
  /var/lib/bind/** rw,
  /var/lib/bind/ rw,
  /var/cache/bind/** lrw,
  /var/cache/bind/ rw,

  # added for bind9 chroot environment
  /chroot/named/etc/namedb/slave/** rw,
  /chroot/named/etc/namedb/db.* r,
  /chroot/named/etc/namedb/tmp-* rw,
  /chroot/named/etc/namedb/managed-keys.* rw,
  /chroot/named/etc/** r,
  /chroot/named/dev/log w,
  /chroot/named/dev/null rw,
  /chroot/named/dev/random r,
  /chroot/named/var/run/named.pid rw,
  /chroot/named/var/run/session.key rw,
  /chroot/named/var/run/named.stats rw,
  /chroot/named/run/** rw,
  /chroot/named/usr/lib/x86_64-linux-gnu/openssl-1.0.0/engines/*.so r,

  # gssapi
  /etc/krb5.keytab kr,
  /etc/bind/krb5.keytab kr,

  # ssl
  /etc/ssl/openssl.cnf r,

  # GeoIP data files for GeoIP ACLs
  /usr/share/GeoIP/** r,

  # dnscvsutil package
  /var/lib/dnscvsutil/compiled/** rw,

  @{PROC}/net/if_inet6 r,
  @{PROC}/*/net/if_inet6 r,
  @{PROC}/sys/net/ipv4/ip_local_port_range r,
  /usr/sbin/named mr,
  /{,var/}run/named/named.pid w,
  /{,var/}run/named/session.key w,
  # support for resolvconf
  /{,var/}run/named/named.options r,

  # some people like to put logs in /var/log/named/ instead of having
  # syslog do the heavy lifting.
  /var/log/named/** rw,
  /var/log/named/ rw,

  # gssapi
  /var/lib/sss/pubconf/krb5.include.d/** r,
  /var/lib/sss/pubconf/krb5.include.d/ r,
  /var/lib/sss/mc/initgroups r,
  /etc/gss/mech.d/ r,

  # ldap
  /etc/ldap/ldap.conf r,
  /{,var/}run/slapd-*.socket rw,

  # dynamic updates
  /var/tmp/DNS_* rw,

  # Site-specific additions and overrides. See local/README for details.
  #include <local/usr.sbin.named>
}
EOF
        systemctl restart apparmor.service
}

edit_config_file() {
        # copy config and zone files and libraries into chroot dir
        cp /etc/bind/db.* /chroot/named/etc/namedb/
        cp /etc/bind/named.conf.default-zones /chroot/named/etc/
        cp /etc/bind/rndc.key /chroot/named/etc/
        cp /usr/lib/x86_64-linux-gnu/openssl-1.0.0/engines/*.so /chroot/named/usr/lib/x86_64-linux-gnu/openssl-1.0.0/engines/

        # replace all '/etc/bind' with '/etc/namedb'
        sed -i -- 's/\/etc\/bind/\/etc\/namedb/g' /chroot/named/etc/named.conf.default-zones

        # settings for ipv4 mode & chroot
        sed -i -- 's/-u bind/-4 -u bind -t \/chroot\/named -c \/etc\/named.conf/g' /lib/systemd/system/bind9.service

        # main config file
        cat > /chroot/named/etc/named.conf << "EOF"
include "/etc/rndc.key";
include "/etc/named.conf.options";
include "/etc/named.conf.local";
include "/etc/named.conf.default-zones";
EOF

	# options
	cat > /chroot/named/etc/named.conf.options << "EOF"
controls {
        inet 127.0.0.1 allow { localhost; } keys { "rndc-key"; };
};

acl "trusted" {
        10.2.2.0/24;	# local subnet
	10.8.0.0/24;    # vpn subnet
};

options {
        directory "/etc/namedb";
        pid-file "/var/run/named.pid";
        statistics-file "/var/run/named.stats";
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
        cat > /chroot/named/etc/named.conf.local << "EOF"
zone "dq5rocks.com" {
    type master;
    file "/etc/namedb/db.dq5rocks.com";       # zone file path
    allow-transfer { 10.2.2.132; };           # ns2 private IP address - secondary
};

zone "2.2.10.in-addr.arpa" {
    type master;
    file "/etc/namedb/db.10.2.2";             # 10.2.2.0/24 subnet
    allow-transfer { 10.2.2.132; };           # ns2 private IP address - secondary
};
EOF
        
        # forward zone
	cat > /chroot/named/etc/namedb/db.dq5rocks.com << "EOF"
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
	cat > /chroot/named/etc/namedb/db.10.2.2 << "EOF"
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

        # set directory permissions
        chown -R bind:bind /chroot/named

        # check if there are syntax error in config files / zone files or not
        named-checkconf
        named-checkzone dq5rocks.com /chroot/named/etc/namedb/db.dq5rocks.com
        named-checkzone 2.2.10.in-addr.arpa /chroot/named/etc/namedb/db.10.2.2
}

start_bind_service() {
        systemctl daemon-reload
        systemctl enable bind9.service
        systemctl restart bind9.service
        systemctl status bind9.service
}

main() {
	install_bind_server
	create_necessary_directories
	edit_rsyslog_config_and_restart_it
	edit_apparmor_config_and_restart_it
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

