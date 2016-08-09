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

	wget --no-check-certificate \
             --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" \
             http://download.oracle.com/otn-pub/java/jdk/8u101-b13/jdk-8u101-linux-arm32-vfp-hflt.tar.gz

	tar -zxvf ./jdk-8u101-linux-arm32-vfp-hflt.tar.gz
	chown -R root:root ./jdk1.8.0_101
	rm -rf /usr/local/jdk
	ln -s /usr/local/jdk1.8.0_101 /usr/local/jdk
	rm -rf ./jdk-8u101-linux-arm32-vfp-hflt.tar.gz

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
	wget http://apache.stu.edu.tw/tomcat/tomcat-8/v8.0.36/bin/apache-tomcat-8.0.36.tar.gz
	tar -zxvf ./apache-tomcat-8.0.36.tar.gz
	chown -R root:root ./apache-tomcat-8.0.36
	chmod -R a+r ./apache-tomcat-8.0.36/conf
	rm -rf /usr/local/tomcat
	ln -s /usr/local/apache-tomcat-8.0.36 /usr/local/tomcat
	rm -rf ./apache-tomcat-8.0.36.tar.gz
	echo -e "make symbolic links for jni_md.h and jawt_md.h\n"
	ln -s /usr/local/jdk1.8.0_101/include/linux/jni_md.h /usr/local/jdk1.8.0_101/include/jni_md.h
	ln -s /usr/local/jdk1.8.0_101/include/linux/jawt_md.h /usr/local/jdk1.8.0_101/include/jawt_md.h
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
	rm -rf /usr/local/maven3
	ln -s /usr/local/apache-maven-3.3.9 /usr/local/maven3
	rm -rf ./apache-maven-3.3.9-bin.tar.gz
}

install_gradle() {
	echo -e "ready to install gradle\n"
	cd /usr/local
	wget https://services.gradle.org/distributions/gradle-2.14.1-all.zip
	unzip ./gradle-2.14.1-all.zip
	chown -R root:root ./gradle-2.14.1
	rm -rf /usr/local/gradle
	ln -s /usr/local/gradle-2.14.1 /usr/local/gradle
	rm -rf ./gradle-2.14.1-all.zip
}

install_spring_boot_cli() {
	echo -e "ready to install spring boot cli\n"
	cd /usr/local
        wget http://repo.spring.io/release/org/springframework/boot/spring-boot-cli/1.3.6.RELEASE/spring-boot-cli-1.3.6.RELEASE-bin.tar.gz
        tar -zxvf ./spring-boot-cli-1.3.6.RELEASE-bin.tar.gz
	chown -R root:root ./spring-1.3.6.RELEASE
	rm -rf /usr/local/spring-boot-cli
	ln -s /usr/local/spring-1.3.6.RELEASE /usr/local/spring-boot-cli
	rm -rf ./spring-boot-cli-1.3.6.RELEASE-bin.tar.gz
}

install_cassandra_v2() {
        cd /usr/local
        echo -e "download cassandra 2.2x and extract it to /usr/local/\n"
        curl -L http://apache.stu.edu.tw/cassandra/2.2.7/apache-cassandra-2.2.7-bin.tar.gz | tar xz
        rm -rf ./cassandra
        ln -s apache-cassandra-2.2.7 cassandra
	echo -e "create cassandra user\n"
        groupadd -g 700 cassandra
        useradd -u 700 -g cassandra -s /sbin/nologin cassandra
        id cassandra
	echo -e "delete data directory if it has existed\n"
	rm -rf /usr/local/cassandra/data
	echo -e "editing config file for cassandra non-seed node in cluster\n"
	cp /usr/local/cassandra/conf/cassandra.yaml /usr/local/cassandra/conf/cassandra.yaml.default
	sed -i -- "s|cluster_name: 'Test Cluster'|cluster_name: 'AnnCluster'|g" /usr/local/cassandra/conf/cassandra.yaml
	sed -i -- "s|num_tokens: 256|num_tokens: 256|g" /usr/local/cassandra/conf/cassandra.yaml
	sed -i -- "s|seeds: \"127.0.0.1\"|seeds: \"10.1.1.91\"|g" /usr/local/cassandra/conf/cassandra.yaml
	sed -i -- "s|listen_address: localhost|listen_address: |g" /usr/local/cassandra/conf/cassandra.yaml
	sed -i -- "s|# listen_interface: eth0|listen_interface: eth0|g" /usr/local/cassandra/conf/cassandra.yaml
	sed -i -- "s|# listen_interface_prefer_ipv6: false|listen_interface_prefer_ipv6: false|g" /usr/local/cassandra/conf/cassandra.yaml
	sed -i -- "s|rpc_address: localhost|rpc_address: |g" /usr/local/cassandra/conf/cassandra.yaml
	sed -i -- "s|# rpc_interface: eth1|rpc_interface: eth0|g" /usr/local/cassandra/conf/cassandra.yaml
	sed -i -- "s|# rpc_interface_prefer_ipv6: false|rpc_interface_prefer_ipv6: false|g" /usr/local/cassandra/conf/cassandra.yaml
	sed -i -- "s|endpoint_snitch: SimpleSnitch|endpoint_snitch: GossipingPropertyFileSnitch|g" /usr/local/cassandra/conf/cassandra.yaml
	sed -i '$a auto_bootstrap: false' /usr/local/cassandra/conf/cassandra.yaml
	sed -i -- "s|dc=dc1|dc=datacenter1|g" /usr/local/cassandra/conf/cassandra-rackdc.properties
	sed -i -- "s|rack=rack1|rack=rack1|g" /usr/local/cassandra/conf/cassandra-rackdc.properties
        echo -e "change owner and group for \$CASSANDRA_HOME\n"
        chown -R cassandra:cassandra /usr/local/apache-cassandra-2.2.7

	# install latest python casssandra-driver
	apt-get -y install python-pip python-dev
        pip install cassandra-driver
}

