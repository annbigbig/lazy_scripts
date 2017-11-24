#!/bin/bash
#
# this script will install jdk 8 and tomcat 8.5.x and several tools for JavaEE developers
# there are some parameters have to be confirmed before u run this script :
#######################################################################################################
TOMCAT_ADMIN_USERNAME="admin"                                                                         #
TOMCAT_ADMIN_PASSWORD="admin"                                                                         #
TOMCAT_JNDI_RESOURCE_NAME="jdbc/DB_SPRING"                                                            #
TOMCAT_JNDI_USERNAME="spring"                                                                         #
TOMCAT_JNDI_PASSWORD="spring"                                                                         #
TOMCAT_JNDI_URL="jdbc:mariadb://127.0.0.1:3306/db_spring"                                             #
TOMCAT_MEMCACHED_NODES="n1:172.17.205.141:11211,n2:172.17.205.142:11211"                              #
MINIMAL_HEAP_MEMORY_SIZE="1024m"                                                                      #
MAXIMUM_HEAP_MEMORY_SIZE="1536m"                                                                      #
#######################################################################################################

say_goodbye() {
        echo "goodbye everyone"
}

install_jdk() {
	echo -e "ready to install jdk \n"
	cd /usr/local/

	wget --no-check-certificate \
             --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" \
             http://download.oracle.com/otn-pub/java/jdk/8u152-b16/aa0333dd3019491ca4f6ddbe78cdb6d0/jdk-8u152-linux-x64.tar.gz

        # checksum could be found here
        # https://www.oracle.com/webfolder/s/digest/8u152checksum.html
        SHA256SUM_SHOULD_BE="218b3b340c3f6d05d940b817d0270dfe0cfd657a636bad074dcabe0c111961bf"
        SHA256SUM_COMPUTED="$(/usr/bin/sha256sum ./jdk-8u152-linux-x64.tar.gz | cut -d ' ' -f 1)"
        [ "$SHA256SUM_SHOULD_BE" == "$SHA256SUM_COMPUTED" ] && echo "jdk sha256sum matched." || exit 2

	tar -zxvf ./jdk-8u152-linux-x64.tar.gz
	chown -R root:root ./jdk1.8.0_152
	rm -rf /usr/local/jdk
	ln -s /usr/local/jdk1.8.0_152 /usr/local/jdk
	rm -rf ./jdk-8u152-linux-x64.tar.gz

	echo -e "jdk installation completed."
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
        echo -e "jdk priority changed. \n"
}

