#!/bin/bash
# This script will modify sshd settings on Ubuntu 15.10
# it will change sshd port number from default 22 to the number you specified here (range could be: 1024 to 65535)
SSHD_LISTENING_PORT="36000"
# and append the public key you specify here
PUBLIC_KEY_PATH="/tmp/public.key"
# to /home/$AUTHORIZED_USER/.ssh/authorzied_keys
AUTHORIZED_USER="labasky"
# NOTE: you have to copy public.key from your client computer to raspberry pi 2 first
# HINT: scp /path/to/your/public.key username@your.raspberrypi2.ipv4.address:/tmp
#####################

say_goodbye (){
	echo "goodbye everyone"
}

append_public_key(){
  if [ -f $PUBLIC_KEY_PATH ] && [ ! -z $AUTHORIZED_USER ]; then
     cd /home/$AUTHORIZED_USER
     mkdir .ssh
     cd .ssh
     touch ./authorized_keys
     chown -R $AUTHORIZED_USER:$AUTHORIZED_USER /home/$AUTHORIZED_USER
     chmod 700 /home/$AUTHORIZED_USER/.ssh/
     chmod 600 /home/$AUTHORIZED_USER/.ssh/authorized_keys
     cat $PUBLIC_KEY_PATH >> /home/$AUTHORIZED_USER/.ssh/authorized_keys
  fi
}

change_sshd_settings(){
  CONFIG_FILE_PATH=/etc/ssh/sshd_config
  BACKUP_CONFIG_FILE_PATH=/etc/ssh/sshd_config.default
  if [ ! -f $BACKUP_CONFIG_FILE_PATH ]; then
     cp $CONFIG_FILE_PATH $BACKUP_CONFIG_FILE_PATH
     echo -e "modify $CONFIG_FILE_PATH \n replace 'Port 22' with 'Port $SSHD_LISTENING_PORT' \n"
     sed -i -- "s|Port 22|Port $SSHD_LISTENING_PORT|g" $CONFIG_FILE_PATH
     echo -e "done. \n"
     systemctl restart ssh
     systemctl status ssh
  fi
}

main(){
        append_public_key
        change_sshd_settings
	echo -e "now you can connect to your SSH service on raspberry pi 2.\n"
	echo -e "with the following command:\n"
        echo -e "ssh -p$SSHD_LISTENING_PORT -i PATH_TO_YOUR_PRIVATE_KEY $AUTHORIZED_USER@your.raspberrypi2.ipv4.address \n"
}

echo -e "This script will do the following tasks for you, including:"
echo -e "  1.append public key that located at $PUBLIC_KEY_PATH to /home/$AUTHORIZED_USER/.ssh/authorized_keys"
echo -e "  2.change sshd tcp port number from 22 (default) to $SSHD_LISTENING_PORT (custom) \n"
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

