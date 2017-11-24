#!/bin/bash
#
# This script will configure a Bind9 server as primary DNS server with chroot environment
# (tested on Ubuntu mate 16.10/17.04)
#
# All of the commands used here were inspired by this article : 
# http://www.linuxfromscratch.org/blfs/view/cvs/server/bind.html
#####################

say_goodbye() {
	echo "goodbye everyone"
}

unlock_apt_bala_bala(){
        #
        # This function is only needed if you ever seen error messages below
        # E: Could not get lock /var/lib/dpkg/lock - open (11 Resource temporarily unavailable)
        # E: Unable to lock the administration directory (/var/lib/dpkg/) is another process using it?
        #
        rm -rf /var/lib/apt/lists/lock
        rm -rf /var/cache/apt/archives/lock
        rm -rf /var/lib/dpkg/lock
        dpkg --configure -a
}

update_system() {
        # this problem maybe occur
        # https://bugs.launchpad.net/ubuntu/+source/aptitude/+bug/1543280
        # before install/upgrade package, change directory permission number to 777 for it
        chmod 777 /var/lib/update-notifier/package-data-downloads/partial
        apt-get update
        apt-get dist-upgrade -y
        apt autoremove -y
        # after installation , change it back to its original value 755
        chmod 755 /var/lib/update-notifier/package-data-downloads/partial
}

sync_system_time() {
        NTPDATE_INSTALL="$(dpkg --get-selections | grep ntpdate)"
        if [ -z "$NTPDATE_INSTALL" ]; then
                apt-get install -y ntpdate
        fi
                ntpdate -v pool.ntp.org
}

remove_previous_version() {
	NAMED_IS_RUNNING="$(/bin/netstat -anp | grep named | wc -l)"
        if [ "$NAMED_IS_RUNNING" -gt 0 ] || [ -f /lib/systemd/system/bind9.service ]; then
              systemctl stop bind9.service
              systemctl disable bind9.service
        fi

        # if binary package is installed , remove it
        NAMED_BINARY_INSTALLED="$(dpkg-query -l bind9 | grep bind9 | cut -d ' ' -f 1)"
        if [ "$NAMED_BINARY_INSTALLED" == "ii" ]; then
              apt-get purge -y bind9 bind9utils bind9-doc
              apt-get autoremove -y
              rm -rf /etc/bind
              rm -rf /var/cache/bind
        fi

        # if source installation exists , remove it
        if [ -L /usr/local/bind9 ] && [ -d /usr/local/bind9 ]; then
            rm -rf /usr/local/bind9
            rm -rf /usr/local/bind-9*
            rm -rf /usr/share/doc/bind-9*
            rm -rf /srv/named
        fi
}

install_dependencies() {
	apt-get install -y libcap-dev libxml2 libkrb5-dev libssl-dev
}

