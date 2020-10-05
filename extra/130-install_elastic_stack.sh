#!/bin/bash
##################################################################################################################################
# this script will install Elastic Stack 7.x on this computer (Ubuntu 20.04)
# there are some parameters have to be confirmed before u run this script :
##################################################################################################################################
#
MY_NETWORK_INTERFACE="eth0"
ELK_INSTALL_PATH="/usr/local/app"
ELK_USER_NAME="elk"
ELK_USER_PASSWORD="elk"
#
##################################################################################################################################
#
OPENJDK_11_DOWNLOAD_LINK="https://download.java.net/java/GA/jdk11/9/GPL/openjdk-11.0.2_linux-x64_bin.tar.gz"
OPENJDK_11_SHA256SUM="99be79935354f5c0df1ad293620ea36d13f48ec3ea870c838f20c504c9668b57"
OPENJDK_11_MINIMAL_HEAP_MEMORY_SIZE="4g"
OPENJDK_11_MAXIMUM_HEAP_MEMORY_SIZE="4g"
#
##################################################################################################################################
#
TAR_GZ_PATH_ELASTICSEARCH="https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.9.1-linux-x86_64.tar.gz"
TAR_GZ_PATH_KIBANA="https://artifacts.elastic.co/downloads/kibana/kibana-7.9.1-linux-x86_64.tar.gz"
TAR_GZ_PATH_LOGSTASH="https://artifacts.elastic.co/downloads/logstash/logstash-7.9.1.tar.gz"
TAR_GZ_PATH_FILEBEAT="https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.9.1-linux-x86_64.tar.gz"
#
##################################################################################################################################
#
NODE_JS_DOWNLOAD_LINK="https://nodejs.org/dist/v14.11.0/node-v14.11.0-linux-x64.tar.xz"
NODE_JS_SHA256SUM="c0dfb8e45aefefc65410dbe3e9a05e346b952b2a19a965f5bea3e77b74fc73d8"
PHANTOM_JS_DOWNLOAD_LINK="https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2"
PHANTOM_JS_SHA256SUM="86dd9a4bf4aee45f1a84c9f61cf1947c1d6dce9b9e8d2a907105da7852460d2f"
#
##################################################################################################################################
#
ELASTIC_CLUSTER_NAME="logger"
ELASTIC_HTTP_PORT="9200"
ELASTIC_NODE_NAME="node-1"
ELASTIC_MINIMAL_HEAP_MEMORY_SIZE="512m"
ELASTIC_MAXIMUM_HEAP_MEMORY_SIZE="512m"
read -r -d '' ELASTIC_CLUSTER_HOSTS_IP_LIST << EOV
vhost201 172.25.169.201
vhost202 172.25.169.202
EOV
#
##################################################################################################################################
#
KIBANA_ADMIN_USER="kibanaadmin"
KIBANA_ADMIN_PASSWD="password"
KIBANA_FQDN="vhost201.dq5rocks.com"
KIBANA_HTTP_HOST="127.0.0.1"
KIBANA_HTTP_PORT="5601"
read -r -d '' KIBANA_INPUT_HOSTS_PORT_LIST << EOV
172.25.169.201 9200
172.25.169.202 9200
EOV
#
##################################################################################################################################
#
LOGSTASH_INPUT_PORT="5044"
LOGSTASH_MINIMAL_HEAP_MEMORY_SIZE="512m"
LOGSTASH_MAXIMUM_HEAP_MEMORY_SIZE="512m"
read -r -d '' LOGSTASH_OUTPUT_HOSTS_PORT_LIST << EOV
172.25.169.201 9200
EOV
#
##################################################################################################################################
#
read -r -d '' FILEBEAT_OUTPUT_LOGSTASH_HOSTS_PORT_LIST << EOV
172.25.169.201 5044
EOV
#
##################################################################################################################################
#
# most of parameters below are auto calculated , no need to change this block except XXXX_BASE_PATH
#
##################################################################################################################################
#
IP_ADDRESS="$(/sbin/ip addr show $MY_NETWORK_INTERFACE | grep inet | grep -v inet6 | tr -s ' ' | cut -d ' ' -f 3 | cut -d '/' -f 1)"
#
##################################################################################################################################
#
FILENAME_OPENJDK_11="${OPENJDK_11_DOWNLOAD_LINK##*/}"
FILENAME_ELASTICSEARCH="${TAR_GZ_PATH_ELASTICSEARCH##*/}"
FILENAME_KIBANA="${TAR_GZ_PATH_KIBANA##*/}"
FILENAME_LOGSTASH="${TAR_GZ_PATH_LOGSTASH##*/}"
FILENAME_FILEBEAT="${TAR_GZ_PATH_FILEBEAT##*/}"
FILENAME_NODE_JS="${NODE_JS_DOWNLOAD_LINK##*/}"
FILENAME_PHANTOM_JS="${PHANTOM_JS_DOWNLOAD_LINK##*/}"
#
##################################################################################################################################
#
OPENJDK_11_BASE_PATH="$ELK_INSTALL_PATH/jdk-11.0.2"
OPENJDK_11_BIN_PATH="$OPENJDK_11_BASE_PATH/bin"
OPENJDK_11_SYMBLIC_LINK_PATH="$ELK_INSTALL_PATH/jdk"
#
##################################################################################################################################
#
ELASTIC_BASE_PATH="$ELK_INSTALL_PATH/elasticsearch-7.9.1"
ELASTIC_CONFIG_PATH="$ELASTIC_BASE_PATH/config"
ELASTIC_BIN_PATH="$ELASTIC_BASE_PATH/bin"
ELASTIC_DATA_PATH="$ELASTIC_BASE_PATH/data"
ELASTIC_LOGS_PATH="$ELASTIC_BASE_PATH/logs"
#
##################################################################################################################################
#
ELASTIC_HEAD_BASE_PATH="$ELK_INSTALL_PATH/elasticsearch-head"
#
#
# this block will output ELASTIC_IP_LIST like this "172.25.169.201","172.25.169.202"
  ELASTIC_IP_LIST=""
        while read -r LINE; do
           SHORT_HOSTNAME="$(/bin/echo $LINE | cut -d ' ' -f 1)"
           IPV4_ADDRESS="$(/bin/echo $LINE | cut -d ' ' -f 2)"
            if [ ! -z "$ELASTIC_IP_LIST" ]; then
                 # not first line
                 ELASTIC_IP_LIST="$ELASTIC_IP_LIST,\"$IPV4_ADDRESS\""
            else
                 # first line
                 ELASTIC_IP_LIST="\"$IPV4_ADDRESS\""
            fi
        done <<< "$ELASTIC_CLUSTER_HOSTS_IP_LIST"
   echo "ELASTIC_IP_LIST = $ELASTIC_IP_LIST"
