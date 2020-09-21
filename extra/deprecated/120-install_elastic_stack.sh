#!/bin/bash
##################################################################################################################################
# this script will install Elastic Stack 7.x on this computer (Ubuntu 20.04)
# there are some parameters have to be confirmed before u run this script :
#
MY_NETWORK_INTERFACE="eth0"
ELASTIC_CLUSTER_NAME="es_cluster"
ELASTIC_HTTP_PORT="9200"
ELASTIC_NODE_NAME="esnode-1"
#
KIBANA_ADMIN_USER="kibanaadmin"
KIBANA_ADMIN_PASSWD="password"
KIBANA_FQDN="vhost201.dq5rocks.com"
#
LOGSTASH_INPUT_PORT="5044"
LOGSTASH_OUTPUT_HOSTS="\"localhost:9200\""
#
FILEBEAT_OUTPUT_LOGSTASH_HOSTS="\"localhost:5044\""
FILEBEAT_OUTPUT_ELASTICSEARCH_HOSTS="\"localhost:9200\""
FILEBEAT_SETUP_KIBANA_HOST="127.0.0.1:5601"
#
##################################################################################################################################
#####  Special Thanks #####
#
# https://www.digitalocean.com/community/tutorials/how-to-install-elasticsearch-logstash-and-kibana-elastic-stack-on-ubuntu-20-04
# https://linuxize.com/post/how-to-install-elasticsearch-on-ubuntu-20-04/
# https://ohdoylerules.com/tricks/openssl-passwd-without-prompt/
##################################################################################################################################

say_goodbye() {
        echo "goodbye everyone"
}

install_prerequisite() {
        apt-get update
        apt-get install -y curl apt-transport-https ca-certificates wget
}

install_elastic_search() {
	# install it
	curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
        echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-7.x.list
	apt-get update
	apt-get install -y elasticsearch

	# configure it
	cp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.default
	IP_ADDRESS="$(/sbin/ip addr show $MY_NETWORK_INTERFACE | grep dynamic | grep -v inet6 | tr -s ' ' | cut -d ' ' -f 3 | cut -d '/' -f 1)"
        sed -i -- "s|#cluster.name: my-application|cluster.name: $ELASTIC_CLUSTER_NAME|g" /etc/elasticsearch/elasticsearch.yml
        sed -i -- "s|#network.host: 192.168.0.1|network.host: 127.0.0.1 , $IP_ADDRESS|g" /etc/elasticsearch/elasticsearch.yml
	sed -i -- "s|#http.port: 9200|http.port: $ELASTIC_HTTP_PORT|g" /etc/elasticsearch/elasticsearch.yml
	sed -i -- "s|#node.name: node-1|node.name: $ELASTIC_NODE_NAME|g" /etc/elasticsearch/elasticsearch.yml
	#sed -i -- '/----- Discovery -----/a discovery.type: single-node' /etc/elasticsearch/elasticsearch.yml
	sed -i -- 's|#discovery.seed_hosts: \["host1", "host2"\]|discovery.seed_hosts: \[\]|g' /etc/elasticsearch/elasticsearch.yml
	sed -i -- 's|#cluster.initial_master_nodes: \["node-1", "node-2"\]|cluster.initial_master_nodes: \[\]|g' /etc/elasticsearch/elasticsearch.yml

	# start and enable its service
	systemctl enable elasticsearch
        systemctl start elasticsearch

	# test it whether it is running ?
	curl -X GET "localhost:9200"
}