install_tomcat() {
	echo -e "ready to install tomcat \n"
	apt-get install -y build-essential
	cd /usr/local
	wget http://ftp.tc.edu.tw/pub/Apache/tomcat/tomcat-8/v8.5.23/bin/apache-tomcat-8.5.23.tar.gz
        wget https://www.apache.org/dist/tomcat/tomcat-8/v8.5.23/bin/apache-tomcat-8.5.23.tar.gz.md5
        MD5SUM_SHOULD_BE="$(/bin/cat ./apache-tomcat-8.5.23.tar.gz.md5 | cut -d ' ' -f 1)"
        MD5SUM_COMPUTED="$(/usr/bin/md5sum ./apache-tomcat-8.5.23.tar.gz | cut -d ' ' -f 1)"
        [ "$MD5SUM_SHOULD_BE" == "$MD5SUM_COMPUTED" ] && echo "tomcat md5sum matched." || exit 2

	tar -zxvf ./apache-tomcat-8.5.23.tar.gz
	chown -R root:root ./apache-tomcat-8.5.23
	chmod -R a+r ./apache-tomcat-8.5.23
        find /usr/local/apache-tomcat-8.5.23 -type d -exec chmod a+rx {} \;
	rm -rf /usr/local/tomcat
	ln -s /usr/local/apache-tomcat-8.5.23 /usr/local/tomcat
	rm -rf ./apache-tomcat-8.5.23.tar.gz*

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
	cd /usr/local/tomcat/conf/
        cp tomcat-users.xml tomcat-users.xml.default
        rm -rf tomcat-users.xml
        cat > /usr/local/apache-tomcat-8.5.23/conf/tomcat-users.xml << "EOF"
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">
<role rolename="admin-gui"/>
<role rolename="manager-script"/>
<role rolename="manager-jmx"/>
<role rolename="manager-gui"/>
<role rolename="manager-status"/>
<user username="TOMCAT_ADMIN_USERNAME" password="TOMCAT_ADMIN_PASSWORD" roles="admin-gui,manager-script,manager-jmx,manager-gui,manager-status"/>
</tomcat-users>
EOF
        sed -i -- "s|TOMCAT_ADMIN_USERNAME|$TOMCAT_ADMIN_USERNAME|g" /usr/local/apache-tomcat-8.5.23/conf/tomcat-users.xml
        sed -i -- "s|TOMCAT_ADMIN_PASSWORD|$TOMCAT_ADMIN_PASSWORD|g" /usr/local/apache-tomcat-8.5.23/conf/tomcat-users.xml

        echo -e "configure JNDI DataSource"
        cd /usr/local/tomcat/conf/
        cp server.xml server.xml.default
        rm -rf server.xml
        cat > /usr/local/apache-tomcat-8.5.23/conf/server.xml << "EOF"
<?xml version="1.0" encoding="UTF-8"?>
<Server port="8005" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.startup.VersionLoggerListener" />
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />
  <GlobalNamingResources>
    <Resource name="UserDatabase" auth="Container"
              type="org.apache.catalina.UserDatabase"
              description="User database that can be updated and saved"
              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
              pathname="conf/tomcat-users.xml" />

    <Resource name="TOMCAT_JNDI_RESOURCE_NAME"
          auth="Container"
          type="javax.sql.DataSource"
          factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
          testWhileIdle="true"
          testOnBorrow="true"
          testOnReturn="false"
          validationQuery="SELECT 1"
          validationInterval="30000"
          timeBetweenEvictionRunsMillis="30000"
          maxActive="100"
          minIdle="10"
          maxWait="10000"
          initialSize="10"
          removeAbandonedTimeout="60"
          removeAbandoned="true"
          logAbandoned="true"
          minEvictableIdleTimeMillis="30000"
          jmxEnabled="true"
          jdbcInterceptors="org.apache.tomcat.jdbc.pool.interceptor.ConnectionState;
            org.apache.tomcat.jdbc.pool.interceptor.StatementFinalizer"
          username="TOMCAT_JNDI_USERNAME"
          password="TOMCAT_JNDI_PASSWORD"
          driverClassName="org.mariadb.jdbc.Driver"
          url="TOMCAT_JNDI_URL"/>

  </GlobalNamingResources>

  <Service name="Catalina">
    <Connector port="8080" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443" />
    <Connector port="8009" protocol="AJP/1.3" redirectPort="8443" address="0.0.0.0" useIPVHosts="true" />
    <Engine name="Catalina" defaultHost="localhost">
      <Realm className="org.apache.catalina.realm.LockOutRealm">
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
               resourceName="UserDatabase"/>
      </Realm>

      <Host name="localhost"  appBase="webapps"
            unpackWARs="true" autoDeploy="true">
        <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
               prefix="localhost_access_log" suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b" />
      </Host>
    </Engine>
  </Service>
</Server>
EOF
        sed -i -- "s|TOMCAT_JNDI_RESOURCE_NAME|$TOMCAT_JNDI_RESOURCE_NAME|g" /usr/local/apache-tomcat-8.5.23/conf/server.xml
        sed -i -- "s|TOMCAT_JNDI_USERNAME|$TOMCAT_JNDI_USERNAME|g" /usr/local/apache-tomcat-8.5.23/conf/server.xml
        sed -i -- "s|TOMCAT_JNDI_PASSWORD|$TOMCAT_JNDI_PASSWORD|g" /usr/local/apache-tomcat-8.5.23/conf/server.xml
        sed -i -- "s|TOMCAT_JNDI_URL|$TOMCAT_JNDI_URL|g" /usr/local/apache-tomcat-8.5.23/conf/server.xml

        cd /usr/local/tomcat/conf/
        cp context.xml context.xml.default
        rm context.xml
        cat > /usr/local/apache-tomcat-8.5.23/conf/context.xml << "EOF"
<?xml version="1.0" encoding="UTF-8"?>
<Context antiJARLocking="true" antiResourceLocking="true">

    <ResourceLink name="TOMCAT_JNDI_RESOURCE_NAME" global="TOMCAT_JNDI_RESOURCE_NAME" type="javax.sql.DataSource"/>
    <Manager className="de.javakaffee.web.msm.MemcachedBackupSessionManager"
       memcachedNodes="TOMCAT_MEMCACHED_NODES"
        sticky="false"
        sessionBackupAsync="false"
        lockingMode="none"
       requestUriIgnorePattern=".*\.(ico|png|gif|jpg|css|js)$"
       transcoderFactoryClass="de.javakaffee.web.msm.JavaSerializationTranscoderFactory"/>
    <WatchedResource>WEB-INF/web.xml</WatchedResource>
    <WatchedResource>${catalina.base}/conf/web.xml</WatchedResource>

</Context>
EOF
        sed -i -- "s|TOMCAT_JNDI_RESOURCE_NAME|$TOMCAT_JNDI_RESOURCE_NAME|g" /usr/local/apache-tomcat-8.5.23/conf/context.xml
        sed -i -- "s|TOMCAT_MEMCACHED_NODES|$TOMCAT_MEMCACHED_NODES|g" /usr/local/apache-tomcat-8.5.23/conf/context.xml


        # unlock host-manager and manager that only be accessed by 127.0.0.1
        rm -rf /usr/local/apache-tomcat-8.5.23/webapps/manager/META-INF/context.xml
        rm -rf /usr/local/apache-tomcat-8.5.23/webapps/host-manager/MATA-INF/context.xml

        cat > /usr/local/apache-tomcat-8.5.23/webapps/manager/META-INF/context.xml << "EOF"
<?xml version="1.0" encoding="UTF-8"?>
<!--
  Licensed to the Apache Software Foundation (ASF) under one or more
  contributor license agreements.  See the NOTICE file distributed with
  this work for additional information regarding copyright ownership.
  The ASF licenses this file to You under the Apache License, Version 2.0
  (the "License"); you may not use this file except in compliance with
  the License.  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
-->
<Context antiResourceLocking="false" privileged="true" >
  <!--<Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1" /> -->
  <Manager sessionAttributeValueClassNameFilter="java\.lang\.(?:Boolean|Integer|Long|Number|String)|org\.apache\.catalina\.filters\.CsrfPreventionFilter\$LruCache(?:\$1)?|java\.util\.(?:Linked)?HashMap"/>
</Context>
EOF
        cp /usr/local/apache-tomcat-8.5.23/webapps/manager/META-INF/context.xml /usr/local/apache-tomcat-8.5.23/webapps/host-manager/META-INF/context.xml
        chmod 644 /usr/local/apache-tomcat-8.5.23/webapps/manager/META-INF/context.xml
        chmod 644 /usr/local/apache-tomcat-8.5.23/webapps/host-manager/META-INF/context.xml

        # download jar file 'slf4j-api-1.7.21.jar' and place it in $CATALINA_HOME/lib
        wget -O /usr/local/apache-tomcat-8.5.23/lib/slf4j-api-1.7.21.jar http://central.maven.org/maven2/org/slf4j/slf4j-api/1.7.21/slf4j-api-1.7.21.jar 

        # download jar files for JNDI resource settings
        cd /usr/local/apache-tomcat-8.5.23/lib/
        wget https://downloads.mariadb.com/Connectors/java/connector-java-2.1.2/mariadb-java-client-2.1.2.jar
        wget https://downloads.mariadb.com/Connectors/java/connector-java-2.1.2/md5sums.txt
        MD5SUM_SHOULD_BE="$(/bin/cat ./md5sums.txt | grep mariadb-java-client-2.1.2.jar | cut -d ' ' -f 1)"
        MD5SUM_COMPUTED="$(/usr/bin/md5sum ./mariadb-java-client-2.1.2.jar | cut -d ' ' -f 1)"
        [ "$MD5SUM_SHOULD_BE" == "$MD5SUM_COMPUTED" ] && echo "mariadb jdbc driver md5sum matched." || exit 2

        # download jar files for memcached-session-manager settings
        wget http://central.maven.org/maven2/org/ow2/asm/asm/5.2/asm-5.2.jar
        wget http://central.maven.org/maven2/com/googlecode/kryo/1.04/kryo-1.04.jar
        wget http://central.maven.org/maven2/de/javakaffee/kryo-serializers/0.42/kryo-serializers-0.42.jar
        wget http://central.maven.org/maven2/de/javakaffee/msm/memcached-session-manager-tc8/2.1.1/memcached-session-manager-tc8-2.1.1.jar
        wget http://central.maven.org/maven2/de/javakaffee/msm/memcached-session-manager/2.1.1/memcached-session-manager-2.1.1.jar
        wget http://central.maven.org/maven2/com/esotericsoftware/minlog/1.3/minlog-1.3.jar
        wget http://central.maven.org/maven2/de/javakaffee/msm/msm-kryo-serializer/2.1.1/msm-kryo-serializer-2.1.1.jar
        wget http://central.maven.org/maven2/com/esotericsoftware/reflectasm/1.11.3/reflectasm-1.11.3.jar
        wget http://central.maven.org/maven2/net/spy/spymemcached/2.12.3/spymemcached-2.12.3.jar

	echo -e "tomcat installation completed."
}