#
##################################################################################################################################
#
LOGSTASH_BASE_PATH="$ELK_INSTALL_PATH/logstash-7.9.1"
LOGSTASH_CONFIG_PATH="$LOGSTASH_BASE_PATH/config"
LOGSTASH_BIN_PATH="$LOGSTASH_BASE_PATH/bin"
LOGSTASH_DATA_PATH="$LOGSTASH_BASE_PATH/data"
LOGSTASH_TOOLS_PATH="$LOGSTASH_BASE_PATH/tools"
#
#
# this block will output LOGSTASH_OUTPUT_LIST 
#       like this "172.25.169.201:9200","172.25.169.202:9200" --- when line counts greater then 1
#         or this "172.25.169.201" --- when line count equal 1
  LOGSTASH_OUTPUT_LIST=""
  LINE_COUNT=0
        while read -r LINE; do
           IPV4_ADDRESS="$(/bin/echo $LINE | cut -d ' ' -f 1)"
           PORT_NUMBER="$(/bin/echo $LINE | cut -d ' ' -f 2)"
            if [ ! -z "$LOGSTASH_OUTPUT_LIST" ]; then
                 # not first line
                 LOGSTASH_OUTPUT_LIST="$LOGSTASH_OUTPUT_LIST,\"$IPV4_ADDRESS:$PORT_NUMBER\""
            else
                 # first line
                 LOGSTASH_OUTPUT_LIST="\"$IPV4_ADDRESS:$PORT_NUMBER\""
            fi
	    LINE_COUNT=$((LINE_COUNT+1))
        done <<< "$LOGSTASH_OUTPUT_HOSTS_PORT_LIST"
  if [ $LINE_COUNT -gt 1 ] ; then
     LOGSTASH_OUTPUT_LIST="[$LOGSTASH_OUTPUT_LIST]"
  fi	  
  echo "LOGSTASH_OUTPUT_LIST = $LOGSTASH_OUTPUT_LIST"
#
##################################################################################################################################
#
KIBANA_BASE_PATH="$ELK_INSTALL_PATH/kibana-7.9.1-linux-x86_64"
KIBANA_CONFIG_PATH="$KIBANA_BASE_PATH/config"
KIBANA_BIN_PATH="$KIBANA_BASE_PATH/bin"
KIBANA_DATA_PATH="$KIBANA_BASE_PATH/data"