install_bind_server() {
	cd /usr/local/src/
	wget ftp://ftp.isc.org/isc/bind9/9.11.1/bind-9.11.1.tar.gz
	MD5SUM="$(md5sum ./bind-9.11.1.tar.gz | tr -s ' ' | cut -d ' ' -f 1)"
	if [ "$MD5SUM" != "c384ab071d902bac13487c1268e5a32f" ]; then
		echo -e "md5 checksum of downloaded tarball is error, dangerous.\n"
		exit 1
	fi
	echo -e "md5 checksum pass!"
	tar zxvf ./bind-9.11.1.tar.gz
	cd bind-9.11.1
        ./configure --prefix=/usr/local/bind-9.11.1           \
	            --sysconfdir=/etc                         \
	            --localstatedir=/var                      \
	            --mandir=/usr/share/man                   \
		    --libdir=/usr/lib/x86_64-linux-gnu        \
	            --enable-threads                          \
	            --with-libtool                            \
	            --disable-static                          \
	            --with-randomdev=/dev/urandom
	make
	make install
        ln -s /usr/local/bind-9.11.1 /usr/local/bind9
	install -v -m755 -d /usr/share/doc/bind-9.11.1/{arm,misc}
	install -v -m644 doc/arm/*.html /usr/share/doc/bind-9.11.1/arm
	install -v -m644 doc/misc/{dnssec,ipv6,migrat*,options,rfc-compliance,roadmap,sdb} /usr/share/doc/bind-9.11.1/misc
}

export_sbin_dir_to_path() {
        cat > /etc/profile.d/named.sh << EOF
export NAMED_HOME=/usr/local/bind9
export PATH=\$NAMED_HOME/bin:\$NAMED_HOME/sbin:\$PATH
EOF
        source /etc/profile
}

create_named_user_and_group() {
        groupadd -g 200 named &&
        useradd -c "BIND Owner" -g named -s /bin/false -u 200 named
}

create_necessary_directories() {
        # (directories overview) 
        #
        #   /srv
        #     +-- named
        #          +-- dev
        #          +-- etc
        #          |    +-- namedb
        #          |           +-- slave
	#          |           +-- pz
        #          +-- usr
        #          |    +-- lib
	#          |         +-- x86_64-linux-gnu 
        #          |                        +-- openssl-1.0.0
        #          |                                    +-- engines 
	#          |
        #          +-- var
        #               +-- run
        #          
	#          
        #
        install -d -m770 -o named -g named /srv/named
        cd /srv/named
        mkdir -p dev etc/namedb/{slave,pz} var/run/named
	mkdir -p usr/lib/x86_64-linux-gnu/openssl-1.0.0/engines
        mknod /srv/named/dev/null c 1 3
        mknod /srv/named/dev/urandom c 1 9
        chmod 666 /srv/named/dev/{null,urandom}
        cp /etc/localtime etc
        touch /srv/named/managed-keys.bind
	cp /usr/lib/x86_64-linux-gnu/openssl-1.0.0/engines/*.so /srv/named/usr/lib/x86_64-linux-gnu/openssl-1.0.0/engines
}

edit_rsyslog_config_and_restart_it() {
        echo "\$AddUnixListenSocket /srv/named/dev/log" > /etc/rsyslog.d/bind-chroot.conf
        systemctl restart rsyslog.service
}

edit_config_file() {
        # systemd unit file
	cat > /lib/systemd/system/bind9.service << "EOF"
[Unit]
Description=BIND Domain Name Server
Documentation=man:named(8)
After=network.target
Wants=nss-lookup.target
Before=nss-lookup.target

[Service]
ExecStart=/usr/local/bind9/sbin/named -f -4 -u named -t /srv/named -c /etc/named.conf
ExecReload=/usr/local/bind9/sbin/rndc reload
ExecStop=/usr/local/bind9/sbin/rndc stop

[Install]
WantedBy=multi-user.target
EOF

        # /etc/rndc.conf and /srv/named/etc/named.conf
	rndc-confgen -r /dev/urandom -b 512 > /etc/rndc.conf &&
	sed '/conf/d;/^#/!d;s:^# ::' /etc/rndc.conf > /srv/named/etc/named.conf

        # append to /srv/named/etc/named.conf
cat >> /srv/named/etc/named.conf << "EOF"
acl "trusted" {
        127.0.0.0/8;    # loopback
        10.2.2.0/24;    # local subnet
        10.8.0.0/24;    # vpn subnet
};

options {
        directory "/etc/namedb";
        pid-file "/var/run/named.pid";
        statistics-file "/var/run/named.stats";
        recursion yes;                      # enables resursive queries
        allow-recursion { trusted; };       # allows recursive queries from "trusted" clients
        listen-on { localnets; };           # ns1 private IP address - listen on private network only
        allow-transfer { trusted; };        # allow zone transfers only in trusted intranet

        forwarders {
	                8.8.8.8;
	                8.8.4.4;
        };

        dnssec-validation auto;
        auth-nxdomain no;    # conform to RFC1035
        listen-on-v6 { none; };
};

zone "." {
	type hint;
	file "pz/db.root";
};

zone "localhost" {
	type master;
	file "pz/db.local";
};

zone "127.in-addr.arpa" {
	type master;
	file "pz/db.127";
};

zone "0.in-addr.arpa" {
	type master;
	file "pz/db.0";
};

zone "255.in-addr.arpa" {
	type master;
	file "pz/db.255";
};

zone "dq5rocks.com" {
        type master;
        file "pz/db.dq5rocks.com";                # zone file path
        allow-transfer { 10.2.2.134; };           # private IP address of secondary DNS Server
};

zone "geniussucks.com" {
        type master;
        file "pz/db.geniussucks.com";             # zone file path
        allow-transfer { 10.2.2.134; };           # private IP address of secondary DNS Server
};

zone "2.2.10.in-addr.arpa" {
        type master;
        file "pz/db.10.2.2";                      # 10.2.2.0/24 subnet
        allow-transfer { 10.2.2.134; };           # private IP address of secondary DNS Server
};	

    // Bind 9 now logs by default through syslog (except debug).
    // These are the default logging rules.

logging {
        category default { default_syslog; default_debug; };
        category unmatched { null; };

        channel default_syslog {
            syslog daemon;                  // send to syslog's daemon
                                            // facility
            severity info;                  // only send priority info
                                            // and higher
        };

        channel default_debug {
            file "named.run";               // write to named.run in
	                                    // the working directory
					    // Note: stderr is used instead
					    // of "named.run"
					    // if the server is started
					    // with the '-f' option
            severity dynamic;               // log at the server's
	                                    // current debug level
        };

	channel default_stderr {
            stderr;                         // writes to stderr
	    severity info;                  // only send priority info
	                                    // and higher
        };

	channel null {
	    null;                           // toss anything sent to
	                                    // this channel
	};
};
EOF

        # db.root
        cat > /srv/named/etc/namedb/pz/db.root << "EOF"
.                       6D  IN      NS      A.ROOT-SERVERS.NET.
.                       6D  IN      NS      B.ROOT-SERVERS.NET.
.                       6D  IN      NS      C.ROOT-SERVERS.NET.
.                       6D  IN      NS      D.ROOT-SERVERS.NET.
.                       6D  IN      NS      E.ROOT-SERVERS.NET.
.                       6D  IN      NS      F.ROOT-SERVERS.NET.
.                       6D  IN      NS      G.ROOT-SERVERS.NET.
.                       6D  IN      NS      H.ROOT-SERVERS.NET.
.                       6D  IN      NS      I.ROOT-SERVERS.NET.
.                       6D  IN      NS      J.ROOT-SERVERS.NET.
.                       6D  IN      NS      K.ROOT-SERVERS.NET.
.                       6D  IN      NS      L.ROOT-SERVERS.NET.
.                       6D  IN      NS      M.ROOT-SERVERS.NET.
A.ROOT-SERVERS.NET.     6D  IN      A       198.41.0.4
A.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:503:ba3e::2:30
B.ROOT-SERVERS.NET.     6D  IN      A       192.228.79.201
B.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:500:84::b
C.ROOT-SERVERS.NET.     6D  IN      A       192.33.4.12
C.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:500:2::c
D.ROOT-SERVERS.NET.     6D  IN      A       199.7.91.13
D.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:500:2d::d
E.ROOT-SERVERS.NET.     6D  IN      A       192.203.230.10
E.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:500:a8::e
F.ROOT-SERVERS.NET.     6D  IN      A       192.5.5.241
F.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:500:2f::f
G.ROOT-SERVERS.NET.     6D  IN      A       192.112.36.4
H.ROOT-SERVERS.NET.     6D  IN      A       198.97.190.53
H.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:500:1::53
I.ROOT-SERVERS.NET.     6D  IN      A       192.36.148.17
I.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:7fe::53
J.ROOT-SERVERS.NET.     6D  IN      A       192.58.128.30
J.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:503:c27::2:30
K.ROOT-SERVERS.NET.     6D  IN      A       193.0.14.129
K.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:7fd::1
L.ROOT-SERVERS.NET.     6D  IN      A       199.7.83.42
L.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:500:9f::42
M.ROOT-SERVERS.NET.     6D  IN      A       202.12.27.33
M.ROOT-SERVERS.NET.     6D  IN      AAAA    2001:dc3::35
EOF

        # db.local
	cat > /srv/named/etc/namedb/pz/db.local << "EOF"
;
; BIND data file for local loopback interface
;
$TTL	604800
@	IN	SOA	localhost. root.localhost. (
			      2		; Serial
			 604800		; Refresh
			  86400		; Retry
			2419200		; Expire
			 604800 )	; Negative Cache TTL
;
@	IN	NS	localhost.
@	IN	A	127.0.0.1
@	IN	AAAA	::1
EOF

        # db.127
        cat > /srv/named/etc/namedb/pz/db.127 << "EOF"
;
; BIND reverse data file for local loopback interface
;
$TTL	604800
@	IN	SOA	localhost. root.localhost. (
			      1		; Serial
			 604800		; Refresh
			  86400		; Retry
			2419200		; Expire
			 604800 )	; Negative Cache TTL
;
@	IN	NS	localhost.
1.0.0	IN	PTR	localhost.
EOF

        # db.0
	cat > /srv/named/etc/namedb/pz/db.0 << "EOF"
;
; BIND reverse data file for broadcast zone
;
$TTL	604800
@	IN	SOA	localhost. root.localhost. (
			      1		; Serial
			 604800		; Refresh
			  86400		; Retry
			2419200		; Expire
			 604800 )	; Negative Cache TTL
;
@	IN	NS	localhost.
EOF

        # db.255
	cat > /srv/named/etc/namedb/pz/db.255 << "EOF"
;
; BIND reverse data file for broadcast zone
;
$TTL	604800
@	IN	SOA	localhost. root.localhost. (
			      1		; Serial
			 604800		; Refresh
			  86400		; Retry
			2419200		; Expire
			 604800 )	; Negative Cache TTL
;
@	IN	NS	localhost.
EOF

        # db.dq5rocks.com (forward zone)
        cat > /srv/named/etc/namedb/pz/db.dq5rocks.com << "EOF"
$TTL    604800
@       IN      SOA     vhost03.dq5rocks.com. admin.dq5rocks.com. (
                  3     ; Serial
             604800     ; Refresh
              86400     ; Retry
            2419200     ; Expire
             604800 )   ; Negative Cache TTL
;
; name servers - NS records
                              IN      NS     vhost03.dq5rocks.com.
                              IN      NS     vhost04.dq5rocks.com.

; A records
laptop.dq5rocks.com.          IN      A      10.2.2.90
vhost01.dq5rocks.com.         IN      A      10.2.2.131
vhost03.dq5rocks.com.         IN      A      10.2.2.133
vhost04.dq5rocks.com.         IN      A      10.2.2.134

; MX records
dq5rocks.com.                 IN      MX     10 vhost01.dq5rocks.com.

; SPF records
dq5rocks.com.                 IN      TXT    "v=spf1 mx mx:dq5rocks.com -all"

; DKIM records
dkim._domainkey.dq5rocks.com. IN      TXT    (
  "v=DKIM1; p="
  "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC7nrZcx/hXMBCUAIvl99AqNQK0"
  "36cHosKTnNSJfGTTIygano5JZhzipe/ZgcvueuumrqX9koHEHkMqWCTJGN1MrB+c"
  "1mgFhBiPTIa86SrbcM7cwgz4M0qdDrS/3DooO7ww8MwLb+Qwrg8Tn5iKwW2NV3cy"
  "nfELFRFlmoBvDncZxQIDAQAB")

EOF

        # db.geniussucks.com (forward zone)
        cat > /srv/named/etc/namedb/pz/db.geniussucks.com << "EOF"
$TTL    604800
@       IN      SOA     vhost03.geniussucks.com. admin.geniussucks.com. (
                  3     ; Serial
             604800     ; Refresh
              86400     ; Retry
            2419200     ; Expire
             604800 )   ; Negative Cache TTL
;
; name servers - NS records
                              IN      NS      vhost03.geniussucks.com.
                              IN      NS      vhost04.geniussucks.com.

; A records
desktop.geniussucks.com.      IN      A       10.2.2.110
vhost02.geniussucks.com.      IN      A       10.2.2.132
vhost03.geniussucks.com.      IN      A       10.2.2.133
vhost04.geniussucks.com.      IN      A       10.2.2.134

; MX records
geniussucks.com.              IN      MX     10 vhost02.geniussucks.com.

EOF

        # db.10.2.2 (reverse zone) 
        cat > /srv/named/etc/namedb/pz/db.10.2.2 << "EOF"
$TTL    604800
@       IN      SOA     dq5rocks.com. admin.dq5rocks.com. (
                              3         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
; name servers
      IN      NS      vhost03.dq5rocks.com.
      IN      NS      vhost04.dq5rocks.com.

; PTR Records
131   IN      PTR     vhost01.dq5rocks.com.        ; 10.2.2.131
133   IN      PTR     vhost03.dq5rocks.com.        ; 10.2.2.133
134   IN      PTR     vhost04.dq5rocks.com.        ; 10.2.2.134
90    IN      PTR     laptop.dq5rocks.com.         ; 10.2.2.90
EOF

        # set directory permissions
        chown -R named:named /srv/named

        # check if there are syntax error in config files / zone files or not
	named-checkconf -t /srv/named
	named-checkzone dq5rocks.com /srv/named/etc/namedb/pz/db.dq5rocks.com
	named-checkzone 2.2.10.in-addr.arpa /srv/named/etc/namedb/pz/db.10.2.2
}

start_bind_service() {
        systemctl daemon-reload
        systemctl enable bind9.service
        systemctl restart bind9.service
        systemctl status bind9.service
}

main() {
	unlock_apt_bala_bala
	update_system
	sync_system_time
        remove_previous_version
	install_dependencies
	install_bind_server
	export_sbin_dir_to_path
	create_named_user_and_group
	create_necessary_directories
	edit_rsyslog_config_and_restart_it
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