create_test_jsp() {
        IP_ADDRESS="$(/sbin/ip addr show eth0 | grep dynamic | grep -v inet6 | tr -s ' ' | cut -d ' ' -f 3 | cut -d '/' -f 1)"
        LAST_NUMBER_OF_IP_ADDRESS="$(/sbin/ip addr show eth0 | grep dynamic | grep -v inet6 | tr -s ' ' | cut -d ' ' -f 3 | cut -d '/' -f 1 | cut -d '.' -f 4)"
        COLOR="black"
        if [ $(($LAST_NUMBER_OF_IP_ADDRESS % 3)) -eq 0 ] ; then
           COLOR="red"
        elif [ $(($LAST_NUMBER_OF_IP_ADDRESS % 3)) -eq 1 ] ; then
           COLOR="blue"
        else
           COLOR="green"
        fi
cat > /usr/local/tomcat/webapps/ROOT/test.jsp << "EOF"
<html>
  <head><title>Tomcat at HOSTNAME (IP_ADDRESS)</title></head>
  <body>
    <h1><font color="COLOR">Tomcat at HOSTNAME (IP_ADDRESS)</font></h1>
    <table align="centre" border="1">
      <tr>
        <td>Session ID</td>
        <td><%= session.getId() %></td>
      </tr>
      <tr>
        <td>Created on</td>
        <td><%= session.getCreationTime() %></td>
     </tr>
    </table>
  </body>
</html>
EOF
       sed -i -- "s|HOSTNAME|$HOSTNAME|g" /usr/local/tomcat/webapps/ROOT/test.jsp
       sed -i -- "s|COLOR|$COLOR|g" /usr/local/tomcat/webapps/ROOT/test.jsp
       sed -i -- "s|IP_ADDRESS|$IP_ADDRESS|g" /usr/local/tomcat/webapps/ROOT/test.jsp
}

