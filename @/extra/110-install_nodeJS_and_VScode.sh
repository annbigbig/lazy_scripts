#!/bin/bash
##
## all of commands in this script were inspired by these link :
## https://www.digitalocean.com/community/tutorials/how-to-install-node-js-on-ubuntu-20-04
## https://code.visualstudio.com/docs/setup/linux
## https://code.visualstudio.com/docs/nodejs/vuejs-tutorial
## https://marketplace.visualstudio.com/items?itemName=octref.vetur
##
OS_TYPE="Desktop"  ## install Visual Studio Code only when OS_TYPE set to 'Desktop'
##

say_goodbye() {
        echo "goodbye everyone"
}

install_prerequisite() {
	apt-get update
	apt-get install curl -y
}

install_nodeJS() {
	
	# apt-get install nodejs -y            # version number of installed nodeJS is too old (10.19)
	# apt-get install npm -y               # so i decided to remove them
	# which nodejs && which npm
	# nodejs -v && npm -v
	# apt-get remove --purge nodejs -y     # and choose install them from newest PPA
	cd /tmp
	curl -sL https://deb.nodesource.com/setup_14.x -o nodesource_setup.sh
	chmod +x /tmp/nodesource_setup.sh
	bash nodesource_setup.sh

	apt-get install nodejs -y
	# no need to install npm seperately , it already contains npm u need
	which node
	which npm
	node -v
	npm -v
}

install_VScode() {
	if [ $OS_TYPE == "Desktop" ] ; then
             echo "u already have snap pre-installed on your system if u use Ubuntu 20.04 "
	     snap install --classic code # or code-insiders
	fi

	##########################################################################
	##                                                                      ##
	##  dont forget to install Vetur                                        ##
        ##  it's a VUE tooling for VScode                                       ##
	##  open VScode editor first then press Ctrl + P then paste this line   ##
	##  ext install octref.vetur                                            ##
        ##  it will guide u to complete the installation                        ##
	##                                                                      ##
        ##########################################################################
}

install_vueCLI() {
        npm install -g @vue/cli
	which vue        # looking for where executable file is
	vue --version    # make sure that u really installed VUE-CLI properly

	########### try to create a hello-world VUE app and run it ################
	#                                                                         #
	#  cd ~                                                                   #
	#  mkdir vue_applications                                                 #
	#  cd vue_applications                                                    #
	#  vue create my-app                                                      #
	#  cd my-app                                                              #
        #  npm list vue version    (check vue version in this project directory)  #
	#  npm info vue            (check vue version globally on this computer)  #
	#  npm run serve                                                          #
	#                                                                         #
	###########################################################################
	#                                                                         #
	#  Hint : dont run npm commands like this                                 #
	#         sudo npm install    or   sudo npm <anything>                    #
	#  Use :  sudo npm install -g only for your personal PC ,                 #
        #             -g means 'globally'                                         #
        #                                                                         #
	###########################################################################
}

install_webpack() {
	npm install webpack -g
	npm install webpack-cli -g
	which webpack
	webpack -v
}	

fix_errors() {
	# https://bin.zmide.com/?p=339
	# https://github.com/gatsbyjs/gatsby/issues/11406
	echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
}

main() {
	install_prerequisite
        install_nodeJS
	install_VScode
	install_vueCLI
	install_webpack
	fix_errors
}

echo -e "This script will install nodeJS and VScode dev environment on this host \n"
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

