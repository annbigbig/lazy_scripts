#!/bin/bash
######################## << Tested on Ubuntu Mate 24.04 Desktop Edition>> #####################
######################## << Tested on Ubuntu 24.04 Server Edition >> ##########################
#
# This script will install openssh-server on Ubuntu 24.04 LTS
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
# SFTP user list , username and password seperated by a space
SFTP_GROUP="sftpusers"
read -r -d '' USER_CREDENTIALS << EOV
internal.user P@55w0rd12345679
public.user P@55w0rd12345679
tony.stark P@55w0rd12345679
peter.parker P@55w0rd12345679
bruce.banner P@55w0rd12345679
stephen.strange P@55w0rd12345679
EOV
###############################################################################################
# Useful Links:
# https://www.golinuxcloud.com/sftp-chroot-restrict-user-specific-directory/
# https://www.freecodecamp.org/news/linux-how-to-add-users-and-create-users-with-useradd/
# https://www.systutorials.com/changing-linux-users-password-in-one-command-line/
###############################################################################################

say_goodbye() {
	echo "see you next time"
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
	SSH_SOCKET_FILE_PATH="/usr/lib/systemd/system/ssh.socket"
	BACKUP_CONFIG_FILE_PATH="/etc/ssh/sshd_config.default"
	INCLUDED_EXTRA_CONFIG_PATH="/etc/ssh/sshd_config.d/50-cloud-init.conf"
	if [ ! -f $BACKUP_CONFIG_FILE_PATH ]; then
		cp $CONFIG_FILE_PATH $BACKUP_CONFIG_FILE_PATH
	fi

        # prevent password logins
        sed -i -- 's|#PasswordAuthentication yes|PasswordAuthentication no|g' $CONFIG_FILE_PATH
        sed -i -- 's|PasswordAuthentication yes|PasswordAuthentication no|g' $INCLUDED_EXTRA_CONFIG_PATH
        sed -i -- 's|#PermitEmptyPasswords no|PermitEmptyPasswords no|g' $CONFIG_FILE_PATH

	# check dsa key existed or not , if not existed , delete all of the other keys and re-generate them
        if [ ! -s /etc/ssh/ssh_host_ecdsa_key -a ! -s /etc/ssh/ssh_host_ecdsa_key.pub ]; then
                rm -rf /etc/ssh/ssh_host_*
                ssh-keygen -A
                chown root:root /etc/ssh/ssh_host_*
                chmod 600 /etc/ssh/ssh_host_*
                chmod 644 /etc/ssh/ssh_host_ecdsa_*.pub
        fi

	# check /var/run/sshd existed or not, if not , create it , this is also a weird bug
        if [ ! -d /var/run/sshd ]; then
                mkdir -p -m0755 /var/run/sshd
                chown root:root /var/run/sshd
        fi

	# change ssh service port from default 22 to custom port you specify at top of the script
	if [ $SSHD_LISTENING_PORT -gt 1024 ] && [ $SSHD_LISTENING_PORT -lt 65535 ] ; then
		echo -e "modify $CONFIG_FILE_PATH \n replace 'Port 22' with 'Port $SSHD_LISTENING_PORT' \n"
		sed -i -- "s|#Port 22|Port 22|g" $CONFIG_FILE_PATH
		sed -i -- "s|Port 22|Port $SSHD_LISTENING_PORT|g" $CONFIG_FILE_PATH
		sed -i -- "s|ListenStream=22|ListenStream=$SSHD_LISTENING_PORT|g" $SSH_SOCKET_FILE_PATH
		echo -e "done. \n"
		systemctl daemon-reload
		systemctl restart ssh.service
		systemctl status ssh.service
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

create_sftp_users() {
	# create group for sftpusers
	groupadd $SFTP_GROUP
	
	# configure /etc/ssh/sshd_config
	SSHD_CONFIG="/etc/ssh/sshd_config"
		cat >> $SSHD_CONFIG << EOF

# sftp chroot jail settings for public.user
Match Group public.user
        ChrootDirectory /opt/sftp-jails
        X11Forwarding no
        AllowTcpForwarding no
        PermitTunnel no
        AllowAgentForwarding no
        ForceCommand internal-sftp

# sftp chroot jail settings for sftp group
Match Group $SFTP_GROUP
        ChrootDirectory /opt/sftp-jails
        X11Forwarding no
        AllowTcpForwarding no
        PermitTunnel no
        AllowAgentForwarding no
        ForceCommand internal-sftp
EOF
	# create sftp users
        while read -r line; do
                _USERNAME="$(/bin/echo $line | cut -d ' ' -f 1)"
                _PASSWORD="$(/bin/echo $line | cut -d ' ' -f 2)"
		useradd -m -s /bin/false $_USERNAME
		echo -e "$_PASSWORD\n$_PASSWORD" | passwd $_USERNAME
		[ $_USERNAME != "public.user" ] && usermod -g $SFTP_GROUP $_USERNAME || echo "do nothing , dont let public.user add to $SFTP_GROUP"
		sudo mkdir -p /opt/sftp-jails/$_USERNAME
		if [ $_USERNAME == "internal.user" ] || [ $_USERNAME == "public.user" ] ; then
			sudo chown $_USERNAME:$SFTP_GROUP /opt/sftp-jails/$_USERNAME
			sudo chmod 770 /opt/sftp-jails/$_USERNAME
		else
		       	sudo chown $_USERNAME:root /opt/sftp-jails/$_USERNAME
			sudo chmod 700 /opt/sftp-jails/$_USERNAME 
		fi
        done <<< "$USER_CREDENTIALS"

	# restart ssh service
	systemctl restart ssh
	systemctl status ssh
}

clear_public_dir_everyday() {
	# clear everything in dir /opt/sftp-jails/public.user everyday
	CLEAR_SCRIPT_CRON_FILE="/etc/cron.daily/clear_public_dir.sh"
	cat > $CLEAR_SCRIPT_CRON_FILE << EOF
#!/bin/sh
/usr/bin/rm -rf /opt/sftp-jails/public.user/*
EOF
	sudo chown root:root $CLEAR_SCRIPT_CRON_FILE
	sudo chmod 755 $CLEAR_SCRIPT_CRON_FILE
}	

main() {
	install_openssh_server
        change_sshd_settings
        append_public_key
	create_sftp_users
	clear_public_dir_everyday
	echo -e "now you can connect to your SSH service .\n"
	echo -e "with the following command:\n"
	WIRED_INTERFACE_NAME="$(ip link show | grep '2:' | cut -d ':' -f 2 | sed 's/^ *//g')"
	ip_address=$(/sbin/ifconfig $WIRED_INTERFACE_NAME | grep inet | grep -v inet6 | tr -s ' ' | cut -d ' ' -f 3 | cut -d ':' -f 2)
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
echo -e "  4.create sftpusers group and some sftp users\n"
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