install_maven() {
	echo -e "ready to install maven\n"
	cd /usr/local
	wget http://ftp.mirror.tw/pub/apache/maven/maven-3/3.5.2/binaries/apache-maven-3.5.2-bin.tar.gz
        wget https://www.apache.org/dist/maven/maven-3/3.5.2/binaries/apache-maven-3.5.2-bin.tar.gz.md5
        MD5SUM_SHOULD_BE="$(/bin/cat ./apache-maven-3.5.2-bin.tar.gz.md5 | cut -d ' ' -f 1)"
        MD5SUM_COMPUTED="$(/usr/bin/md5sum ./apache-maven-3.5.2-bin.tar.gz | cut -d ' ' -f 1)"
        [ "$MD5SUM_SHOULD_BE" == "$MD5SUM_COMPUTED" ] && echo "maven md5sum matched." || exit 2

	tar -zxvf ./apache-maven-3.5.2-bin.tar.gz
	chown -R root:root ./apache-maven-3.5.2
	rm -rf /usr/local/maven3
	ln -s /usr/local/apache-maven-3.5.2 /usr/local/maven3
	rm -rf ./apache-maven-3.5.2-bin.tar.gz*
}

install_gradle() {
	echo -e "ready to install gradle\n"
	cd /usr/local
        wget https://services.gradle.org/distributions/gradle-4.3.1-all.zip
        wget https://services.gradle.org/distributions/gradle-4.3.1-all.zip.sha256
        SHA256SUM_SHOULD_BE="$(/bin/cat ./gradle-4.3.1-all.zip.sha256 | cut -d ' ' -f 1)"
        SHA256SUM_COMPUTED="$(/usr/bin/sha256sum ./gradle-4.3.1-all.zip | cut -d ' ' -f 1)"
        [ "$SHA256SUM_SHOULD_BE" == "$SHA256SUM_COMPUTED" ] && echo "gradle sha256sum matched." || exit 2
	unzip ./gradle-4.3.1-all.zip
	chown -R root:root ./gradle-4.3.1
	rm -rf /usr/local/gradle
	ln -s /usr/local/gradle-4.3.1 /usr/local/gradle
	rm -rf ./gradle-4.3.1-all.zip
}

