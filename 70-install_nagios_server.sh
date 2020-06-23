#!/bin/bash
#
##########################################################################################################
# this script will install nagios server for you,
# before running this script , please confirm these parameters below : 
##########################################################################################################
#
NAGIOS_LOGIN_USERNAME="nagiosadmin"
NAGIOS_LOGIN_PASSWORD="nagiospassword"
ADMIN_EMAIL_ADDRESS="annbigbig@gmail.com"
#
read -r -d '' MONITORED_HOSTS << EOV
vhost07 192.168.0.107
vhost08 192.168.0.108
EOV
#
read -r -d '' MONITORED_SERVICES << EOV
PING check_ping!100.0,20%!500.0,60%
HTTP check_http
CheckSSH check_ssh!-p 36000
CheckTomcat check_tomcat!8080!admin!admin
CheckMemcached check_memcached!11211
CheckMariaDB check_mysqld!3306!spring!spring
EOV
#
##########################################################################################################
# *** SPECIAL THANKS ***
# https://www.howtoforge.com/tutorial/ubuntu-nagios/#step-install-nrpe-service
# https://linuxconfig.org/install-nagios-on-ubuntu-18-04-bionic-beaver-linux
# https://serverfault.com/questions/849507/systemctl-doesnt-recognize-my-service-default-start-contains-no-runlevels-abo
# https://kifarunix.com/install-and-setup-nagios-core-on-ubuntu-20-04/
##########################################################################################################
# *** HINT ***
# after running this script , then you could open broweser , link to URL
# http://ip_address_you_installed_nagios_service/nagios/
# then type in $NAGIOS_LOGIN_USERNAME and $NAGIOS_LOGIN_PASSWORD to login into nagios admin GUI
##########################################################################################################
#
say_goodbye() {
        echo "goodbye everyone"
}

remove_previous_installation() {
        # stop service
	systemctl stop apache2
	systemctl stop nagios.service
	systemctl disable apache2
	systemctl disable nagios.service

        # remove apache2 
        apt-get purge -y apache2 php php-gd sendmail
        apt-get autoremove -y

        # remove nagios
        rm -rf /usr/local/src/nagios*
        rm -rf /usr/local/nagios*
}

install_prerequisites() {
        apt-get update
        apt-get install -y wget build-essential apache2 php php-gd libgd-dev sendmail unzip
        apt-get install -y mailutils
	apt-get install -y autoconf libc6 make libapache2-mod-php
}

add_users_and_groups() {
        useradd nagios
        groupadd nagcmd
        usermod -a -G nagcmd nagios
        usermod -a -G nagios,nagcmd www-data
}

install_nagios() {
        # Install Nagios Core
        cd /usr/local/src/
        wget https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.4.6.tar.gz
        tar -xzf nagios*.tar.gz
        cd nagios-4.4.6
        ./configure --with-nagios-group=nagios --with-command-group=nagcmd
        make all
        make install
        make install-commandmode
        make install-init
        make install-config
        /usr/bin/install -c -m 644 sample-config/httpd.conf /etc/apache2/sites-available/nagios.conf
        cp -R contrib/eventhandlers/ /usr/local/nagios/libexec/
        chown -R nagios:nagios /usr/local/nagios/libexec/eventhandlers

        # Install the Nagios Plugins
        cd /usr/local/src/
	wget https://nagios-plugins.org/download/nagios-plugins-2.3.3.tar.gz
        tar -xzf nagios-plugins*.tar.gz
        cd ./nagios-plugins-2.3.3/
        ./configure --with-nagios-user=nagios --with-nagios-group=nagios --with-openssl
        make
        make install

        # Download all of the service checkers
        cd /tmp
	wget https://raw.githubusercontent.com/dduenasd/check_tomcat.py/master/check_tomcat.py
	mv /tmp/check_tomcat.py /usr/local/nagios/libexec/
        chown nagios:nagios /usr/local/nagios/libexec/check_tomcat.py
        chmod 755 /usr/local/nagios/libexec/check_tomcat.py

        apt-get install libcache-memcached-perl -y
        cd /tmp
        wget https://raw.githubusercontent.com/willixix/WL-NagiosPlugins/master/check_memcached.pl
        mv /tmp/check_memcached.pl /usr/local/nagios/libexec/
        chown nagios:nagios /usr/local/nagios/libexec/check_memcached.pl
        chmod 755 /usr/local/nagios/libexec/check_memcached.pl

        apt-get install libdbi-perl -y
        apt-get install libdbd-mysql-perl -y
        cd /tmp
        wget https://raw.githubusercontent.com/willixix/WL-NagiosPlugins/master/check_mysqld.pl
        mv /tmp/check_mysqld.pl /usr/local/nagios/libexec/
        chown nagios:nagios /usr/local/nagios/libexec/check_mysqld.pl
        chmod 755 /usr/local/nagios/libexec/check_mysqld.pl

}

