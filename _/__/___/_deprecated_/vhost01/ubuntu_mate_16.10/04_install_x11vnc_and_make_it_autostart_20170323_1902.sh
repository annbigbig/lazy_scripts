#!/bin/bash
# This script will install x11vnc and make it autostart as system service
# please specify your vnc password here
YOUR_VNC_PASSWORD="vnc"
#####################

say_goodbye (){
	echo "goodbye everyone"
}

install_x11vnc(){
  if [ -z "$(dpkg --get-selections | grep x11vnc)" ]; then
      echo -e "ready to install x11vnc ... \n"
      apt-get update
      apt-get install -y x11vnc
      echo -e "done. \n"
      x11vnc -storepasswd $YOUR_VNC_PASSWORD /etc/x11vnc.pass
      touch /lib/systemd/system/x11vnc.service
      cat >> /lib/systemd/system/x11vnc.service << EOF
[Unit]
Description=Start x11vnc at startup.
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -auth /var/run/lightdm/root/:0 -display :0 -forever -loop -noxdamage -repeat -rfbauth /etc/x11vnc.pass -listen localhost -allow 127.0.0.1,10.1.1.,192.168.0. -rfbport 5900 -shared -logfile /var/log/x11vnc.log -ncache 10 -nowf -nowcr -xrandr

[Install]
WantedBy=multi-user.target
EOF
      systemctl daemon-reload
      systemctl enable x11vnc.service
      systemctl start x11vnc.service
      systemctl status x11vnc.service
  fi
}

main(){
        install_x11vnc
	ip_address=$(/sbin/ifconfig eth0 | grep -A 1 'netmask' | head -1 | cut -d " " -f 10)
	echo -e "Note: Before connect to your x11vnc service with vnc client \n"
	echo -e "Please establish ssh tunnel to x11vnc server with the following command: \n"
	echo -e "ssh -p36000 -i </path/to/your/.ssh/id_rsa> labasky@$ip_address -L 5900:localhost:5900 \n"
	echo -e "alternatively you can add the following config section into your /home/<USER_NAME>/.ssh/config \n"
	echo -e "Host vhost01"
	echo -e "   HostName $ip_address"
	echo -e "   User labasky"
	echo -e "   IdentitiesOnly yes"
	echo -e "   Port 36000"
	echo -e "   IdentityFile /path/to/your/.ssh/id_rsa"
	echo -e "   LocalForward 5900 127.0.0.1:5900 \n"
	echo -e "then use this command for establishing ssh tunnel : \n"
	echo -e "ssh vhost01 \n"
	echo -e "then you can use VNC client tool such as Vinagre \n"
	echo -e "specify 127.0.0.1:5900 for connecting to your x11vnc service \n"
}

echo -e "This script will install x11vnc and make it as system service"
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