install_spring_boot_cli() {
	echo -e "ready to install spring boot cli\n"
	cd /usr/local
        wget http://repo.spring.io/release/org/springframework/boot/spring-boot-cli/1.5.8.RELEASE/spring-boot-cli-1.5.8.RELEASE-bin.tar.gz
        wget http://repo.spring.io/release/org/springframework/boot/spring-boot-cli/1.5.8.RELEASE/spring-boot-cli-1.5.8.RELEASE-bin.tar.gz.md5
        MD5SUM_SHOULD_BE="$(/bin/cat ./spring-boot-cli-1.5.8.RELEASE-bin.tar.gz.md5 | cut -d ' ' -f 1)"
        MD5SUM_COMPUTED="$(/usr/bin/md5sum ./spring-boot-cli-1.5.8.RELEASE-bin.tar.gz | cut -d ' ' -f 1)"
        [ "$MD5SUM_SHOULD_BE" == "$MD5SUM_COMPUTED" ] && echo "spring-boot-cli md5sum matched." || exit 2

        tar -zxvf ./spring-boot-cli-1.5.8.RELEASE-bin.tar.gz
	chown -R root:root ./spring-1.5.8.RELEASE
	rm -rf /usr/local/spring-boot-cli
	ln -s /usr/local/spring-1.5.8.RELEASE /usr/local/spring-boot-cli
	rm -rf ./spring-boot-cli-1.5.8.RELEASE-bin.tar.gz*
}

install_jmeter(){
	cd /usr/local/
	wget http://apache.stu.edu.tw//jmeter/binaries/apache-jmeter-3.3.tgz
	wget https://www.apache.org/dist/jmeter/binaries/apache-jmeter-3.3.tgz.sha512
	SHA512SUM_COMPUTED="$(/usr/bin/sha512sum ./apache-jmeter-3.3.tgz | tr -s ' ' | cut -d ' ' -f 1)"
	SHA512SUM_SHOULD_BE="$(/bin/cat ./apache-jmeter-3.3.tgz.sha512 | tr -s ' ' | cut -d ' ' -f 1)"
	[ $SHA512SUM_COMPUTED == $SHA512SUM_SHOULD_BE ] && (echo "yes sha512sum matched." && echo "yabi") || (echo "oops...not matched" && exit 2)
	tar -xxvf ./apache-jmeter-3.3.tgz
	chown -R root:root /usr/local/apache-jmeter-3.3
	ln -s /usr/local/apache-jmeter-3.3 /usr/local/jmeter
	rm -rf ./apache-jmeter-3.3.tgz*
}

