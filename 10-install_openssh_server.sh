#!/bin/bash
#######################################  <<Tested on Ubuntu Mate 20.04 Desktop Edition>> #####
#
# This script will install openssh-server on Ubuntu 20.04 LTS
# it will change sshd port number from default 22 to the number you specified here
# (range could be: 1024 to 65535)
#
SSHD_LISTENING_PORT="36000"
#
# and append the public key you specify here to /home/$AUTHORIZED_USER/.ssh/authorzied_keys
# you could find your own public key at your local computer's /home/$USER/.ssh/id_rsa.pub
# and this public key is mine, dont forget replace it with yours before you run this script
PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCeAV+ikReUS2tJtgTmCUYNm3pTxnBo4dM+rSgvci4kvj54DOGG4ZBZ0zWPjdNGCyf9XA1pmhth8PNA6VBuzUvITlMC6HLzM0qqOVa0WQzTnbjNo8NEKZy49MPT0VUlhh9T7wb+zmAQzoiMOZ6TWO9Qmykdv63hsr97Uq9FEPFp289lyWNMMnr8aMyOSk962sV+iGo0/KdG9uwg2n4XgFy9DYeHzChyhk75HXgb7ElmLIZFSZ6UEkLkiYCexJGvqPlMJowOEItz8kjVa4eWBdQKfzcpf0Qi3+IaV1u1zJlxJoYDLe7xwoSrZmPUippT8iHkCV54QhAtw3daRh4oyEjv annbigbig@gmail.com"
#
AUTHORIZED_USER="labasky"
#
###############################################################################################

say_goodbye() {
	echo "goodbye everyone"
}

install_openssh_server() {
	OPENSSH_SERVER_HAS_BEEN_INSTALL=$(dpkg --get-selections | grep openssh-server)
	if [ -z $OPENSSH_SERVER_HAS_BEEN_INSTALL ] ; then
		apt-get update
		echo -e "install openssh-server ... \n"
		apt-get install -y openssh-server
                echo -e "done"
	fi
}

change_sshd_settings() {
	CONFIG_FILE_PATH="/etc/ssh/sshd_config"
	BACKUP_CONFIG_FILE_PATH="/etc/ssh/sshd_config.default"
	if [ ! -f $BACKUP_CONFIG_FILE_PATH ]; then
		cp $CONFIG_FILE_PATH $BACKUP_CONFIG_FILE_PATH
	fi

        # prevent password logins
        sed -i -- 's|#PasswordAuthentication yes|PasswordAuthentication no|g' $CONFIG_FILE_PATH
        sed -i -- 's|#PermitEmptyPasswords no|PermitEmptyPasswords no|g' $CONFIG_FILE_PATH

        # this error found in Ubuntu 20.04 Server edition
        # point /etc/resolv.conf to correct path for surpressing error below in /var/log/syslog
        # [ Server returned error NXDOMAIN, mitigating potential DNS violation DVE-2018-0001 ]
        # https://askubuntu.com/questions/1058750/new-alert-keeps-showing-up-server-returned-error-nxdomain-mitigating-potential

        if [ -L /etc/resolv.conf ]; then
                rm -rf /etc/resolv.conf
                ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
        fi

        # and here are 3 more problems, one is telling u to find problem with '/usr/sbin/sshd -T' command, it will show possible errors clue
        # two is telling u how to re-generate keys if u found strange error : all of your public/private keys in /etc/ssh/ were actually empty files.
        # three is telling u how to re-generate keys for all the algorithm (dsa/rsa//ecdsa/ed25519...) with single command
        # https://askubuntu.com/questions/1113607/failed-to-start-openbsd-secure-shell-server-error-when-i-try-to-run-apt-get-or-t
        # https://wangxianggit.github.io/sshd%20no%20hostkeys%20available/
        # https://serverfault.com/questions/471327/how-to-change-a-ssh-host-key

        if [ ! -s /etc/ssh/ssh_host_dsa_key -a ! -s /etc/ssh/ssh_host_dsa_key.pub ]; then
                rm -rf /etc/ssh/ssh_host_*
                ssh-keygen -A
                chown root:root /etc/ssh/ssh_host_*
                chmod 600 /etc/ssh/ssh_host_*
                chmod 644 /etc/ssh/ssh_host_dsa_*.pub
        fi

	# check /var/run/sshd existed or not, this is also a weird bug
        if [ ! -d /var/run/sshd ]; then
                mkdir -p -m0755 /var/run/sshd
                chown root:root /var/run/sshd
        fi

	if [ $SSHD_LISTENING_PORT -gt 1024 ] && [ $SSHD_LISTENING_PORT -lt 65535 ] ; then
		echo -e "modify $CONFIG_FILE_PATH \n replace 'Port 22' with 'Port $SSHD_LISTENING_PORT' \n"
		sed -i -- "s|#Port 22|Port 22|g" $CONFIG_FILE_PATH
		sed -i -- "s|Port 22|Port $SSHD_LISTENING_PORT|g" $CONFIG_FILE_PATH
		echo -e "done. \n"
		systemctl restart ssh
		systemctl status ssh
	fi
}

append_public_key() {
	if [ -n "$PUBLIC_KEY" ] && [ -d "/home/$AUTHORIZED_USER" ]; then
		cd /home/$AUTHORIZED_USER
		mkdir .ssh
		cd .ssh
		touch ./authorized_keys
		chown -R $AUTHORIZED_USER:$AUTHORIZED_USER /home/$AUTHORIZED_USER
		chmod 700 /home/$AUTHORIZED_USER/.ssh/
		chmod 600 /home/$AUTHORIZED_USER/.ssh/authorized_keys
		echo "$PUBLIC_KEY" >> /home/$AUTHORIZED_USER/.ssh/authorized_keys
	fi
}

main() {
	install_openssh_server
        change_sshd_settings
        append_public_key
	echo -e "now you can connect to your SSH service .\n"
	echo -e "with the following command:\n"
	ip_address=$(/sbin/ifconfig eth0 | grep inet | grep -v inet6 | tr -s ' ' | cut -d ' ' -f 3 | cut -d ':' -f 2)
        echo -e "ssh -p$SSHD_LISTENING_PORT -i <PATH_TO_YOUR_PRIVATE_KEY> $AUTHORIZED_USER@$ip_address \n"
	echo -e "\n"
	echo -e "you could also put this block below into /home/\$USER/.ssh/config of ssh client computer \n"
	echo -e " \n"
	echo -e "Host $HOSTNAME"
	echo -e "  HostName $ip_address"
	echo -e "  User $AUTHORIZED_USER"
	echo -e "  IdentitiesOnly yes"
	echo -e "  Port $SSHD_LISTENING_PORT"
	echo -e "  IdentityFile /path/to/your/private/key/.ssh/id_rsa"
	echo -e "  LocalForward 5900 127.0.0.1:5900"
	echo -e " \n"
	echo -e " \n"
	echo -e "then issue command 'ssh $HOSTNAME' for connecting to openssh server\n"
}

echo -e "This script will do the following tasks for you, including: \n"
echo -e "  1.install openssh-server on this computer \n"
echo -e "  2.change sshd service port from default 22 to custom $SSHD_LISTENING_PORT then restart sshd service \n"
echo -e "  3.append public key you specified in this script to /home/$AUTHORIZED_USER/.ssh/authorized_keys \n"
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

