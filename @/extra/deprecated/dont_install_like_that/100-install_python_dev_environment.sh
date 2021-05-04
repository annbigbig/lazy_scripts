#!/bin/bash
##
## dont install python like this , it will mess up some of your Ubuntu native features
##
say_goodbye() {
        echo "goodbye everyone"
}

install_prerequisite() {
	apt-get update
	apt-get install -y zlib1g-dev tk-dev
}

install_python() {

	cd /usr/local/src
        wget https://www.python.org/ftp/python/3.8.5/Python-3.8.5.tgz

        # checksum could be found here
        # https://www.python.org/downloads/release/python-385/
        MD5SUM_SHOULD_BE="e2f52bcf531c8cc94732c0b6ff933ff0"
        MD5SUM_COMPUTED="$(/usr/bin/md5sum ./Python-3.8.5.tgz | cut -d ' ' -f 1)"
        [ "$MD5SUM_SHOULD_BE" == "$MD5SUM_COMPUTED" ] && echo "download Python-3.8.x.tgz md5sum matched." || exit 2

	tar zxvf ./Python-3.8.5.tgz
	cd Python-3.8.5/
	./configure --prefix=/usr/local/Python-3.8.5
	make
	make test
	make install

	ln -s /usr/local/Python-3.8.5 /usr/local/Python3
	rm -rf /usr/local/src/Python-3.8.5.tgz
}

set_python_priority() {
        echo -e "set python3 priority \n"
        update-alternatives --install "/usr/bin/python3" "python3" "/usr/local/Python3/bin/python3" 385
        update-alternatives --install "/usr/bin/python3" "python3" "/usr/bin/python3.8" 382
        update-alternatives --set python3 /usr/local/Python3/bin/python3
        update-alternatives --list python3
	# to adjust priority manually , use this command below :
	# update-alternatives --config python3
	# to remove alternative option , use this command , if it cause any problem on your system , don't forget delete /etc/profile.d/python_environments.sh too
	# update-alternatives --remove "python3" "/usr/local/Python3/bin/python3"
        echo -e "python3 priority changed. \n"
}

set_environments_variables() {
        echo -e "setting environments variables\n"
        ENVIRONMENTS_FILE=/etc/profile.d/python_environments.sh
        rm -rf $ENVIRONMENTS_FILE
        touch $ENVIRONMENTS_FILE
        cat >> $ENVIRONMENTS_FILE << EOF
export PATH=/usr/local/Python3/bin:\$PATH
EOF
        source /etc/profile
        which python3
	which pip3
        python3 -V
        echo -e "environments variables settings completed."
}

fix_error() {
	# when u run 'apt-get update' then get following error messages:
	#
	# Traceback (most recent call last):
        #   File "/usr/lib/cnf-update-db", line 8, in <module>
        #     from CommandNotFound.db.creator import DbCreator
        # ModuleNotFoundError: No module named 'CommandNotFound'
        #
        # just change python3 to python3.8 in cnf-update-db will solve this problem
        sed -i -- 's|python3|python3.8|g' /usr/lib/cnf-update-db	
}

main() {
	install_prerequisite
        install_python
	set_python_priority
	set_environments_variables
	fix_error
}

echo -e "This script will install python 3.8.x dev environment on this host \n"
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

