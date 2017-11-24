#!/bin/bash

#################

say_goodbye() {
        echo "goodbye everyone"
}


cross_compile_building() {
	apt-get update
	apt-get upgrade
	apt-get install -y ia32-libs
	apt-get install -y ncurses-dev
	apt-get install -y build-essential git u-boot-tools
	apt-get install -y install texinfo texlive ccache zlib1g-dev gawk bison flex gettext uuid-dev
	apt-get install -y uboot-mkimage
	apt-get install -y binutils-arm-linux-gnueabihf gcc-arm-linux-gnueabi
	apt-get install -y gcc-arm-linux-gnueabihf cpp-arm-linux-gnueabihf
	apt-get install -y libusb-1.0-0 libusb-1.0-0-dev
	apt-get install -y wget fakeroot kernel-package zlib1g-dev libncurses5-dev
}

fex2bin_bin2fex_tools_adding() {
	git clone https://github.com/cubieboard/sunxi-tools
	cd sunxi-tools
	make
	cp fex2bin bin2fex /usr/bin
}

get_source_code() {
	cd ~
	mkdir linux-sdk-card
	cd linux-sdk-card
	git clone https://github.com/cubieboard/linux-sdk-kernel-source.git
	mv linux-sdk-kernel-source linux-sunxi
	git clone https://github.com/cubieboard/linux-sdk-card-tools.git
	mv linux-sdk-card-tools tools
	git clone https://github.com/cubieboard/linux-sdk-card-products.git
	mv linux-sdk-card-products products
	git clone https://github.com/cubieboard/linux-sdk-binaries.git
	mv linux-sdk-binaries binaries
	cd binaries
	wget http://dl.cubieboard.org/model/commom/linux-sdk-binaries/u-boot-a10.tar.gz
	wget http://dl.cubieboard.org/model/commom/linux-sdk-binaries/u-boot-a20.tar.gz
	tar -zxvf ./u-boot-a10.tar.gz
	tar -zxvf ./u-boot-a20.tar.gz
	wget http://dl.cubieboard.org/model/commom/linux-sdk-binaries/cubieez-lxde-20140916.tar.gz
	wget http://dl.cubieboard.org/model/commom/linux-sdk-binaries/debian-server-v1.2.tar.gz
	wget http://dl.cubieboard.org/model/commom/linux-sdk-binaries/linaro-desktop-trusty-14.04-no-mesa-egl-Cubieaio-V1.1.tar.gz
	wget http://dl.cubieboard.org/model/commom/linux-sdk-binaries/linaro-trusty-server-14.04-v1.0.tar.gz
	cd ~
	cd linux-sdk-card
	source tools/scripts/envsetup.sh
}

main() {
	echo "main() was called"
	cross_compile_building
	fex2bin_bin2fex_tools_adding
	get_source_code
}

echo -e "This script will cubieboard 3 sd-card image for you"
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
