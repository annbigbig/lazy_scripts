# Lazy Scripts
these shell scripts will help you setup and configure LEMP stack && Tomcat on Ubuntu 16.04 with less painful, after executing all of the shell scripts provided here, you will have a ready-to-use PHP/JavaEE deployment environment for your webapps.

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
## Network Topology Diagram
basically i extect a horizontal scalable architecture, so my deployment environment would look like this :

![Network Topology Diagram](images/network_topology_diagram_000.jpg?raw=true "Title")

## Server types in Subnet and their corresponding shell scripts
* **single node in cluster**
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

## Router's responsibilities
the concepts about how to configure a router were not covered in this README file, you could search google use titles listed below as keywords and u will gain lots of the results, the routers i drawn in previous diagram have to meet these requirement :

#### Reverse Proxy
a http request coming from Internet will be sent to WAN interface of router first, then it will be forwarded to one of the backend servers reside in private network behind the router, finally the client sending this request will get the its response content.

#### Establish a VPN tunnel between Lan1 and Lan2
Lan behind routerTPE and Lan behind routerTNN were connected together via a vpn tunnel, one router acts as vpn server and the other one acts as vpn client, the hosts inside seperate Lan can connect each other without any problem just like they were reside in the same Lan (hosts in 172.28.117.0/24 can connect to 172.17.205.0/24 and vise versa)

#### DNAT to host inside LAN (port forwarding)
there is a dns server host in each Lan so you have to mapping tcp/ndp port 53 on WAN to that dns server's private ip address.

## Disclaimer Clause
i don't guarantee these shell scripts would work properly as you expected, review the code and set the proper parameters on top of the shell scripts carefully, every single node in cluster should have their own specific configuration, and sometimes these shell scripts may fail due to network connectivity or just the software package tar balls were updated to newer version and old ones were removed from URL links i wrote, you should know the risk and i have no resposibilities for that.

## Contact me
my E-mail address : [annbigbig@gmail.com](mailto:annbigbig@gmail.com)
and my preferred language is Traditional Chinese (繁體中文),
i could use English either but with very limited-skills.

## Donate to me
if these shell scripts actually help you a lot, you could buy me a beer :-D

   - [Alipay(支付寶)](#alipay)  annbigbig@gmail.com
   - [BitCoin](#bitcoin)  ![BitcoinIcon](images/bitcoindonate.png?raw=true "Thank you") 1FGEtWkZpo3WHzQqDw6aJvsaDyxNmX4H9
   - [Dogecoin](#dogecoin) ![DogecoinIcon](images/doge.png?raw=true "Thank you")
   DJEZGrRP9BY6nnJJuFXoPFXzQdJZMe6n5d
