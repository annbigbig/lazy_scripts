#!/bin/bash
#
# This script will configure a Bind9 server as primary DNS server with chroot environment
# (tested on Ubuntu mate 18.04 LTS)
# before running this script, please set some parameters below:
#
##########################################################################################################
#
DOMAIN_NAME="dq5rocks.com"
FIRST_OCTET="172"
SECOND_OCTET="16"
THIRD_OCTET="225"
#
TRUSTED_LOCAL_SUBNET="172.16.225.0/24"
TRUSTED_VPN_SUBNET="10.8.0.0/24"
SECONDARY_DNS_IP_ADDRESS="140.82.10.123"
#
# dont forget suffix dot . if you write a FQDN for NS/MX/A/PTR record
# each column is seperated by space
read -r -d '' DNS_RECORDS << EOV
NS vps01.dq5rocks.com.
NS vps02.dq5rocks.com.
MX vps01.dq5rocks.com. 10
MX vps02.dq5rocks.com. 20
CNAME ns1 vps01
CNAME ns2 vps02
CNAME mail1 vps01
CNAME mail2 vps02
A vps01.dq5rocks.com. 140.82.6.242
A vps02.dq5rocks.com. 140.82.10.123
A www.dq5rocks.com. 140.82.6.242
A www.dq5rocks.com. 140.82.10.123
A vps01-internal.dq5rocks.com. 172.16.225.17
A vps02-internal.dq5rocks.com. 172.16.225.18
A vps03-internal.dq5rocks.com. 172.16.225.19
PTR 17 vps01-internal.dq5rocks.com.
PTR 18 vps02-internal.dq5rocks.com.
PTR 19 vps03-internal.dq5rocks.com.
EOV
##########################################################################################################
# *** Hint ***
# how to query a specifc DNS server (ex: 140.82.6.242) ? use this command : 
#  $ nslookup www.dq5rocks.com 140.82.6.242
#  $ nslookup vps01.dq5rocks.com 140.82.6.242
#  $ nslookup 172.16.225.17 140.82.6.242
#
##########################################################################################################
# *** SPECIAL THANKS ***
# All of the commands used here were inspired by this article : 
# http://www.linuxfromscratch.org/blfs/view/cvs/server/bind.html
# https://superuser.com/questions/284187/bash-iterating-over-lines-in-a-variable
# https://stackoverflow.com/questions/23929235/multi-line-string-with-extra-space-preserved-indentation
# http://3108485.blog.51cto.com/3098485/1911116
# http://blog.chinaunix.net/uid-21142030-id-5673064.html
##########################################################################################################