edit_config_files() {
        sed -i -- 's|#cfg_dir=/usr/local/nagios/etc/servers|cfg_dir=/usr/local/nagios/etc/servers|g' /usr/local/nagios/etc/nagios.cfg
        mkdir -p /usr/local/nagios/etc/servers
        sed -i -- "s|nagios@localhost|$ADMIN_EMAIL_ADDRESS|g" /usr/local/nagios/etc/objects/contacts.cfg

        # Configuration for localhost
        sed -i -- 's|check_ssh|check_ssh!-p 36000|g' /usr/local/nagios/etc/objects/localhost.cfg

        # define all of the check commands
cat >> /usr/local/nagios/etc/objects/commands.cfg << "EOF"
# 'check_tomcat' command definition
define command{
        command_name    check_tomcat
        command_line    $USER1$/check_tomcat.py -H $HOSTADDRESS$ -p $ARG1$ -u $ARG2$ -a $ARG3$ -m status
        }

# 'check_memcached' command definition
define command{
        command_name    check_memcached
        command_line    $USER1$/check_memcached.pl -H $HOSTADDRESS$ -p $ARG1$
        }

# 'check_mysqld' command definition
define command{
        command_name    check_mysqld
        command_line    $USER1$/check_mysqld.pl -H $HOSTADDRESS$ -P $ARG1$ -u $ARG2$ -p $ARG3$
        }
EOF

        # enable Apache modules
        /usr/sbin/a2enmod rewrite
        /usr/sbin/a2enmod cgi

        # set login username and passwords
        echo $NAGIOS_LOGIN_PASSWORD | htpasswd -i -c /usr/local/nagios/etc/htpasswd.users $NAGIOS_LOGIN_USERNAME

        # enable the Nagios virtualhost
        ln -s /etc/apache2/sites-available/nagios.conf /etc/apache2/sites-enabled/

	# /etc/init.d/nagios   ----->   for supressing error messages when nagios service start at first time
	cat > /etc/init.d/nagios << "EOF"
DESC="Nagios"
NAME=nagios
DAEMON=/usr/local/nagios/bin/$NAME
DAEMON_ARGS="-d /usr/local/nagios/etc/nagios.cfg"
PIDFILE=/usr/local/nagios/var/$NAME.lock
EOF
	chmod 755 /etc/init.d/nagios
	chown root:root /etc/init.d/nagios

	# systemd unit file
	cat > /lib/systemd/system/nagios.service << "EOF"
[Unit]
Description=Nagios
BindTo=network.target

[Install]
WantedBy=multi-user.target

[Service]
Type=simple
User=nagios
Group=nagios
ExecStart=/usr/local/nagios/bin/nagios /usr/local/nagios/etc/nagios.cfg
EOF

        # configure hosts you wanna monitor in LAN
        while read -r lineX; do
              SHORT_HOSTNAME="$(/bin/echo $lineX | cut -d ' ' -f 1)"
              IPV4_ADDRESS="$(/bin/echo $lineX | cut -d ' ' -f 2)"
              cat > /usr/local/nagios/etc/servers/$SHORT_HOSTNAME.cfg << "EOF"
# Ubuntu Host configuration file

define host {
        use                          linux-server
        host_name                    SHORT_HOSTNAME
        alias                        SHORT_HOSTNAME
        address                      IPV4_ADDRESS
        register                     1
}

EOF
              sed -i -- "s|SHORT_HOSTNAME|$SHORT_HOSTNAME|g" /usr/local/nagios/etc/servers/$SHORT_HOSTNAME.cfg
              sed -i -- "s|IPV4_ADDRESS|$IPV4_ADDRESS|g" /usr/local/nagios/etc/servers/$SHORT_HOSTNAME.cfg

              while read -r lineY; do
                   SERVICE_DESCRIPTION="$(/bin/echo $lineY | cut -d ' ' -f 1)"
                   CHECK_COMMAND="$(/bin/echo $lineY | cut -d ' ' -f 2)"
                   EXTRA_PARAMETER_AT_3RD_COLUMN="$(/bin/echo $lineY | cut -d ' ' -f 3)"
                   cat >> /usr/local/nagios/etc/servers/$SHORT_HOSTNAME.cfg << "EOF"
define service {
      host_name                       SHORT_HOSTNAME
      service_description             SERVICE_DESCRIPTION
      check_command                   CHECK_COMMAND EXTRA_PARAMETER_AT_3RD_COLUMN
      max_check_attempts              2
      check_interval                  2
      retry_interval                  2
      check_period                    24x7
      check_freshness                 1
      contact_groups                  admins
      notification_interval           2
      notification_period             24x7
      notifications_enabled           1
      register                        1
}

EOF
                   sed -i -- "s|SHORT_HOSTNAME|$SHORT_HOSTNAME|g" /usr/local/nagios/etc/servers/$SHORT_HOSTNAME.cfg
                   sed -i -- "s|SERVICE_DESCRIPTION|$SERVICE_DESCRIPTION|g" /usr/local/nagios/etc/servers/$SHORT_HOSTNAME.cfg
                   sed -i -- "s|CHECK_COMMAND|$CHECK_COMMAND|g" /usr/local/nagios/etc/servers/$SHORT_HOSTNAME.cfg
                   sed -i -- "s|EXTRA_PARAMETER_AT_3RD_COLUMN|$EXTRA_PARAMETER_AT_3RD_COLUMN|g" /usr/local/nagios/etc/servers/$SHORT_HOSTNAME.cfg
              done <<< "$MONITORED_SERVICES"

        done <<< "$MONITORED_HOSTS"

        # check if any config syntax error exist
        /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg

}

start_nagios_service() {
	# move daemon file to /etc/systemd/system/
	mv /etc/init.d/nagios /etc/systemd/system/
	systemctl daemon-reload

        # make nagios service autostart and start it now
	systemctl enable nagios.service
	systemctl start nagios.service

        # make apache2 service autostart and start it now
        systemctl enable apache2
        systemctl restart apache2
}

main() {
        remove_previous_installation
        install_prerequisites
        add_users_and_groups
        install_nagios
        edit_config_files
        start_nagios_service
}

echo -e "This script will install nagios server on this host \n"
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


