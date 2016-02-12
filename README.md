# Lazy scripts
These scripts are aimed to reduce the complexity of your daily adminstration works on Raspberry Pi 2.

it can perform these tasks for you , including :

01_make_a_bootable_sd_card.sh
```text
Download Ubuntu 15.10 image for your Raspberry Pi 2 
then flash the image into micro-SD card
set the default display resolution to 1080p 60Hz
finally it will resize your 2nd partition to the maximum size of your micro-SD
after running this script, you will get a bootable micro-SD card for your Raspberry Pi 2.
```
02_miscellaneous.sh
```text
This script will do the following tasks for your Raspberry Pi 2
1.Fix network interfaces name (To conventional 'eth0' and 'wlan0')
2.Turn on tlp power save (Set TLP_ENABLE=1 in /etc/default/tlp) 
3.Firewall rule setting (Write firewall rules in /etc/network/if-up.d/firewall)
4.delete route to 169.254.0.0
5.add swap space with 512MB
6.install softwares you need
```
03_modify_sshd_settings.sh
```text
change the sshd service port number from 22(default) to whatever you preferred
then add a public key that located at /tmp/public.key
to /home/<USER_YOU_SPECIFIED>/.ssh/authorized_keys
```
04_install_x11vnc_and_make_it_autostart.sh
```text
install x11vnc and make it a permanate system service for you
(listening on 127.0.0.1:5900)
before run this script , you have to specify vnc password you preferred at top of the script for x11vnc service
```

I am not an expert so If you found any issue
contact me : annbigbig@gmail.com
or make a pull request , have fun :)

## Licence: GNU GPL v3
