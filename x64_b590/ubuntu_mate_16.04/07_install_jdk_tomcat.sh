#!/bin/bash
# set your username here
YOUR_USERNAME="labasky"
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
             http://download.oracle.com/otn-pub/java/jdk/8u91-b14/jdk-8u91-linux-x64.tar.gz

	tar -zxvf ./jdk-8u91-linux-x64.tar.gz
	chown -R root:root ./jdk1.8.0_91
	ln -s /usr/local/jdk1.8.0_91 /usr/local/jdk
	rm -rf ./jdk-8u91-linux-x64.tar.gz

	echo -e "done."
}

set_jdk_priority() {
        # http://stackoverflow.com/questions/17609083/update-alternatives-warning-etc-alternatives-java-is-dangling
        echo -e "set jdk priority \n"
        update-alternatives --install "/usr/bin/java" "java" "/usr/local/jdk/bin/java" 1
        update-alternatives --install "/usr/bin/javac" "javac" "/usr/local/jdk/bin/javac" 1
        update-alternatives --set java /usr/local/jdk/bin/java
        update-alternatives --set javac /usr/local/jdk/bin/javac
        update-alternatives --list java
        update-alternatives --list javac
}

install_tomcat() {
	echo -e "ready to install tomcat \n"
	apt-get install -y build-essential
	cd /usr/local
	wget http://apache.stu.edu.tw/tomcat/tomcat-8/v8.0.35/bin/apache-tomcat-8.0.35.tar.gz
	tar -zxvf ./apache-tomcat-8.0.35.tar.gz
	chown -R root:root ./apache-tomcat-8.0.35
	chmod -R a+r ./apache-tomcat-8.0.35/conf
	ln -s /usr/local/apache-tomcat-8.0.35 /usr/local/tomcat
	rm -rf ./apache-tomcat-8.0.35.tar.gz

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

install_maven() {
	echo -e "ready to install maven\n"
	cd /usr/local
	wget http://ftp.tc.edu.tw/pub/Apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz
	tar -zxvf ./apache-maven-3.3.9-bin.tar.gz
	chown -R root:root ./apache-maven-3.3.9
	ln -s /usr/local/apache-maven-3.3.9 /usr/local/maven3
	rm -rf ./apache-maven-3.3.9-bin.tar.gz
}

install_spring_boot_cli() {
	echo -e "ready to install spring boot cli\n"
	cd /usr/local
        wget http://repo.spring.io/release/org/springframework/boot/spring-boot-cli/1.3.5.RELEASE/spring-boot-cli-1.3.5.RELEASE-bin.tar.gz
        tar -zxvf ./spring-boot-cli-1.3.5.RELEASE-bin.tar.gz
	chown -R root:root ./spring-1.3.5.RELEASE
	ln -s /usr/local/spring-1.3.5.RELEASE /usr/local/spring-boot-cli
	rm -rf ./spring-boot-cli-1.3.5.RELEASE-bin.tar.gz
}

install_eclipse_ee() {
	echo -e "ready to install Eclipse EE\n"
	cd /usr/local
	wget https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/neon/M6/eclipse-jee-neon-M6-linux-gtk-x86_64.tar.gz\&r=1 -O eclipse-jee-neon-M6-linux-gtk-x86_64.tar.gz
	tar -zxvf ./eclipse-jee-neon-M6-linux-gtk-x86_64.tar.gz
	chown -R root:root ./eclipse
	ln -s /usr/local/eclipse/eclipse /home/$YOUR_USERNAME/桌面/eclipse-EE-neon
	rm -rf ./eclipse-jee-neon-M6-linux-gtk-x86_64.tar.gz
}

set_environments_variables() {
	echo -e "setting environments variables\n"
	ENVIRONMENTS_FILE=/etc/profile.d/jdk_environments.sh
	touch $ENVIRONMENTS_FILE
	cat >> $ENVIRONMENTS_FILE << EOF
export JAVA_HOME=/usr/local/jdk
export JRE_HOME=\$JAVA_HOME/jre
export CATALINA_HOME=/usr/local/tomcat
export M2_HOME=/usr/local/maven3
export SPRING_HOME=/usr/local/spring-boot-cli
export CLASSPATH=.:\$JAVA_HOME/lib:\$JRE_HOME/lib:\$CATALINA_HOME/lib
export PATH=\$JAVA_HOME/bin:\$JRE_HOME/bin:\$CATALINA_HOME/bin:\$M2_HOME/bin:\$SPRING_HOME/bin:\$PATH
EOF
	source /etc/profile
	which java
	java -version
	which javac
	javac -version
	which mvn
	mvn -v
	which spring
	spring --version
	echo -e "done."
}

post_installation() {
	echo -e "create tomcat user\n"
	groupadd -g 600 tomcat
	useradd -u 600 -g tomcat -s /sbin/nologin tomcat
	id tomcat

	echo -e "change owner and group for \$CATALINA_HOME\n"
	chown -R tomcat:tomcat /usr/local/apache-tomcat-8.0.35

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
	set_jdk_priority
	install_tomcat
	install_maven
	install_spring_boot_cli
	install_eclipse_ee
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