install_kibana() {
	# install it
	apt-get install -y kibana
	systemctl enable kibana
	systemctl start kibana

	# add valid users for accessing kibana
	#echo "kibanaadmin:`echo 'password' | openssl passwd -apr1 -stdin`" | tee -a ./htpasswd.users
	mkdir -p /usr/local/nginx/auth
	cd /usr/local/nginx/auth
	echo "$KIBANA_ADMIN_USER:`echo "$KIBANA_ADMIN_PASSWD" | openssl passwd -apr1 -stdin`" | tee -a ./htpasswd.users
	chown -R nginx:nginx /usr/local/nginx/auth
	chmod 644 /usr/local/nginx/auth/htpasswd.users

	# edit nginx config file for kibana
	cat >> /usr/local/nginx/conf.d/$KIBANA_FQDN.conf << "EOF"
server {
    listen 80;

    server_name KIBANA_FQDN;

    auth_basic "Restricted Access";
    auth_basic_user_file /usr/local/nginx/auth/htpasswd.users;
    # Logging --
    access_log  logs/KIBANA_FQDN.access.log;
    error_log  logs/KIBANA_FQDN.error.log notice;

    location / {
        proxy_pass http://localhost:5601;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF
	sed -i -- "s|KIBANA_FQDN|$KIBANA_FQDN|g" /usr/local/nginx/conf.d/$KIBANA_FQDN.conf
	chown nginx:nginx /usr/local/nginx/conf.d/$KIBANA_FQDN.conf
	chmod 644 /usr/local/nginx/conf.d/$KIBANA_FQDN.conf

	# test nginx.conf to see if syntax error exist
        CONFIG_SYNTAX_ERR="$(/usr/local/nginx/sbin/nginx -t -c /usr/local/nginx/conf/nginx.conf 2>&1 | grep 'test failed' | wc -l)"
        [ "$CONFIG_SYNTAX_ERR" -eq 1 ] && echo 'SYNTAX ERROR in nginx.conf' || echo 'nginx.conf is GOOD'

	# restart nginx service
	systemctl restart nginx.service
}

install_logstash() {
	# install it
	apt-get install -y logstash

	# configure it
	cat >> /etc/logstash/conf.d/02-beats-input.conf << "EOF"
input {
  beats {
    port => LOGSTASH_INPUT_PORT
  }
}
EOF
	sed -i -- "s|LOGSTASH_INPUT_PORT|$LOGSTASH_INPUT_PORT|g" /etc/logstash/conf.d/02-beats-input.conf

	cat >> /etc/logstash/conf.d/30-elasticsearch-output.conf << "EOF"
output {
  if [@metadata][pipeline] {
    elasticsearch {
    hosts => [LOGSTASH_OUTPUT_HOSTS]
    manage_template => false
    index => "%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}"
    pipeline => "%{[@metadata][pipeline]}"
    }
  } else {
    elasticsearch {
    hosts => [LOGSTASH_OUTPUT_HOSTS]
    manage_template => false
    index => "%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}"
    }
  }
}
EOF
	sed -i -- "s|LOGSTASH_OUTPUT_HOSTS|$LOGSTASH_OUTPUT_HOSTS|g" /etc/logstash/conf.d/30-elasticsearch-output.conf

	# test logstash config
	sudo -u logstash /usr/share/logstash/bin/logstash --path.settings /etc/logstash -t

	# start logstash service
	systemctl enable logstash
	systemctl start logstash

}

install_filebeat() {
	# install it
	apt-get install -y filebeat

	# configure it
	cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.default
	sed -i -- 's|output.elasticsearch:|#output.elasticsearch:|g' /etc/filebeat/filebeat.yml
	sed -i -- 's|hosts: \["localhost:9200"\]|#hosts: \["localhost:9200"\]|g' /etc/filebeat/filebeat.yml
	sed -i -- 's|#output.logstash:|output.logstash:|g' /etc/filebeat/filebeat.yml
	sed -i -- "s|#hosts: \[\"localhost:5044\"\]|hosts: \[$FILEBEAT_OUTPUT_LOGSTASH_HOSTS\]|g" /etc/filebeat/filebeat.yml

	# enable 'system' module
	filebeat modules enable system
	filebeat setup --pipelines --modules system
	filebeat setup --index-management -E output.logstash.enabled=false -E "output.elasticsearch.hosts=[$FILEBEAT_OUTPUT_ELASTICSEARCH_HOSTS]"
	filebeat setup -E output.logstash.enabled=false -E output.elasticsearch.hosts=[$FILEBEAT_OUTPUT_ELASTICSEARCH_HOSTS] -E setup.kibana.host=$FILEBEAT_SETUP_KIBANA_HOST
	filebeat modules list

	# enable and start service
	systemctl enable filebeat
	systemctl start filebeat

	# test whether if Elasticsearch is indeed receiving this data
	curl -XGET "http://localhost:$ELASTIC_HTTP_PORT/filebeat-*/_search?pretty"
}	

main() {
        install_prerequisite
        install_elastic_search
	install_kibana
	install_logstash
	install_filebeat
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