# this block will output KIBANA_INPUT_LIST
#       like this "http://172.25.169.201:9200","http://172.25.169.202:9200"
  KIBANA_INPUT_LIST=""
        while read -r LINE; do
           IPV4_ADDRESS="$(/bin/echo $LINE | cut -d ' ' -f 1)"
           PORT_NUMBER="$(/bin/echo $LINE | cut -d ' ' -f 2)"
            if [ ! -z "$KIBANA_INPUT_LIST" ]; then
                 # not first line
                 KIBANA_INPUT_LIST="$KIBANA_INPUT_LIST,\"http://$IPV4_ADDRESS:$PORT_NUMBER\""
            else
                 # first line
                 KIBANA_INPUT_LIST="\"http://$IPV4_ADDRESS:$PORT_NUMBER\""
            fi
        done <<< "$KIBANA_INPUT_HOSTS_PORT_LIST"
  echo "KIBANA_INPUT_LIST = $KIBANA_INPUT_LIST"
#
##################################################################################################################################
#
FILEBEAT_BASE_PATH="$ELK_INSTALL_PATH/filebeat-7.9.1-linux-x86_64"
# this block will output FILEBEAT_OUTPUT_LIST
#       like this "172.25.169.201:5044","172.25.169.202:5044"
  FILEBEAT_OUTPUT_LIST=""
        while read -r LINE; do
           IPV4_ADDRESS="$(/bin/echo $LINE | cut -d ' ' -f 1)"
           PORT_NUMBER="$(/bin/echo $LINE | cut -d ' ' -f 2)"
            if [ ! -z "$FILEBEAT_OUTPUT_LIST" ]; then
                 # not first line
                 FILEBEAT_OUTPUT_LIST="$FILEBEAT_OUTPUT_LIST,\"$IPV4_ADDRESS:$PORT_NUMBER\""
            else
                 # first line
                 FILEBEAT_OUTPUT_LIST="\"$IPV4_ADDRESS:$PORT_NUMBER\""
            fi
        done <<< "$FILEBEAT_OUTPUT_LOGSTASH_HOSTS_PORT_LIST"
  echo "FILEBEAT_OUTPUT_LIST = $FILEBEAT_OUTPUT_LIST"
#
##################################################################################################################################
#####  Special Thanks #####
#
# https://www.cnblogs.com/JetpropelledSnake/p/9893566.html
# https://www.cnblogs.com/JetpropelledSnake/p/10057545.html
# https://www.cnblogs.com/JetpropelledSnake/p/9893550.html
# https://stackoverflow.com/questions/46338286/why-cant-i-install-phantomjs-error-eacces-permission-denied
# https://github.com/npm/npm/issues/2481
# https://www.twblogs.net/a/5b8db6182b71771883401903?lang=zh-cn
# https://zhang0peter.com/2020/02/07/linux-chrome-bug/
#
##################################################################################################################################

say_goodbye() {
        echo "goodbye everyone"
}

