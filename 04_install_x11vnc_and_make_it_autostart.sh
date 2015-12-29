#!/bin/bash
# This script will install x11vnc and make it autostart as system service
# please specify your vnc password here
YOUR_VNC_PASSWORD=vnc
#####################

say_goodbye (){
	echo "goodbye everyone"
}

install_x11vnc(){
  if [ -z "$(dpkg --get-selections | grep x11vnc)" ]; then
      echo -e "ready to install x11vnc ... \n"
      apt-get install -y x11vnc
      echo -e "done. \n"
      echo -e "Please set your password for your x11vnc service: \n"
      x11vnc –storepasswd $YOUR_VNC_PASSWORD /etc/x11vnc.pass
      touch /lib/systemd/system/x11vnc.service
      cat >> /lib/systemd/system/x11vnc.service << EOF
[Unit]
Description=Start x11vnc at startup.
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -auth guess -forever -loop -noxdamage -repeat -rfbauth /etc/x11vnc.pass -rfbport 5900 -shared

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
	echo -e "now you can connect to your x11vnc service on raspberry pi 2.\n"
	echo -e "HINT: you can use VNC client tool such as Vinagre\n"
	echo -e "if your IPv4 address of the raspberry pi 2 is 10.1.1.172, then you should coneect to 10.1.1.172:5900"
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

