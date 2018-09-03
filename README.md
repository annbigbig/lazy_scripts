# Lazy Scripts
these shell scripts will help you setup and configure LEMP stack && Tomcat on Ubuntu 18.04 with less painful, after executing all of the shell scripts provided here, you will have a ready-to-use PHP/JavaEE deployment environment for your webapps.

## How to use it?
clone this repo and make all of them executable
```
git clone https://github.com/annbigbig/lazy_scripts
cd lazy_scripts
chmod +x ./*.sh
```
open the script you wanna execute later with your favorite text editor
```
vim 00-optimize_ubuntu
```
modify the parameters on top of shell script to suite your needs <br />
each script has their own specific parameters that have to be configure before use, <br />
change these to your own parameter values then save file and exit text editor
```
LAN="172.28.117.0/24" # The local network that you allow packets come in from there  
VPN="10.8.0.0/24" # The VPN network that you allow packets come in from there
```
then just call their names (with root privilege), the shell script been called will begin to work :-)
```
./00-optimize_ubuntu.sh
```
## System Architecture Diagram
basically i extect a horizontal scalable architecture,  
so my deployment environment would look like this :  
(you could add more vps nodes to suite future demands)

![Network Topology Diagram](images/system_architecture_0.jpg?raw=true "Title")

## Server types in network and their corresponding shell scripts
* **regular node in cluster**
    - [optimize ubuntu](00-optimize_ubuntu.sh)
    - [install openssh server](10-install_openssh_server.sh)
    - [install memcached server](20-install_memcached_server.sh)
    - [install mariadb galera cluster](30-install_mariadb_server.sh)
    - [install tomcat servlet container](40-install_tomcat.sh)
    - [install nginx with php7 support](50-install_nginx_with_php_support.sh)
    - [install nagios nrpe](71-install_nagios_nrpe.sh)
* **primary dns server**
    - [optimize ubuntu](00-optimize_ubuntu.sh)
    - [install openssh server](10-install_openssh_server.sh)
    - [install primary dns server](60-install_primary_dns_server.sh)
* **secondary dns server**
    - [optimize ubuntu](00-optimize_ubuntu.sh)
    - [install openssh server](10-install_openssh_server.sh)
    - [install secondary dns server](61-install_secondary_dns_server.sh)
* **nagios monitoring server**
    - [optimize ubuntu](00-optimize_ubuntu.sh)
    - [install openssh server](10-install_openssh_server.sh)
    - [install nagios server](70-install_nagios_server.sh)

## More questions you might insterested in
here are some search results that might be helpful
* [where to buy domain name](https://www.google.com.tw/search?q=where+to+buy+domain+name)
* [best vps providers](https://www.google.com.tw/search?q=best+vps+providers)
* [how to set NS record for my domain](https://www.google.com.tw/search?q=how+to+set+ns+record+for+my+domain)
* [where to buy cheap SSL certificate](https://www.google.com.tw/search?q=where+to+buy+cheap+ssl+certificate)
* [where to find free SSL certificate](https://www.google.com.tw/search?q=where+to+find+free+ssl+certificate)

and my domain (dq5rocks.com) was bought at GoDaddy,  
vps nodes were rent at Vultr, i have a wordpress blog running at  
 https://www.dq5rocks.com/wordpress/  
but that's my personal choice, you could buy domain/vps from other providers you preferred.

## Disclaimer Clause
i don't guarantee these shell scripts would work properly as you expected,  
review the code and set the proper parameters on top of the shell scripts
carefully,  
every single node in cluster should have their own specific configuration,  
and sometimes these shell scripts may fail due to network connectivity  
or just the software package tar balls were updated to newer version  
and old ones were removed from URL links i wrote,  
you should know the risk and i have no resposibilities for that.

## Contact me
my E-mail address : [annbigbig@gmail.com](mailto:annbigbig@gmail.com)  
and my preferred language is Traditional Chinese (繁體中文),  
i could use English either but with very limited-skills.

## Donate to me
if these shell scripts actually help you a lot, you could buy me a beer :-D

   - [Alipay(支付寶)](#alipay) annbigbig@gmail.com  
   - [BitCoin](#bitcoin)  ![BitcoinIcon](images/bitcoindonate.png?raw=true "Thank you") 1FGEtWkZpo3WHzQqDw6aJvsaDyxNmX4H9  
   - [Dogecoin](#dogecoin) ![DogecoinIcon](images/doge.png?raw=true "Thank you")
   DJEZGrRP9BY6nnJJuFXoPFXzQdJZMe6n5d  

## Hire me
if u don't care my very limited poor English skill  
and u believe i could do system admin works very well  
u could hire me
i wish i deserve 350 NTD dollars per hour  
and i expect receive payment after every daily work  
basically a regular vps node i drawn at previous picture will need 2 hours for it could be setup/configure properly

如果你不在意我的拙劣英文技巧  
而且你覺得我可以勝任系統管理工作  
歡迎你雇用我  
我希望我值得時薪350新台幣  
而且我喜歡薪水每日結算  
基本上我畫在上面的每個常規vps節點  
會需要兩個小時的時間來完成設定/配置