install_cassandra_v3() {
	cd /usr/local
	echo -e "download cassandra 3.x and extract it to /usr/local/\n"
	curl -L http://apache.stu.edu.tw/cassandra/3.7/apache-cassandra-3.7-bin.tar.gz | tar xz
	rm -rf ./cassandra
	ln -s apache-cassandra-3.7 cassandra
	cd cassandra
	echo -e "create directories for custom settings\n"
	mkdir cassandra-data
	cd cassandra-data
	mkdir data saved_caches commitlog
	echo -e "edit config file\n"
	cd /usr/local/cassandra/conf
	cp ./cassandra.yaml ./cassandra.yaml.default
	sed -i -- 's|# data_file_directories:|data_file_directories:|g' ./cassandra.yaml
	sed -i -- 's|#     - /var/lib/cassandra/data|     - /usr/local/cassandra/cassandra-data/data|g' ./cassandra.yaml
	sed -i -- 's|# commitlog_directory: /var/lib/cassandra/commitlog|commitlog_directory: /usr/local/cassandra/cassandra-data/commitlog|g' ./cassandra.yaml
	sed -i -- 's|# saved_caches_directory: /var/lib/cassandra/saved_caches|saved_caches_directory: /usr/local/cassandra/cassandra-data/saved_caches|g' ./cassandra.yaml
	echo -e "create cassandra user\n"
        groupadd -g 700 cassandra
        useradd -u 700 -g cassandra -s /sbin/nologin cassandra
        id cassandra

        echo -e "change owner and group for \$CASSANDRA_HOME\n"
        chown -R cassandra:cassandra /usr/local/apache-cassandra-3.7
}

set_environments_variables() {
	echo -e "setting environments variables\n"
	ENVIRONMENTS_FILE=/etc/profile.d/jdk_environments.sh
	rm -rf $ENVIRONMENTS_FILE
	touch $ENVIRONMENTS_FILE
	cat >> $ENVIRONMENTS_FILE << EOF
export JAVA_HOME=/usr/local/jdk
export JRE_HOME=\$JAVA_HOME/jre
export CATALINA_HOME=/usr/local/tomcat
export M2_HOME=/usr/local/maven3
export GRADLE_HOME=/usr/local/gradle
export SPRING_HOME=/usr/local/spring-boot-cli
export CASSANDRA_HOME=/usr/local/cassandra
export CQLSH_NO_BUNDLED=true # https://issues.apache.org/jira/browse/CASSANDRA-11850
export CLASSPATH=.:\$JAVA_HOME/lib:\$JRE_HOME/lib:\$CATALINA_HOME/lib
export PATH=\$JAVA_HOME/bin:\$JRE_HOME/bin:\$CATALINA_HOME/bin:\$M2_HOME/bin:\$GRADLE_HOME/bin:\$SPRING_HOME/bin:\$CASSANDRA_HOME/bin:\$PATH
EOF
	source /etc/profile
	which java
	java -version
	which javac
	javac -version
	which mvn
	mvn -v
	which gradle
	gradle -v
	which spring
	spring --version
	which cassandra
	cassandra -v
	echo -e "done."
}

register_tomcat_as_systemd_service() {
	echo -e "create tomcat user\n"
	groupadd -g 600 tomcat
	useradd -u 600 -g tomcat -s /sbin/nologin tomcat
	id tomcat

	echo -e "change owner and group for \$CATALINA_HOME\n"
	chown -R tomcat:tomcat /usr/local/apache-tomcat-8.0.36

	echo -e "create a systemd service\n"
	rm -rf /lib/systemd/system/tomcat.service
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

register_cassandra_as_systemd_service() {
        echo -e "create a systemd unit file for cassandra\n"
        rm -rf /lib/systemd/system/cassandra.service
        cat >> /lib/systemd/system/cassandra.service << "EOF"
[Unit]
Description=Cassandra
After=network.target

[Service]
Type=forking
PIDFile=/usr/local/cassandra/cassandra.pid
User=cassandra
Group=cassandra
ExecStart=/usr/local/cassandra/bin/cassandra -p /usr/local/cassandra/cassandra.pid
StandardOutput=journal
StandardError=journal
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable cassandra.service
        systemctl start cassandra.service
        systemctl status cassandra.service
}

main() {
	echo "main() was called"
	install_jdk
	set_jdk_priority
	install_tomcat
	install_maven
	install_gradle
	install_spring_boot_cli
	install_cassandra_v2
	#install_cassandra_v3
	set_environments_variables
	register_tomcat_as_systemd_service
	register_cassandra_as_systemd_service
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