install_prerequisite() {
        apt-get update
        apt-get install -y curl wget git fontconfig
        apt-get install -y libnss3-dev libxss1 libasound2

	# create installation base directory
	mkdir -p $ELK_INSTALL_PATH

	# Install OpenJDK 11
	cd $ELK_INSTALL_PATH
	wget "$OPENJDK_11_DOWNLOAD_LINK"
        SHA256SUM_COMPUTED="$(/usr/bin/sha256sum ./$FILENAME_OPENJDK_11 | cut -d ' ' -f 1)"
        [ "$OPENJDK_11_SHA256SUM" == "$SHA256SUM_COMPUTED" ] && echo "OpenJDK tar.gz file sha256sum Matched." || exit 2
	tar zxvf ./$FILENAME_OPENJDK_11
	chown -R root:root $OPENJDK_11_BASE_PATH
        rm -rf $ELK_INSTALL_PATH/jdk
        ln -s $OPENJDK_11_BASE_PATH $ELK_INSTALL_PATH/jdk

	# OpenJDK env variable settings
        echo -e "setting environments variables\n"
        ENVIRONMENTS_FILE=/etc/profile.d/jdk_environments.sh
        rm -rf $ENVIRONMENTS_FILE
        touch $ENVIRONMENTS_FILE
        cat >> $ENVIRONMENTS_FILE << EOF
export JAVA_HOME=OPENJDK_11_SYMBLIC_LINK_PATH
export JRE_HOME=\$JAVA_HOME/jre
export JVM_ARGS="-XmsOPENJDK_11_MINIMAL_HEAP_MEMORY_SIZE -XmxOPENJDK_11_MAXIMUM_HEAP_MEMORY_SIZE"
export CLASSPATH=.:\$JAVA_HOME/lib:\$JRE_HOME/lib
export PATH=\$JAVA_HOME/bin:\$JRE_HOME/bin:\$PATH
EOF
        sed -i -- "s|OPENJDK_11_SYMBLIC_LINK_PATH|$OPENJDK_11_SYMBLIC_LINK_PATH|g" $ENVIRONMENTS_FILE
        sed -i -- "s|OPENJDK_11_MINIMAL_HEAP_MEMORY_SIZE|$OPENJDK_11_MINIMAL_HEAP_MEMORY_SIZE|g" $ENVIRONMENTS_FILE
        sed -i -- "s|OPENJDK_11_MAXIMUM_HEAP_MEMORY_SIZE|$OPENJDK_11_MAXIMUM_HEAP_MEMORY_SIZE|g" $ENVIRONMENTS_FILE
        source /etc/profile
        which java
        java -version
        which javac
        javac -version

        echo -e "OpenJDK installation completed."

	# Install NodeJS
	wget "$NODE_JS_DOWNLOAD_LINK"
	SHA256SUM_COMPUTED="$(/usr/bin/sha256sum ./$FILENAME_NODE_JS | cut -d ' ' -f 1)"
	[ "$NODE_JS_SHA256SUM" == "$SHA256SUM_COMPUTED" ] && echo "Node.js tar.xz file sha256sum Matched." || exit 2
	tar -xvf ./$FILENAME_NODE_JS

	# Install PhantomJS
	wget "$PHANTOM_JS_DOWNLOAD_LINK"	
	SHA256SUM_COMPUTED="$(/usr/bin/sha256sum ./$FILENAME_PHANTOM_JS | cut -d ' ' -f 1)"
	[ "$PHANTOM_JS_SHA256SUM" == "$SHA256SUM_COMPUTED" ] && echo "PhantomJS tar.bz2 file sha256sum Matched." || exit 2
	tar -xvf ./$FILENAME_PHANTOM_JS
	mv $ELK_INSTALL_PATH/${FILENAME_PHANTOM_JS%.tar.bz2} /usr/local/phantomjs
	ln -s /usr/local/phantomjs/bin/phantomjs /usr/bin/

	# Set NodeJS env variables
	cat >> /etc/profile.d/node_environment.sh << "EOF"
export NODE_HOME=ELK_INSTALL_PATH/DIRECTORY_NAME_NODE_JS
export NODE_PATH=$NODE_HOME/lib/node_modules
export PATH=$NODE_HOME/bin:$PATH
EOF
	sed -i -- "s|ELK_INSTALL_PATH|$ELK_INSTALL_PATH|g" /etc/profile.d/node_environment.sh
	sed -i -- "s|DIRECTORY_NAME_NODE_JS|${FILENAME_NODE_JS%.tar.xz}|g" /etc/profile.d/node_environment.sh
	source /etc/profile

	# line 1 for node js
	# line 2 for : max virtual memory areas vm.max_map_count [65530] is too low, increase to at least [262144]
	echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
	echo vm.max_map_count=655360 | sudo tee -a /etc/sysctl.conf
	sysctl -p

	# add user and group
	groupadd $ELK_USER_NAME
	useradd -g $ELK_USER_NAME -m -d /home/$ELK_USER_NAME -s /bin/bash $ELK_USER_NAME
	echo "$ELK_USER_NAME:$ELK_USER_PASSWORD" | chpasswd
	mkdir -p /home/$ELK_USER_NAME
	chown -R $ELK_USER_NAME:$ELK_USER_NAME /home/$ELK_USER_NAME

}

