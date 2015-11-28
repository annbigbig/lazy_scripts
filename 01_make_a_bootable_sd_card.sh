#!/bin/sh
# this script will help you make a bootable SD card for your Raspberry Pi 2
# before excute it, please fill in the correct device name of your SD card here.
SDCARD=/dev/sdb
# WARNING!!! if you specify a wrong device, that maybe cause an unexpected result
# (writing image file to wrong device or even destroy all of the data on your hard-disk)
# HINT: you can run command 'sudo df -h' before and after plugging SD card into computer
# to know what your device name of SD card extractly is.

flash_it (){
	echo "umount SD card\n"
	umount $SDCARD*
	echo "done.\n"

	#echo "checking SD card if any bad block exists on it ?\n"
	#badblocks -n -v $SDCARD
	#echo "done.\n"

	echo "download the image file\n"
	cd ~
	mkdir rasp2_image
	cd rasp2_image
	wget http://can.ubuntu-mate.net/raspberry-pi/ubuntu-mate-15.10-desktop-armhf-raspberry-pi-2.img.bz2
	echo "download completed.\n"

	echo "extracting image from bz2 file we just downloaded\n"
	bzip2 -d ./ubuntu-mate-15.10-desktop-armhf-raspberry-pi-2.img.bz2
	echo "done.\n"

	echo "flash image into SD card, start now ";date; echo "\n"
	dd if=ubuntu-mate-15.10-desktop-armhf-raspberry-pi-2.img of=$SDCARD bs=1M
	sync
	echo "done. completed at ";date; echo "\n"

	echo "change the VGA resolution to 1024X768 60Hz"
 	mkdir /mnt/boot
	mount ${SDCARD}1 /mnt/boot
	sleep 5
	cd /mnt/boot
	sed -i -- "s|#hdmi_mode=1|hdmi_mode=16|g" ./config.txt
	sync
	sleep 5
	cd /mnt
	umount /mnt/boot
	sleep 5
	echo "done. VGA resolution changed to 1024X768 60Hz"

	echo "now you can boot your Raspberry Pi 2 with this SD card."
}

say_goodbye (){
	echo "goodbye everyone"
}

echo "You are going to write Raspberry Pi 2 image file into device $SDCARD \n"
read -p "Are you sure (y/n)?" sure
case $sure in
	[Yy]* )
		flash_it;
		break;;
	[Nn]* ) 
		say_goodbye;
		exit 1;;
	* ) echo "Please answer yes or no."
esac

