#!/bin/sh
# this script will help you make a bootable SD card for your Raspberry Pi 2
# before excute it, please fill in the correct device name of your SD card here.
SDCARD=/dev/sdc
# WARNING!!! if you specify a wrong device, that maybe cause an unexpected result
# (writing image file to wrong device or even destroy all of the data on your hard-disk)
# HINT: you can run command 'sudo df -h' before and after plugging SD card into computer
# to know what your device name of SD card extractly is.

###
calculate_last_sector() {
	OFFSET=1
	TOTAL_SECTORS=$(parted -s $SDCARD unit s print | grep $SDCARD | sed -r 's/^[^0-9]*([0-9]+).*/\1/')
	return $(($TOTAL_SECTORS - $OFFSET))
}

flash_it() {
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
	wget http://can.ubuntu-mate.net/raspberry-pi/ubuntu-mate-16.04-desktop-armhf-raspberry-pi.img.xz
	echo "download completed.\n"

	echo "extracting image from xz file we just downloaded\n"
	unxz -d ./ubuntu-mate-16.04-desktop-armhf-raspberry-pi.img.xz
	echo "done.\n"

	echo "flash image into SD card, start now ";date; echo "\n"
	dd if=ubuntu-mate-16.04-desktop-armhf-raspberry-pi.img of=$SDCARD bs=1M
	sync
	echo "done. completed at ";date; echo "\n"

}

config_tunning() {

	echo "config tunning"
 	mkdir /mnt/boot
	mount ${SDCARD}1 /mnt/boot && cd /mnt/boot
	sed -i -- "s|#hdmi_drive=2|hdmi_drive=2|g" ./config.txt
	sed -i -- "s|#hdmi_group=1|hdmi_group=2|g" ./config.txt
	sed -i -- "s|#hdmi_mode=1|hdmi_mode=82|g" ./config.txt
	sed -i -- "s|#disable_overscan=1|disable_overscan=1|g" ./config.txt
	sed -i -- "s|#hdmi_ignore_edid_audio=1|hdmi_ignore_edid_audio=1|g" ./config.txt
	sed -i -- "s|#hdmi_force_hotplug=1|hdmi_force_hotplug=1|g" ./config.txt
	sync
	cd /mnt
	umount /mnt/boot && sleep 1
	echo "done. display resolution changed to 1080p 60Hz"
}

resize_2nd_partition() {

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
}

say_goodbye (){
	echo "goodbye everyone"
}

main(){
	calculate_last_sector
	LAST_SECTOR=$?
	echo -e "LAST_SECTOR of microSD card is $LAST_SECTOR \n"
	flash_it
	config_tunning
	resize_2nd_partition
	echo "now you can boot your Raspberry Pi 2 with this SD card."
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