install_elastic_search() {

	cd $ELK_INSTALL_PATH

	# download tar.gz and verify their integrity
	wget "$TAR_GZ_PATH_ELASTICSEARCH"
	wget "$TAR_GZ_PATH_ELASTICSEARCH.sha512"
	FILENAME_ELASTICSEARCH="${TAR_GZ_PATH_ELASTICSEARCH##*/}"
	SHA512SUM_SHOULD_BE="$(/bin/cat $FILENAME_ELASTICSEARCH.sha512 | cut -d ' ' -f 1)"
        SHA512SUM_COMPUTED="$(/usr/bin/sha512sum ./$FILENAME_ELASTICSEARCH | cut -d ' ' -f 1)"
        [ "$SHA512SUM_SHOULD_BE" == "$SHA512SUM_COMPUTED" ] && echo "Elastic tar.gz file sha512sum Matched." || exit 2
	tar zxvf ./$FILENAME_ELASTICSEARCH

	# save every config files a default value copy
	cd $ELASTIC_CONFIG_PATH
	cp ./elasticsearch.yml ./elasticsearch.yml.default
	cp ./jvm.options ./jvm.options.default

	# edit elasticsearch.yml
	IP_ADDRESS="$(/sbin/ip addr show $MY_NETWORK_INTERFACE | grep dynamic | grep -v inet6 | tr -s ' ' | cut -d ' ' -f 3 | cut -d '/' -f 1)"
        sed -i -- "s|#cluster.name: my-application|cluster.name: $ELASTIC_CLUSTER_NAME|g" $ELASTIC_CONFIG_PATH/elasticsearch.yml
	sed -i -- "s|#node.name: node-1|node.name: $ELASTIC_NODE_NAME|g" $ELASTIC_CONFIG_PATH/elasticsearch.yml
        sed -i -- "s|#path.data: /path/to/data|path.data: $ELASTIC_DATA_PATH|g" $ELASTIC_CONFIG_PATH/elasticsearch.yml
        sed -i -- "s|#path.logs: /path/to/logs|path.logs: $ELASTIC_LOGS_PATH|g" $ELASTIC_CONFIG_PATH/elasticsearch.yml
	# https://stackoverflow.com/questions/58800603/java-heap-space-problem-with-elastic-search
        sed -i -- "s|#bootstrap.memory_lock: true|bootstrap.memory_lock: true|g" $ELASTIC_CONFIG_PATH/elasticsearch.yml
        sed -i -- "/bootstrap.memory_lock: true/a bootstrap.system_call_filter: false" $ELASTIC_CONFIG_PATH/elasticsearch.yml
        sed -i -- "s|#network.host: 192.168.0.1|network.host: 127.0.0.1 , $IP_ADDRESS|g" $ELASTIC_CONFIG_PATH/elasticsearch.yml
	sed -i -- "s|#http.port: 9200|http.port: $ELASTIC_HTTP_PORT|g" $ELASTIC_CONFIG_PATH/elasticsearch.yml
	sed -i -- "s|#discovery.seed_hosts: \[\"host1\", \"host2\"\]|discovery.seed_hosts: \[$ELASTIC_IP_LIST\]|g" $ELASTIC_CONFIG_PATH/elasticsearch.yml
	sed -i -- "s|#cluster.initial_master_nodes: \[\"node-1\", \"node-2\"\]|cluster.initial_master_nodes: \[$ELASTIC_IP_LIST\]|g" $ELASTIC_CONFIG_PATH/elasticsearch.yml
	sed -i -- "s|#action.destructive_requires_name: true|action.destructive_requires_name: true|g" $ELASTIC_CONFIG_PATH/elasticsearch.yml

	echo "http.cors.enabled: true" >> $ELASTIC_CONFIG_PATH/elasticsearch.yml
	echo 'http.cors.allow-origin: "*" ' >> $ELASTIC_CONFIG_PATH/elasticsearch.yml

	# edit jvm.options
	sed -i -- "s|Xms1g|Xms$ELASTIC_MINIMAL_HEAP_MEMORY_SIZE|g" $ELASTIC_CONFIG_PATH/jvm.options
	sed -i -- "s|Xmx1g|Xmx$ELASTIC_MAXIMUM_HEAP_MEMORY_SIZE|g" $ELASTIC_CONFIG_PATH/jvm.options

	# change owner/group for whole installation dir
	chown -R $ELK_USER_NAME:$ELK_USER_NAME $ELK_INSTALL_PATH
}

start_elastic_search() {
	# place a start-up script
	cat >> $ELASTIC_BASE_PATH/start_elastic.sh << "EOF"
#!/bin/bash

ELK_USER_NAME="@ELK_USER_NAME"
ELASTIC_BIN_PATH="@ELASTIC_BIN_PATH"

HOME=/home/@ELK_USER_NAME su - @ELK_USER_NAME -c "@ELASTIC_BIN_PATH/elasticsearch &"
EOF
	sed -i -- "s|@ELK_USER_NAME|$ELK_USER_NAME|g" $ELASTIC_BASE_PATH/start_elastic.sh
	sed -i -- "s|@ELASTIC_BIN_PATH|$ELASTIC_BIN_PATH|g" $ELASTIC_BASE_PATH/start_elastic.sh
	chown $ELK_USER_NAME:$ELK_USER_NAME $ELASTIC_BASE_PATH/start_elastic.sh
	chmod +x $ELASTIC_BASE_PATH/start_elastic.sh

	# start elastic-search with user elk's permission
	HOME=/home/$ELK_USER_NAME su - $ELK_USER_NAME -c "$ELASTIC_BIN_PATH/elasticsearch &"

	# test it whether it is running ?
	curl -X GET "http://localhost:$ELASTIC_HTTP_PORT"
}

