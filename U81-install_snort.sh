#!/bin/bash
# This script will install Snort3 on your Ubuntu 24.04 machine
# setup these parameters below carefully :
HOME_NET="192.168.251.248/32"
#######################################################################################################################################
# no need to setup below , script will know it and use it automatically for u 
WIRED_INTERFACE_NAME="$(ip link show | grep '2:' | cut -d ':' -f 2 | sed 's/^ *//g')"
YOUR_SERVER_IP="$(/sbin/ip addr show $WIRED_INTERFACE_NAME | grep 'inet' | grep -v 'inet6' | tr -s ' ' | cut -d ' ' -f 3 | cut -d '/' -f 1)"
#######################################################################################################################################
# useful links: 
#
# https://kifarunix.com/install-and-configure-snort-3-on-ubuntu/
# https://www.snort.org/downloads
# https://docs.snort.org/start/installation
# 
# Posts related to error messages (on Armv7 devices): 
# -----------------------------------------------------------------------
# Snort (PID 31869756847952551) caught fatal signal: (null)
# Version: 3.1.58.0
#
# Backtrace:
# unw_get_proc_info failed: no unwind info found (-5303315249326194688)
# Segmentation fault
# -----------------------------------------------------------------------
# https://github.com/TigerVNC/tigervnc/issues/800
# https://linux.debian.bugs.dist.narkive.com/nvpduOGG/bug-932499-tigervnc-standalone-server-does-not-start-in-buster-on-arm64
# https://bugs.launchpad.net/ubuntu/+source/libunwind/+bug/2004039
# https://snort-org-site.s3.amazonaws.com/production/document_files/files/000/003/977/original/Snort_3_GA_on_CentOS_8_Stream.pdf
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=932499
# https://0xzx.com/zh-tw/2022101723502745239.html
# https://github.com/snort3/snort3/issues/285
#######################################################################################################################################
#                            <<Tested on Ubuntu 24.04 Server Edition>>
#######################################################################################################################################

say_goodbye() {
        echo "see you next time"
}

install_prerequisite() {
	apt-get update
	apt-get upgrade -y
	apt-get install cmake build-essential pkg-config dh-autoreconf -y
	apt-get install libpcap-dev libpcre3-dev \
		libnet1-dev zlib1g-dev luajit hwloc \
		libdumbnet-dev bison flex liblzma-dev openssl libssl-dev \
		pkg-config libhwloc-dev cpputest libsqlite3-dev uuid-dev \
		libcmocka-dev libnetfilter-queue-dev libmnl-dev autotools-dev \
		libluajit-5.1-dev libunwind-dev libfl-dev -y
	apt-get install libdumbnet-dev libdumbnet1 flex libhwloc15 libhwloc-dev -y
	#apt-get install luajit libluajit-5.1-dev -y
	apt-get install luajit2 libluajit2-5.1-dev -y
	apt-get install libssl-dev libpcap-dev libpcre3 libpcre3-dev -y
	apt-get install zlib1g zlib1g-dev lzma lzma-dev liblzma5 liblzma-dev -y
}

install_snort3() {
	
	# install libdaq
	cd /usr/local/src
	git clone https://github.com/snort3/libdaq.git
	cd libdaq
	./bootstrap
	./configure
	make
	make install

	# install gperftools
	cd /usr/local/src
	wget https://github.com/gperftools/gperftools/releases/download/gperftools-2.15/gperftools-2.15.tar.gz
	tar zxvf ./gperftools-2.15.tar.gz
	cd gperftools-2.15
	./configure
	make
	make install

	# install snort3
	cd /usr/local/src
	wget https://github.com/snort3/snort3/archive/refs/tags/3.1.84.0.tar.gz
	tar zxvf ./3.1.84.0.tar.gz
	cd snort3-3.1.84.0
	./configure_cmake.sh --prefix=/usr/local --enable-tcmalloc
	cd build
	make
	make install

	# check it
	ldconfig
	snort -V

}

change_nic_behavior() {
	# temporary
	ip add sh $WIRED_INTERFACE_NAME
	ip link set dev $WIRED_INTERFACE_NAME promisc on
	ip add sh $WIRED_INTERFACE_NAME

	ethtool -k $WIRED_INTERFACE_NAME | grep receive-offload
	ethtool -K $WIRED_INTERFACE_NAME gro off lro off
	ethtool -k $WIRED_INTERFACE_NAME | grep receive-offload

	# permanently
	SYSTEMD_UNIT_FILE="/lib/systemd/system/snort3-nic.service"
	cat > $SYSTEMD_UNIT_FILE << 'EOF'
[Unit]
Description=Set Snort 3 NIC in promiscuous mode and Disable GRO, LRO on boot
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ip link set dev _WIRED_INTERFACE_NAME_ promisc on
ExecStart=/usr/sbin/ethtool -K _WIRED_INTERFACE_NAME_ gro off lro off
TimeoutStartSec=0
RemainAfterExit=yes

[Install]
WantedBy=default.target
EOF
	sed -i -- "s|_WIRED_INTERFACE_NAME_|$WIRED_INTERFACE_NAME|g" $SYSTEMD_UNIT_FILE
	chmod 644 $SYSTEMD_UNIT_FILE
	chown root:root $SYSTEMD_UNIT_FILE
	systemctl daemon-reload
	systemctl enable --now snort3-nic.service
	systemctl restart snort3-nic.service
	systemctl status snort3-nic.service
}