install_eclipse_ee() {
        # hint: There is no need to install Eclipse IDE tool on a Server machine.
        #       you could skip this function safely.
	echo -e "ready to install Eclipse EE\n"
	cd /usr/local
	rm -rf ./eclipse
        wget http://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/oxygen/1a/eclipse-jee-oxygen-1a-linux-gtk-x86_64.tar.gz\&r=1 -O eclipse-jee-oxygen-1a-linux-gtk-x86_64.tar.gz
        wget http://download.eclipse.org/technology/epp/downloads/release/oxygen/1a/eclipse-jee-oxygen-1a-linux-gtk-x86_64.tar.gz.md5
	MD5SUM_SHOULD_BE="$(/bin/cat ./eclipse-jee-oxygen-1a-linux-gtk-x86_64.tar.gz.md5 | cut -d ' ' -f 1)"
        MD5SUM_COMPUTED="$(/usr/bin/md5sum eclipse-jee-oxygen-1a-linux-gtk-x86_64.tar.gz | cut -d ' ' -f 1)"
        [ "$MD5SUM_SHOULD_BE" == "$MD5SUM_COMPUTED" ] && echo "Eclipse EE md5sum matched." || exit 2
	
	tar -zxvf ./eclipse-jee-oxygen-1a-linux-gtk-x86_64.tar.gz
	chown -R root:root ./eclipse

        # find the user whose UID is 1000
        YOUR_USERNAME="$(/bin/cat /etc/passwd | grep 1000 | head -1 | cut -d ':' -f 1)"

	rm -rf /home/$YOUR_USERNAME/桌面/eclipse-EE-oxygen-1a
	ln -s /usr/local/eclipse/eclipse /home/$YOUR_USERNAME/桌面/eclipse-EE-oxygen-1a
	rm -rf ./eclipse-jee-oxygen-1a-linux-gtk-x86_64.tar.gz
        echo -e "Eclipse EE installation completed."
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
export JMETER_HOME=/usr/local/jmeter
export JVM_ARGS="-XmsMINIMAL_HEAP_MEMORY_SIZE -XmxMAXIMUM_HEAP_MEMORY_SIZE"
export CLASSPATH=.:\$JAVA_HOME/lib:\$JRE_HOME/lib:\$CATALINA_HOME/lib
export PATH=\$JAVA_HOME/bin:\$JRE_HOME/bin:\$CATALINA_HOME/bin:\$M2_HOME/bin:\$GRADLE_HOME/bin:\$SPRING_HOME/bin:\$JMETER_HOME/bin:\$PATH
EOF
        sed -i -- "s|MINIMAL_HEAP_MEMORY_SIZE|$MINIMAL_HEAP_MEMORY_SIZE|g" $ENVIRONMENTS_FILE
        sed -i -- "s|MAXIMUM_HEAP_MEMORY_SIZE|$MAXIMUM_HEAP_MEMORY_SIZE|g" $ENVIRONMENTS_FILE
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
        which jmeter
        jmeter -v
	echo -e "environments variables settings completed."
}

register_tomcat_as_systemd_service() {
	echo -e "create tomcat user\n"
	groupadd -g 600 tomcat
	useradd -u 600 -g tomcat -s /sbin/nologin tomcat
	id tomcat

	echo -e "change owner and group for \$CATALINA_HOME\n"
	chown -R tomcat:tomcat /usr/local/apache-tomcat-8.5.23

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
Environment=CATALINA_OPTS="-XmsMINIMAL_HEAP_MEMORY_SIZE -XmxMAXIMUM_HEAP_MEMORY_SIZE"

ExecStart=/usr/local/tomcat/bin/jsvc \
            -cp ${CATALINA_HOME}/bin/commons-daemon.jar:${CATALINA_HOME}/bin/bootstrap.jar:${CATALINA_HOME}/bin/tomcat-juli.jar \
            -errfile SYSLOG \
            -outfile SYSLOG \
            -Dcatalina.home=${CATALINA_HOME} \
            -Dcatalina.base=${CATALINA_BASE} \
            -Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager \
            -Djava.util.logging.config.file=$CATALINA_BASE/conf/logging.properties \
            -user tomcat \
            -java-home ${JAVA_HOME} \
            -pidfile /var/run/tomcat.pid \
            $CATALINA_OPTS \
            org.apache.catalina.startup.Bootstrap

ExecStop=/usr/local/tomcat/bin/jsvc \
            -pidfile /var/run/tomcat.pid \
            -stop \
            org.apache.catalina.startup.Bootstrap

[Install]
WantedBy=multi-user.target
EOF
        sed -i -- "s|MINIMAL_HEAP_MEMORY_SIZE|$MINIMAL_HEAP_MEMORY_SIZE|g" /lib/systemd/system/tomcat.service
        sed -i -- "s|MAXIMUM_HEAP_MEMORY_SIZE|$MAXIMUM_HEAP_MEMORY_SIZE|g" /lib/systemd/system/tomcat.service

	systemctl daemon-reload
	systemctl enable tomcat.service
	systemctl start tomcat.service
	systemctl status tomcat.service

}

main() {
	install_jdk
	set_jdk_priority
	install_tomcat
        create_test_jsp
	install_maven
	install_gradle
	install_spring_boot_cli
	install_jmeter
	install_eclipse_ee
	set_environments_variables
	register_tomcat_as_systemd_service
}

echo -e "This script will install jdk 8 and tomcat 8.5.x for you"
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
