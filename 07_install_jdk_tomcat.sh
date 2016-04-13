#!/bin/bash

#################

say_goodbye() {
        echo "goodbye everyone"
}

install_jdk() {
	echo -e "ready to install jdk \n"
	cd /usr/local/

        # uncomment this if you want install jdk on x64 platform
	wget --no-check-certificate \
             --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" \
             http://download.oracle.com/otn-pub/java/jdk/8u77-b03/jdk-8u77-linux-x64.tar.gz

	tar -zxvf ./jdk-8u77-linux-x64.tar.gz
	chown -R root:root ./jdk1.8.0_77
	ln -s /usr/local/jdk1.8.0_77 /usr/local/jdk
	rm -rf ./jdk-8u77-linux-x64.tar.gz

	echo -e "done."
}

install_tomcat() {
	echo -e "ready to install tomcat \n"
	apt-get install -y build-essential
	cd /usr/local
	wget http://apache.stu.edu.tw/tomcat/tomcat-8/v8.0.33/bin/apache-tomcat-8.0.33.tar.gz
	tar -zxvf ./apache-tomcat-8.0.33.tar.gz
	chown -R root:root ./apache-tomcat-8.0.33
	chmod -R a+r ./apache-tomcat-8.0.33/conf
	ln -s /usr/local/apache-tomcat-8.0.33 /usr/local/tomcat
	rm -rf ./apache-tomcat-8.0.33.tar.gz

	echo -e "build jsvc\n"
	cd /usr/local/tomcat/bin
	tar -zxvf ./commons-daemon-native.tar.gz
	cd commons-daemon-1.0.15-native-src/unix
	./configure --with-java=/usr/local/jdk
	make
	cp jsvc ../..
	cd /usr/local/tomcat/bin
	ls -al|grep jsvc

	echo -e "set default admin user in tomcat-user.xml\n"
	cd /usr/local/tomcat/conf
	sed -i -- 's/.*<\/tomcat-users>.*/<user username="admin" password="admin" roles="manager-gui,manager-status"\/>\n&/' ./tomcat-users.xml

	echo -e "done."
}

set_environments_variables() {
	echo -e "setting environments variables\n"
	ENVIRONMENTS_FILE=/etc/profile.d/jdk_environments.sh
	touch $ENVIRONMENTS_FILE
	cat >> $ENVIRONMENTS_FILE << EOF
export JAVA_HOME=/usr/local/jdk
export JRE_HOME=\$JAVA_HOME/jre
export CATALINA_HOME=/usr/local/tomcat
export CLASSPATH=.:\$JAVA_HOME/lib:\$JRE_HOME/lib:\$CATALINA_HOME/lib
export PATH=\$JAVA_HOME/bin:\$JRE_HOME/bin:\$CATALINA_HOME/bin:\$PATH
EOF
	source /etc/profile
	which java
	java -version
	which javac
	javac -version
	echo -e "done."
}

post_installation() {
	echo -e "create tomcat user\n"
	groupadd -g 600 tomcat
	useradd -u 600 -g tomcat -s /sbin/nologin tomcat
	id tomcat

	echo -e "change owner and group for \$CATALINA_HOME\n"
	chown -R tomcat:tomcat /usr/local/apache-tomcat-8.0.33

	echo -e "create a systemd service\n"
	cat >> /lib/systemd/system/tomcat.service << "EOF"
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
PIDFile=/var/run/tomcat.pid
Environment=CATALINA_PID=/var/run/tomcat.pid
Environment=JAVA_HOME=/usr/local/jdk
Environment=CATALINA_HOME=/usr/local/tomcat
Environment=CATALINA_BASE=/usr/local/tomcat
Environment=CATALINA_OPTS=

ExecStart=/usr/local/tomcat/bin/jsvc \
            -Dcatalina.home=${CATALINA_HOME} \
            -Dcatalina.base=${CATALINA_BASE} \
            -cp ${CATALINA_HOME}/bin/commons-daemon.jar:${CATALINA_HOME}/bin/bootstrap.jar:${CATALINA_HOME}/bin/tomcat-juli.jar \
            -user tomcat \
            -java-home ${JAVA_HOME} \
            -pidfile /var/run/tomcat.pid \
            -errfile SYSLOG \
            -outfile SYSLOG \
            $CATALINA_OPTS \
            org.apache.catalina.startup.Bootstrap

ExecStop=/usr/local/tomcat/bin/jsvc \
            -pidfile /var/run/tomcat.pid \
            -stop \
            org.apache.catalina.startup.Bootstrap

[Install]
WantedBy=multi-user.target
EOF

	systemctl daemon-reload
	systemctl enable tomcat.service
	systemctl start tomcat.service
	systemctl status tomcat.service

}

main() {
	echo "main() was called"
	install_jdk
	install_tomcat
	set_environments_variables
	post_installation
}

echo -e "This script will install jdk 8.x and tomcat 8.x for you"
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