install_elastic_search_head() {
	
	# change to elk base directory
	cd $ELK_INSTALL_PATH

	# clone the repo
	git clone https://github.com/mobz/elasticsearch-head

	# change dir owner ang group
	chown -R $ELK_USER_NAME:$ELK_USER_NAME $ELASTIC_HEAD_BASE_PATH

	# edit config file and download dependencies
	cd $ELASTIC_HEAD_BASE_PATH
	sed -i -- "s|keepalive: true|keepalive: true,|g" $ELASTIC_HEAD_BASE_PATH/Gruntfile.js
	sed -i -- "/keepalive: true,/a hostname: '*'" $ELASTIC_HEAD_BASE_PATH/Gruntfile.js
	
	HOME=/home/$ELK_USER_NAME su - $ELK_USER_NAME -c "cd $ELASTIC_HEAD_BASE_PATH ; npm install"
        HOME=/home/$ELK_USER_NAME su - $ELK_USER_NAME -c "cd $ELASTIC_HEAD_BASE_PATH ; npm audit fix"
        HOME=/home/$ELK_USER_NAME su - $ELK_USER_NAME -c "cd $ELASTIC_HEAD_BASE_PATH ; npm audit fix --force"
}

start_elastic_search_head() {

	HOME=/home/$ELK_USER_NAME su - $ELK_USER_NAME -c "cd $ELASTIC_HEAD_BASE_PATH ; npm run start"
}

install_kibana() {
	# Change to elk base directory
	cd $ELK_INSTALL_PATH

	# Install kibana
	wget "$TAR_GZ_PATH_KIBANA"
	wget "$TAR_GZ_PATH_KIBANA.sha512"
	SHA512SUM_SHOULD_BE="$(/bin/cat $FILENAME_KIBANA.sha512 | cut -d ' ' -f 1)"
        SHA512SUM_COMPUTED="$(/usr/bin/sha512sum ./$FILENAME_KIBANA | cut -d ' ' -f 1)"
        [ "$SHA512SUM_SHOULD_BE" == "$SHA512SUM_COMPUTED" ] && echo "Kibana tar.gz file sha512sum Matched." || exit 2
	tar zxvf ./$FILENAME_KIBANA

	# Edit config file
	cd $KIBANA_CONFIG_PATH
	cp ./kibana.yml ./kibana.yml.default
	sed -i -- "s|#server.port: 5601|server.port: $KIBANA_HTTP_PORT|g" $KIBANA_CONFIG_PATH/kibana.yml
	sed -i -- "s|#server.host: \"localhost\"|server.host: \"$IP_ADDRESS\"|g" $KIBANA_CONFIG_PATH/kibana.yml
	sed -i -- "s|#elasticsearch.hosts: \[\"http://localhost:9200\"\]|elasticsearch.hosts: \[$KIBANA_INPUT_LIST\]|g" $KIBANA_CONFIG_PATH/kibana.yml
	sed -i -- 's|#kibana.index: ".kibana"|kibana.index: ".kibana"|g' $KIBANA_CONFIG_PATH/kibana.yml
}

start_kibana() {
	# place a start-up script
	cat >> $KIBANA_BASE_PATH/start_kibana.sh << "EOF"
#!/bin/bash

ELK_USER_NAME="@ELK_USER_NAME"
KIBANA_BIN_PATH="@KIBANA_BIN_PATH"

HOME=/home/@ELK_USER_NAME su - @ELK_USER_NAME -c "@KIBANA_BIN_PATH/kibana &"
EOF
	sed -i -- "s|@ELK_USER_NAME|$ELK_USER_NAME|g" $KIBANA_BASE_PATH/start_kibana.sh
	sed -i -- "s|@KIBANA_BIN_PATH|$KIBANA_BIN_PATH|g" $KIBANA_BASE_PATH/start_kibana.sh
	chown $ELK_USER_NAME:$ELK_USER_NAME $KIBANA_BASE_PATH/start_kibana.sh
	chmod +x $KIBANA_BASE_PATH/start_kibana.sh

	# Start kibana with user elk's permission
	HOME=/home/$ELK_USER_NAME su - $ELK_USER_NAME -c "$KIBANA_BIN_PATH/kibana &"
}

