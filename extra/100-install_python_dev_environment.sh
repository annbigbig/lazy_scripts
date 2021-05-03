#!/bin/bash
##
## Ref links : https://phoenixnap.com/kb/how-to-install-python-3-ubuntu
##             https://linuxhint.com/install_python_pip_tool_ubuntu/
##
##
say_goodbye() {
        echo "goodbye everyone"
}

install_prerequisite() {
	apt-get update
	apt-get install -y zlib1g-dev tk-dev
}

install_python2() {
	add-apt-repository universe
	apt install python2
	curl https://bootstrap.pypa.io/get-pip.py --output get-pip.py
	python2 get-pip.py
}

install_python3() {
	apt install software-properties-common
	add-apt-repository ppa:deadsnakes/ppa
	apt update
	apt install python3.8 python3-pip
}

set_python_priority() {
        update-alternatives --install /usr/bin/python python /usr/bin/python2 2
        update-alternatives --install /usr/bin/python python /usr/bin/python3 3
        update-alternatives --set python /usr/bin/python3
	# update-alternatives --config python
}

set_environments_variables() {

}

fix_error() {

}

main() {
	install_prerequisite
        install_python2
        install_python3
	set_python_priority
	#set_environments_variables
	#fix_error
}

echo -e "This script will install python2 python3 dev environment on this host \n"
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

