# Lazy scripts
These scripts are aimed to reduce the complexity of your daily adminstration works on Raspberry Pi 2.

it can perform these tasks for you , including :

-01_make_a_bootable_sd_card.sh
```text
Download Ubuntu 15.10 image for your Raspberry Pi 2 
then flash the image into micro-SD card
set the default VGA resolution to 1024X768 60Hz
finally it will resize your 2nd partition to the maximum size of your micro-SD
after running this script, you will get a bootable micro-SD card for your Raspberry Pi 2.
```
-02_network_settings.sh
```text
This script will do the following tasks for your Raspberry Pi 2
1.Fix network interfaces name (To conventional 'eth0' and 'wlan0')
2.Turn on tlp power save (Set TLP_ENABLE=1 in /etc/default/tlp) 
3.Firewall rule setting (Write firewall rules in /etc/network/if-up.d/firewall)
```

I am not an expert so If you found any issue
contact me : annbigbig@gmail.com
or make a pull request , have fun :)

## Licence: GNU GPL v3