install_logstash() {
	# Change to elk base directory
        cd $ELK_INSTALL_PATH

	# Install Logstash
	wget "$TAR_GZ_PATH_LOGSTASH"
	wget "$TAR_GZ_PATH_LOGSTASH.sha512"
	FILENAME_LOGSTASH="${TAR_GZ_PATH_LOGSTASH##*/}"
	SHA512SUM_SHOULD_BE="$(/bin/cat $FILENAME_LOGSTASH.sha512 | cut -d ' ' -f 1)"
        SHA512SUM_COMPUTED="$(/usr/bin/sha512sum ./$FILENAME_LOGSTASH | cut -d ' ' -f 1)"
        [ "$SHA512SUM_SHOULD_BE" == "$SHA512SUM_COMPUTED" ] && echo "Logstash tar.gz file sha512sum Matched." || exit 2
	tar zxvf ./$FILENAME_LOGSTASH
	cd $LOGSTASH_CONFIG_PATH

	# Generate a config file for logstash
	cat >> $LOGSTASH_CONFIG_PATH/logstash-es.conf << "EOF"
input {
  stdin { }
  beats {
    port => LOGSTASH_INPUT_PORT
    ssl => false
  }
}
output {
    elasticsearch {
        action => "index"
        hosts => LOGSTASH_OUTPUT_LIST
        index  => "logstash-%{+YYYY-MM}"
    }
    stdout { codec=> rubydebug }
}
EOF
	sed -i -- "s|LOGSTASH_INPUT_PORT|$LOGSTASH_INPUT_PORT|g" $LOGSTASH_CONFIG_PATH/logstash-es.conf
	sed -i -- "s|LOGSTASH_OUTPUT_LIST|$LOGSTASH_OUTPUT_LIST|g" $LOGSTASH_CONFIG_PATH/logstash-es.conf
	chown $ELK_USER_NAME:$ELK_USER_NAME $LOGSTASH_CONFIG_PATH/logstash-es.conf
	chmod 644 $LOGSTASH_CONFIG_PATH/logstash-es.conf

	# change jvm.options settings
	cp $LOGSTASH_CONFIG_PATH/jvm.options $LOGSTASH_CONFIG_PATH/jvm.options.default
	sed -i -- "s|-Xms1g|-Xms$LOGSTASH_MINIMAL_HEAP_MEMORY_SIZE|g" $LOGSTASH_CONFIG_PATH/jvm.options
	sed -i -- "s|-Xmx1g|-Xms$LOGSTASH_MAXIMUM_HEAP_MEMORY_SIZE|g" $LOGSTASH_CONFIG_PATH/jvm.options
}

start_logstash() {
	# Place a start-up script
	cat >> $LOGSTASH_BASE_PATH/start_logstash.sh << "EOF"
#!/bin/bash

ELK_USER_NAME="@ELK_USER_NAME"
LOGSTASH_BIN_PATH="@LOGSTASH_BIN_PATH"
LOGSTASH_CONFIG_PATH="@LOGSTASH_CONFIG_PATH"

HOME=/home/@ELK_USER_NAME su - @ELK_USER_NAME -c "@LOGSTASH_BIN_PATH/logstash -f @LOGSTASH_CONFIG_PATH/logstash-es.conf &"
EOF
        sed -i -- "s|@ELK_USER_NAME|$ELK_USER_NAME|g" $LOGSTASH_BASE_PATH/start_logstash.sh
        sed -i -- "s|@LOGSTASH_BIN_PATH|$LOGSTASH_BIN_PATH|g" $LOGSTASH_BASE_PATH/start_logstash.sh
        sed -i -- "s|@LOGSTASH_CONFIG_PATH|$LOGSTASH_CONFIG_PATH|g" $LOGSTASH_BASE_PATH/start_logstash.sh
        chown $ELK_USER_NAME:$ELK_USER_NAME $LOGSTASH_BASE_PATH/start_logstash.sh
        chmod +x $LOGSTASH_BASE_PATH/start_logstash.sh

	# Start logstash with user elk's permission
	HOME=/home/$ELK_USER_NAME su - $ELK_USER_NAME -c "$LOGSTASH_BIN_PATH/logstash -f $LOGSTASH_CONFIG_PATH/logstash-es.conf &"
}

install_filebeat() {
	# Change to elk base directory
        cd $ELK_INSTALL_PATH

	# Install Filebeat
	wget "$TAR_GZ_PATH_FILEBEAT"
	wget "$TAR_GZ_PATH_FILEBEAT.sha512"
	FILENAME_FILEBEAT="${TAR_GZ_PATH_FILEBEAT##*/}"
	SHA512SUM_SHOULD_BE="$(/bin/cat $FILENAME_FILEBEAT.sha512 | cut -d ' ' -f 1)"
        SHA512SUM_COMPUTED="$(/usr/bin/sha512sum ./$FILENAME_FILEBEAT | cut -d ' ' -f 1)"
        [ "$SHA512SUM_SHOULD_BE" == "$SHA512SUM_COMPUTED" ] && echo "Filebeat tar.gz file sha512sum Matched." || exit 2
	tar zxvf ./$FILENAME_FILEBEAT

	# Edit config file
	cd $FILEBEAT_BASE_PATH
	cp $FILEBEAT_BASE_PATH/filebeat.yml $FILEBEAT_BASE_PATH/filebeat.yml.default
	chown root:root $FILEBEAT_BASE_PATH/filebeat.yml*
	
	sed -i -- 's|- type: log|- type: log|g' $FILEBEAT_BASE_PATH/filebeat.yml
	sed -i -- 's|  enabled: false|  enabled: true|g' $FILEBEAT_BASE_PATH/filebeat.yml
	sed -i -- 's|- /var/log/*.log|- /var/log/*.log|g' $FILEBEAT_BASE_PATH/filebeat.yml
	sed -i -- 's|output.elasticsearch:|#output.elasticsearch:|g' $FILEBEAT_BASE_PATH/filebeat.yml
	sed -i -- 's|hosts: \["localhost:9200"\]|#hosts: \["localhost:9200"\]|g' $FILEBEAT_BASE_PATH/filebeat.yml
	sed -i -- 's|#output.logstash:|output.logstash:|g' $FILEBEAT_BASE_PATH/filebeat.yml
	sed -i -- "s|#hosts: \[\"localhost:5044\"\]|hosts: \[$FILEBEAT_OUTPUT_LIST\]|g" $FILEBEAT_BASE_PATH/filebeat.yml
}