install_rulesets() {
	mkdir /usr/local/etc/rules
	cd /usr/local/etc/rules
	wget -qO- https://www.snort.org/downloads/community/snort3-community-rules.tar.gz | tar xz -C /usr/local/etc/rules/
	ls -1 /usr/local/etc/rules/snort3-community-rules/
	CONFIG_FILE="/usr/local/etc/snort/snort.lua"
	cp $CONFIG_FILE /root/snort.lua.default

	# create custom rules for ICMP packets
	LOCAL_RULES_FILE="/usr/local/etc/rules/local.rules"
	cat > $LOCAL_RULES_FILE << "EOF"
alert icmp any any -> $HOME_NET any (msg:"ICMP connection test"; sid:1000001; rev:1;)
EOF
	# snort.lua setting
	sed -i -- "s|HOME_NET = 'any'|HOME_NET = '_HOME_NET_'|g" $CONFIG_FILE
	if [ -z "$HOME_NET" ]; then
		sed -i -- "s|_HOME_NET_|$YOUR_SERVER_IP|g" $CONFIG_FILE
	else
		sed -i -- "s|_HOME_NET_|$HOME_NET|g" $CONFIG_FILE
	fi
	sed -i -- "s|EXTERNAL_NET = 'any'|EXTERNAL_NET = '!\$HOME_NET'|g" $CONFIG_FILE
	RULE_FULL_PATH="/usr/local/etc/rules/snort3-community-rules/snort3-community.rules"
	sed -i -- "/variables = default_variables/a rules = [[\n\tinclude $RULE_FULL_PATH\n\tinclude $LOCAL_RULES_FILE\n]]\n" $CONFIG_FILE
	sed -i -- 's|variables = default_variables|variables = default_variables,|g' $CONFIG_FILE

	# log setting
	sed -i -- "/--alert_fast = { }/a alert_fast = {\n\tfile = true, \n\tpacket = false,\n\tlimit = 10,\n}\n" $CONFIG_FILE

	# verify settings
	snort -c /usr/local/etc/snort/snort.lua
	snort -c /usr/local/etc/snort/snort.lua -R $LOCAL_RULES_FILE
}

install_openappid() {
	cd /usr/local/src
	# cannot get OpenAppId-26425.tgz anymore , this file was gone and i cannot find it on the internet ???
	wget https://www.snort.org/downloads/openappid/26425 -O OpenAppId-26425.tgz
	tar -xzvf OpenAppId-26425.tgz
	cp -R odp /usr/local/lib/
	CONFIG_FILE="/usr/local/etc/snort/snort.lua"
	sed -i -- "/.*app_detector_dir =.*/a app_detector_dir = '/usr/local/lib',\nlog_stats = true,\n" $CONFIG_FILE
	mkdir /var/log/snort

	# verify settings
	snort -c /usr/local/etc/snort/snort.lua
}	

enable_snort_as_service() {
	# add non-priviledge user for snort
	useradd -r -s /usr/sbin/nologin -M -c SNORT_IDS snort

	# create systemd unit file
	SYSTEMD_UNIT_FILE="/etc/systemd/system/snort3.service"
	cat > $SYSTEMD_UNIT_FILE << "EOF"
[Unit]
Description=Snort Daemon
After=syslog.target network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/snort -c /usr/local/etc/snort/snort.lua -s 65535 -k none -l /var/log/snort -D -i _WIRED_INTERFACE_NAME_ -m 0x1b -u snort -g snort
ExecStop=/bin/kill -9 $MAINPID

[Install]
WantedBy=multi-user.target
EOF
	sed -i -- "s|_WIRED_INTERFACE_NAME_|$WIRED_INTERFACE_NAME|g" $SYSTEMD_UNIT_FILE
	chown root:root $SYSTEMD_UNIT_FILE
	chmod 644 $SYSTEMD_UNIT_FILE
	mkdir -p /var/log/snort
	chmod -R 5775 /var/log/snort
	chown -R snort:snort /var/log/snort
	systemctl daemon-reload
	systemctl enable --now snort3.service
	systemctl restart snort3.service
	systemctl status snort3.service
}

main(){
	install_prerequisite
	install_snort3
	change_nic_behavior
	install_rulesets
	###install_openappid
	enable_snort_as_service
}

echo -e "This script will install snort3 on this Machine \n"
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