say_goodbye() {
	echo "goodbye everyone"
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
	wget ftp://ftp.isc.org/isc/bind9/9.12.2-P1/bind-9.12.2-P1.tar.gz
	wget ftp://ftp.isc.org/isc/bind9/9.12.2-P1/bind-9.12.2-P1.tar.gz.sha512.asc

        # how to verify the integrity of downloaded tar.gz file ? see here:
        # https://kb.isc.org/article/AA-01225/0/Verifying-the-Integrity-of-ISC-Downloads-using-PGP-GPG.html

        PUBLIC_KEY="$(gpg --verify ./bind-9.12.2-P1.tar.gz.sha512.asc ./bind-9.12.2-P1.tar.gz 2>&1 | grep -E -i 'rsa|dsa' | tr -s ' ' | rev | cut -d ' ' -f 1 | rev)"
        IMPORT_KEY_RESULT="$(gpg --keyserver keyserver.ubuntu.com --recv $PUBLIC_KEY 2>&1 | grep 'codesign@isc.org' | wc -l)"
        VERIFY_SIGNATURE_RESULT="$(gpg --verify ./bind-9.12.2-P1.tar.gz.sha512.asc ./bind-9.12.2-P1.tar.gz 2>&1 | tr -s ' ' | grep 'BE0E 9748 B718 253A 28BB 89FF F1B1 1BF0 5CF0 2E57' | wc -l)"
        [ "$IMPORT_KEY_RESULT" -gt 0 ] && echo "pubkey $PUBLIC_KEY imported successfuly" ||  exit 2
        [ "$VERIFY_SIGNATURE_RESULT" -gt 0 ] && echo "verify signature successfully" || exit 2


	tar zxvf ./bind-9.12.2-P1.tar.gz
	cd bind-9.12.2-P1
        ./configure --prefix=/usr/local/bind-9.12.2-P1           \
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
        ln -s /usr/local/bind-9.12.2-P1 /usr/local/bind9
	install -v -m755 -d /usr/share/doc/bind-9.12.2-P1/{arm,misc}
	install -v -m644 doc/arm/*.html /usr/share/doc/bind-9.12.2-P1/arm
	install -v -m644 doc/misc/{dnssec,ipv6,migrat*,options,rfc-compliance,roadmap,sdb} /usr/share/doc/bind-9.12.2-P1/misc
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
        127.0.0.0/8;            # loopback
        TRUSTED_LOCAL_SUBNET;   # local subnet
        TRUSTED_VPN_SUBNET;     # vpn subnet
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

        dnssec-enable no;     # write this line only when host Internal(private) DNS server
        dnssec-validation no; # 'no' if used in Internal(private) DNS server, or 'auto' if used in normal situation
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

zone "DOMAIN_NAME" {
        type master;
        file "pz/db.DOMAIN_NAME";                             # zone file path
        allow-transfer { SECONDARY_DNS_IP_ADDRESS; };         # ns2 private IP address - secondary
};

zone "THIRD_OCTET.SECOND_OCTET.FIRST_OCTET.in-addr.arpa" {
        type master;
        file "pz/db.FIRST_OCTET.SECOND_OCTET.THIRD_OCTET";    # FIRST_OCTET.SECOND_OCTET.THIRD_OCTET.0/24 subnet
        allow-transfer { SECONDARY_DNS_IP_ADDRESS; };         # ns2 private IP address - secondary
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
        sed -i -- "s|TRUSTED_LOCAL_SUBNET|$TRUSTED_LOCAL_SUBNET|g" /srv/named/etc/named.conf
        sed -i -- "s|TRUSTED_VPN_SUBNET|$TRUSTED_VPN_SUBNET|g" /srv/named/etc/named.conf
        sed -i -- "s|DOMAIN_NAME|$DOMAIN_NAME|g" /srv/named/etc/named.conf
        sed -i -- "s|SECONDARY_DNS_IP_ADDRESS|$SECONDARY_DNS_IP_ADDRESS|g" /srv/named/etc/named.conf
        sed -i -- "s|FIRST_OCTET|$FIRST_OCTET|g" /srv/named/etc/named.conf
        sed -i -- "s|SECOND_OCTET|$SECOND_OCTET|g" /srv/named/etc/named.conf
        sed -i -- "s|THIRD_OCTET|$THIRD_OCTET|g" /srv/named/etc/named.conf

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
			      5		; Serial
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
			      5		; Serial
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
			      5		; Serial
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
			      5		; Serial
			 604800		; Refresh
			  86400		; Retry
			2419200		; Expire
			 604800 )	; Negative Cache TTL
;
@	IN	NS	localhost.
EOF

        # db.$DOMAIN_NAME (forward zone)
        cat > /srv/named/etc/namedb/pz/db.$DOMAIN_NAME << "EOF"
$TTL    604800
@       IN      SOA     PRIMARY_DNS_SERVER_NAME admin.DOMAIN_NAME. (
                  5     ; Serial --> increase this value then restart bind if there are any changes happend
             604800     ; Refresh
              86400     ; Retry
            2419200     ; Expire
             604800 )   ; Negative Cache TTL
;
EOF
        sed -i -- "s|DOMAIN_NAME|$DOMAIN_NAME|g" /srv/named/etc/namedb/pz/db.$DOMAIN_NAME

        # populate NS/MX/CNAME/A records into forward zone file
        while read -r line; do
           RECORD_TYPE="$(/bin/echo $line | cut -d ' ' -f 1)"
           case $RECORD_TYPE in
              NS)
                 FQDN_WITH_ENDING_DOT="$(/bin/echo $line | cut -d ' ' -f 2)"
                 sed -i -- "s|PRIMARY_DNS_SERVER_NAME|$FQDN_WITH_ENDING_DOT|g" /srv/named/etc/namedb/pz/db.$DOMAIN_NAME
                 echo "     IN     NS     $FQDN_WITH_ENDING_DOT" >> /srv/named/etc/namedb/pz/db.$DOMAIN_NAME
                      ;;
              MX)
                 FQDN_WITH_ENDING_DOT="$(/bin/echo $line | cut -d ' ' -f 2)"
                 PRIORITY_VALUE="$(/bin/echo $line | cut -d ' ' -f 3)"
                 echo "     IN     MX     $PRIORITY_VALUE     $FQDN_WITH_ENDING_DOT" >> /srv/named/etc/namedb/pz/db.$DOMAIN_NAME
                      ;;
              CNAME)
                 SHORT_CANONICAL_HOSTNAME_WITHOUT_ENDING_DOT="$(/bin/echo $line | cut -d ' ' -f 2)"
                 SHORT_REAL_HOSTNAME_WITHOUT_ENDING_DOT="$(/bin/echo $line | cut -d ' ' -f 3)"
                 echo "$SHORT_CANONICAL_HOSTNAME_WITHOUT_ENDING_DOT      IN     CNAME     $SHORT_REAL_HOSTNAME_WITHOUT_ENDING_DOT" >> /srv/named/etc/namedb/pz/db.$DOMAIN_NAME
                      ;;
              A)
                 FQDN_WITH_ENDING_DOT="$(/bin/echo $line | cut -d ' ' -f 2)"
                 IPV4_ADDRESS="$(/bin/echo $line | cut -d ' ' -f 3)"
                 echo "$FQDN_WITH_ENDING_DOT     IN     A     $IPV4_ADDRESS" >> /srv/named/etc/namedb/pz/db.$DOMAIN_NAME
                      ;;
           esac
        done <<< "$DNS_RECORDS"


        # db.$FIRST_OCTET.$SECOND_OCTET.$THIRD.OCTET (reverse zone) 
        cat > /srv/named/etc/namedb/pz/db.$FIRST_OCTET.$SECOND_OCTET.$THIRD_OCTET << "EOF"
$TTL    604800
@       IN      SOA     PRIMARY_DNS_SERVER_NAME admin.DOMAIN_NAME. (
                              5         ; Serial --> increase this value then restart bind if there are any changes happend
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
EOF
        sed -i -- "s|DOMAIN_NAME|$DOMAIN_NAME|g" /srv/named/etc/namedb/pz/db.$FIRST_OCTET.$SECOND_OCTET.$THIRD_OCTET

        # populate NS/MX/CNAME/A records into forward zone file
        while read -r line; do
           RECORD_TYPE="$(/bin/echo $line | cut -d ' ' -f 1)"
           case $RECORD_TYPE in
              NS)
                 FQDN_WITH_ENDING_DOT="$(/bin/echo $line | cut -d ' ' -f 2)"
                 sed -i -- "s|PRIMARY_DNS_SERVER_NAME|$FQDN_WITH_ENDING_DOT|g" /srv/named/etc/namedb/pz/db.$FIRST_OCTET.$SECOND_OCTET.$THIRD_OCTET
                 echo "     IN     NS     $FQDN_WITH_ENDING_DOT" >> /srv/named/etc/namedb/pz/db.$FIRST_OCTET.$SECOND_OCTET.$THIRD_OCTET
                      ;;

              PTR)
                 FOURTH_OCTET="$(/bin/echo $line | cut -d ' ' -f 2)"
                 FQDN_WITH_ENDING_DOT="$(/bin/echo $line | cut -d ' ' -f 3)"
                 echo "$FOURTH_OCTET     IN     PTR     $FQDN_WITH_ENDING_DOT     ; $FIRST_OCTET.$SECOND_OCTET.$THIRD_OCTET.$FOURTH_OCTET" >> /srv/named/etc/namedb/pz/db.$FIRST_OCTET.$SECOND_OCTET.$THIRD_OCTET
                      ;;
           esac
        done <<< "$DNS_RECORDS"

        # set directory permissions
        chown -R named:named /srv/named

        # check if there are syntax error in config files / zone files or not
	named-checkconf -t /srv/named
	named-checkzone $DOMAIN_NAME /srv/named/etc/namedb/pz/db.$DOMAIN_NAME
	named-checkzone $THIRD_OCTET.$SECOND_OCTET.$FIRST_OCTET.in-addr.arpa /srv/named/etc/namedb/pz/db.$FIRST_OCTET.$SECOND_OCTET.$THIRD_OCTET
}

start_bind_service() {
        systemctl daemon-reload
        systemctl enable bind9.service
        systemctl restart bind9.service
        systemctl status bind9.service
}

main() {
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