start_filebeat() {
	# Change Directory
	cd $FILEBEAT_BASE_PATH

	# Start filebeat with root permission
	$FILEBEAT_BASE_PATH/filebeat -c $FILEBEAT_BASE_PATH/filebeat.yml

	# test whether if Elasticsearch is indeed receiving this data
	curl -X GET "http://localhost:$ELASTIC_HTTP_PORT/filebeat-*/_search?pretty"
}

install_rally() {
	apt-get update
	apt-get install gcc python3-pip python3-dev -y
	pip3 install esrally
	# esrally configure
	# esrally list tracks
	# esrally --track=pmc --target-hosts=172.25.169.201:9200,172.25.169.202:9200 --pipeline=benchmark-only
}	

test_it() {
	echo "hi"
}

error_fix() {
	# fix this error when elastic-search start
	# ERROR: [2] bootstrap checks failed
        # [1]: max file descriptors [4096] for elasticsearch process is too low, increase to at least [65535]
        # [2]: max number of threads [1024] for user [elk] is too low, increase to at least [4096]
        # ERROR: Elasticsearch did not exit normally - check the logs at /usr/local/app/elasticsearch-7.9.1/logs/logger.log
	
	cp /etc/security/limits.conf /etc/security/limits.conf.default
	echo "* soft nofile 65536" >> /etc/security/limits.conf
	echo "* hard nofile 65536" >> /etc/security/limits.conf
	echo "* soft nproc 32000" >> /etc/security/limits.conf
	echo "* hard nproc 32000" >> /etc/security/limits.conf
	echo "* hard memlock unlimited" >> /etc/security/limits.conf
	echo "* soft memlock unlimited" >> /etc/security/limits.conf

	# see user elk's resource limit on this machine
	#su elk -c 'ulimit -Hn'

	# someone's suggestion
	# https://www.twblogs.net/a/5ca0b862bd9eee5b1a069eb8
	cp /etc/systemd/system.conf /etc/systemd/system.conf.default
	sed -i -- "s|#DefaultLimitNOFILE=1024:524288|DefaultLimitNOFILE=65536|g" /etc/systemd/system.conf
	sed -i -- "s|#DefaultLimitNPROC=|DefaultLimitNPROC=32000|g" /etc/systemd/system.conf
	sed -i -- "s|#DefaultLimitMEMLOCK=|DefaultLimitMEMLOCK=infinity|g" /etc/systemd/system.conf
	systemctl daemon-reload

	# dont forget turn off swap , command below just for this time , edit /etc/fstab and comment out swap that line
	swapoff -a
}	

change_dir_owner_group() {

	# change directory owner and group
        chown -R $ELK_USER_NAME:$ELK_USER_NAME $ELK_INSTALL_PATH
	cd $ELK_INSTALL_PATH
        find . -type d -exec chmod 755 {} \;

	# For this strange error messages , u have to change all of filebeat-xxx.yml owned by root user and group
	# ??? Exiting: error loading config file: config file ("filebeat.yml") must be owned by the user identifier (uid=0) or root
	cd $FILEBEAT_BASE_PATH
	chown root:root *.yml
	chown 644 $FILEBEAT_BASE_PATH/filebeat.yml*
}

main() {
        install_prerequisite
	install_elastic_search
	install_elastic_search_head
	install_kibana
	install_logstash
	install_filebeat
	install_rally
	change_dir_owner_group
	#test_it
	error_fix
	start_elastic_search
	start_elastic_search_head
	start_kibana
	start_logstash
	start_filebeat
}

echo -e "This script will install elastic stack 7.x  on this host \n"
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

