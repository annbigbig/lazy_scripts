#!/bin/sh
# this script will help you make a bootable SD card for your Raspberry Pi 2
# before excute it, please fill in the correct device name of your SD card here.
SDCARD=/dev/sdb
# WARNING!!! if you specify a wrong device, that maybe cause an unexpected result
# (writing image file to wrong device or even destroy all of the data on your hard-disk)
# HINT: you can run command 'sudo df -h' before and after plugging SD card into computer
# to know what your device name of SD card extractly is.

###
calculate_last_sector(){
	OFFSET=1
	TOTAL_SECTORS=$(parted -s $SDCARD unit s print | grep $SDCARD | sed -r 's/^[^0-9]*([0-9]+).*/\1/')
	return $(($TOTAL_SECTORS - $OFFSET))
}

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
	mount ${SDCARD}1 /mnt/boot && cd /mnt/boot
	sed -i -- "s|#hdmi_mode=1|hdmi_mode=16|g" ./config.txt
	sync
	cd /mnt
	umount /mnt/boot && sleep 1
	echo "done. VGA resolution changed to 1024X768 60Hz"

	echo "ready to resize 2nd partition, expend it to the maximum sector.\n"
	echo "list the partition table first.\n"
	parted -s $SDCARD unit s print
	echo "done.\n"

	echo "delete 2nd partition on SD card.\n"
	parted -s $SDCARD rm 2
	echo "done.\n"

	echo "re-create 2nd partition, use the maximum size until the end of this SD card\n"
	echo "your last sector number on SD card is $LAST_SECTOR \n"
	parted -s $SDCARD unit s mkpart primary ext4 133120 $LAST_SECTOR
	echo "done.\n"

	echo "check 2nd partition.\n"
	e2fsck -f ${SDCARD}2
	echo "done.\n"

	echo "resize it.\n"
	resize2fs ${SDCARD}2
	echo "done.\n"

	echo "list the partition table again.\n"
        parted -s $SDCARD unit s print
        echo "done.\n"

	sync
	echo "now you can boot your Raspberry Pi 2 with this SD card."
}

say_goodbye (){
	echo "goodbye everyone"
}

main(){
	calculate_last_sector
	LAST_SECTOR=$?
	flash_it
}

echo "You are going to write Raspberry Pi 2 image file into device $SDCARD \n"
read -p "Are you sure (y/n)?" sure
case $sure in
	[Yy]* )
		main;
		break;;
	[Nn]* ) 
		say_goodbye;
		exit 1;;
	* ) echo "Please answer yes or no."
esac

