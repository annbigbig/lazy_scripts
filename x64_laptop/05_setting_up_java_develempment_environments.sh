#!/bin/bash
# This script will install jdk 7/8 and tomcat 6/7/8 for you
# you can set which version of jdk/tomcat that you want to active
ACTIVE_JDK="7"
ACTIVE_TOMCAT="6"
#############################################################
install_jdk(){
  echo -e "ready to install jdk \n"
  cd /usr/local/

  wget --no-check-certificate \
  --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" \
  http://download.oracle.com/otn-pub/java/jdk/8u66-b17/jdk-8u66-linux-x64.tar.gz

  wget --no-cookies \
  --no-check-certificate \
  --header "Cookie: oraclelicense=accept-securebackup-cookie" \
  http://download.oracle.com/otn-pub/java/jdk/7u79-b15/jdk-7u79-linux-x64.tar.gz

  tar -zxvf ./jdk-8u66-linux-x64.tar.gz
  tar -zxvf ./jdk-7u79-linux-x64.tar.gz

  if [ "$ACTIVE_JDK" == "7" ]; then
     ln -s ./jdk1.7.0_79 ./jdk
  elif [ "$ACTIVE_JDK" == "8" ]; then
     ln -s ./jdk1.8.0_66 ./jdk
  fi

  echo -e "delete tar.gz file"
  rm -rf ./jdk-8u66-linux-x64.tar.gz
  rm -rf ./jdk-7u79-linux-x64.tar.gz
  echo -e "done.\n"

}

install_tomcat(){
   echo -e "ready to install tomcat \n"
   cd /usr/local/

   wget http://apache.stu.edu.tw/tomcat/tomcat-6/v6.0.44/bin/apache-tomcat-6.0.44.tar.gz
   wget http://ftp.tc.edu.tw/pub/Apache/tomcat/tomcat-7/v7.0.67/bin/apache-tomcat-7.0.67.tar.gz
   wget http://apache.stu.edu.tw/tomcat/tomcat-8/v8.0.30/bin/apache-tomcat-8.0.30.tar.gz

   tar -zxvf ./apache-tomcat-6.0.44.tar.gz
   tar -zxvf ./apache-tomcat-7.0.67.tar.gz
   tar -zxvf ./apache-tomcat-8.0.30.tar.gz

   if [ "$ACTIVE_TOMCAT" == "6" ]; then
     ln -s ./apache-tomcat-6.0.44 ./tomcat
   elif [ "$ACTIVE_TOMCAT" == "7" ]; then
     ln -s ./apache-tomcat-7.0.67 ./tomcat
   elif [ "$ACTIVE_TOMCAT" == "8" ]; then
     ln -s ./apache-tomcat-8.0.30 ./tomcat
   fi
 
   echo -e "delete tar.gz files \n"
   rm -rf ./apache-tomcat-6.0.44.tar.gz
   rm -rf ./apache-tomcat-7.0.67.tar.gz
   rm -rf ./apache-tomcat-8.0.30.tar.gz
   echo -e "done.\n"
}

setting_environments_var(){
   echo -e "setting environments variables \n"
   ENVIRONMENTS_FILE=/etc/profile.d/jdk_environments.sh
   touch $ENVIRONMENTS_FILE
   cat >> $ENVIRONMENTS_FILE << EOF
export JAVA_HOME=/usr/local/jdk
export JRE_HOME=\$JAVA_HOME/jre
export CATALINA_HOME=/usr/local/tomcat
export CLASSPATH=.:\$JAVA_HOME/lib:\$JRE_HOME/lib:\$CATALINA_HOME/lib
export PATH=\$JAVA_HOME/bin:\$JRE_HOME/bin:\$CATALINA_HOME/bin:\$PATH
EOF
   source $ENVIRONMENTS_FILE
   echo -e "\$PATH=$PATH \n"
   echo -e "\$CLASSPATH=$CLASSPATH \n"
   which java
   java -version
   which javac
   javac -version
   echo -e "done."
}

say_goodbye(){
   echo -e "goodbye everyone \n"
}

main(){
  install_jdk
  install_tomcat
  setting_environments_var
}

echo -e "This script will install jdk and tomcat for you,"
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
