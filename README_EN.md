# Lazy Script

[繁體中文](README.md) | [简体中文](README_CN.md) | [English](README_EN.md)  

This project is a collection of many Shell Script files. Shell Script is also known as Shell script/command script, which can be used to install/configure network services (or any other host management work) on Linux hosts. Each Shell Script It has its own tasks. Due to the ordinary daily work of host managers, it is probably: command 1 Enter command 2 Enter command 3 Enter ..... command N Enter, so simple and boring, and Shell Script can be understood as, I Write all the instructions to be executed in this script at one time. Assuming that there are 800 instructions in the script, then executing this script once can run all the 800 instructions needed to complete the task. In addition to the convenience of the system administrator In addition to operation, it can also be fool-proof. After a long time, open a certain Shell Script and look at the commands inside, and you can immediately recall how the service was installed and configured. In addition to convenience, it is also fool-proof Function is actually a must-have skill for system administrators. Even if a technical singularity like Docker is born in the future, Shell Script is still necessary because it is easy to learn. Note that all Shell Script scripts here are Written specifically for Ubuntu 22.04, whether it is the Server version or the Desktop version.


### Files in Directory

```bash
├───@
├───_
├───images
├───README.md
├───README_CN.md
├───README_EN.md
├───U00-optimize_ubuntu.sh
├───U10-install_openssh_server.sh
├───U20-install_memcached_server.sh
├───U30-install_mariadb_server.sh
├───U35_install_mysql_server.sh
├───U40-install_tomcat.sh
├───U50-install_nginx_with_php_support.sh
├───U60-install_primary_dns_server.sh
├───U61-install_secondary_dns_server.sh
├───U70-install_modoboa_mail_server.sh
├───U80-install_netdata.sh
├───U81-install_snort.sh
├───U91-openvpn_ca_operations.sh
├───U92-openvpn_server_operations.sh
├───U93-openvpn_client_operations.sh
├───U94-ikev2vpn_server_operations.sh
├───U95-ikev2vpn_client_operations.sh

```

Only files like UXX-xxxxxxxx_xxxxxxx.sh are. Every Shell Script has its main task. I roughly follow the following principles for file naming:
Take the file U00-optimize_ubuntu.sh as an example. The beginning of U means that it is for Ubuntu, 00 means that its execution priority is prior to other shell scripts, and optimize_ubuntu means what its main task is. The following is a brief description again The task of each Shell Script:
| File name | Main task | Priority level (the smaller the number, the higher priority) | Necessity |
|--------|---------------|-------|-------|
|  U00-optimize_ubuntu.sh | Optimize the newly installed Ubuntu system, such as updating/installing necessary software/adjusting time zone/firewall settings/downgrading GCC compiler...  | 0 | yes |
|  U10-install_openssh_server.sh | Install/configure SSH service , SFTP chroot jail | 10 | yes |
|  U20-install_memcached_server.sh | Install/configure Memcached service  | 20 | no (optional) |
|  U30-install_mariadb_server.sh | Install/configure Mariadb service (single node or Galera Cluster)  | 30 | no (optional) |
|  U35_install_mysql_server.sh | Install/configure MySQL service (single node or Galera Cluster)  | 35 | no (optional) |
|  U40-install_tomcat.sh | Install/configure Tomcat service, JDK will be installed before  | 40 | no (optional) |
|  U50-install_nginx_with_php_support.sh | Install/configure Nginx+PHPFPM service  | 50 | no (optional) |
|  U60-install_primary_dns_server.sh | Install the DNS service and configure it as DNS Master  | 60 | no (optional) |
|  U61-install_secondary_dns_server.sh | Install DNS service and configure it as DNS Slave  | 61 | no (optional) |
|  U70-install_modoboa_mail_server.sh | Install Modoboa (Mail Server) | 70 | no (optional) |
|  U80-install_netdata.sh | Install/configure Netdata service  | 80 | no (optional) |
|  U81-install_snort.sh | Install/Configure Snort3 (Intrusion Detection Software) | 81 | no (optional) |
|  U91-openvpn_ca_operations.sh | Install/Configure OpenVPN Certificate Authority | 91 | no (optional) |
|  U92-openvpn_server_operations.sh | Install/Configure OpenVPN Server | 92 | no (optional) |
|  U93-openvpn_client_operations.sh | Install/configure OpenVPN Client | 93 | no (optional) |
|  U94-ikev2vpn_server_operations.sh | Install/Configure IKEv2 VPN Server | 94 | no (optional) |
|  U95-ikev2vpn_client_operations.sh | Install/Configure IKEv2 VPN Client | 95 | no (optional) |

## Running Guide
How to get the Shell Script here to work? Only two steps<br>
1.Set parameters <br>
2.Execute with root privileges<br>
At the top of each shell script, there are some parameters to be set, because your network environment, host name and other things will not be the same as mine<br>
Take U00-optimize_ubuntu.sh as an example, I use the vi editor to open the script:
```bash
$ vi U00-optimize_ubuntu.sh
```

### Script parameter setting

```bash
#!/bin/bash
# This script will perform lots of work for optimizing Ubuntu 22.04 LTS you've just installed
# before you run this script , please specify some parameters here ;
# these parameters will be used in firewall rules or system settings :
# 
########################################################################################################
OS_TYPE="Server"                        # only two values could work well 'Desktop' or 'Server'
LAN="192.168.251.0/24"                  # The local network that you allow packets come in from there
OPENVPN_NETWORK="10.8.0.0/24"           # The OpenVPN network that you allow packets come in from there
IKEV2VPN_NETWORK="10.10.10.0/24"        # The IKEv2VPN network that you allow packets come in from there
MY_TIMEZONE="Asia/Taipei"               # The timezone that you specify for this VPS node
ADD_SWAP="yes"                          # Do u need swap space ? fill in 'yes' or 'YES' will add swap for u
YOUR_VNC_PASSWORD="vnc"                 # set your vnc password here
IP_PROTOCOL="dhcp"                      # possible values ('dhcp' or 'staic') ; how do u get ipv4 address?
ADDRESS="192.168.251.91"                # fill in ipv4 address (such as 192.168.251.96) if u use static ip
NETMASK="255.255.255.0"                 # fill in ipv4 netmask (such as 255.255.255.0) if u use static ip
GATEWAY="192.168.251.1"                 # fill in ipv4 gateway (such as 192.168.251.1) if u use static ip
```
This is the top of U00-optimize_ubuntu.sh, where you need to set the parameters. Before you execute this script, please set these parameters first. The meaning of the parameters is briefly introduced after the value, which should be easy to understand , LAN should be set to your intranet segment, such as 172.28.117.0/24, if you don’t need additional SWAP space, ADD_SWAP can be set to no, if IP_PROTOCOL is set to dhcp, then ADDRESS / NETMASK / GATEWAY You can ignore it (or directly give an empty string), after confirming that each parameter is correct, press :wq to save and leave the vi text editor

### Execute the script with root privileges
Execute the script as a user of the sudoer group
```bash
$ sudo ./U00-optimize_ubuntu.sh
```
Or directly switch to the root user, the prompt will change from $ to #, and then execute it directly<br>
```bash
# ./U00-optimize_ubuntu.sh
```
Then it will start working for you : ) <br>

[Tip:] Don't forget that U00-optimize_ubuntu.sh should have execution permission on the Linux host,<br>
If not, you can add execution permission to it with the following command
```bash
$ sudo chmod +x ./U00-optimize_ubuntu.sh
```
## System architecture diagram
You can use the script here to complete such a system architecture<br>
The picture shows only 2 nodes, but it can be expanded according to your needs
![Network Topology Diagram](images/system_architecture_0.jpg?raw=true  'horizontal scaling')

## VPN deployment diagram
Two VPN implementations are provided here, OpenVPN and IKEv2 VPN<br>
After the VPN connection is successful, except the Public IP will change<br>
The VPN Client can access the devices on the VPN Server intranet
![VPN deployment](images/000_VPN_deployment.jpg?raw=true  'VPN deployment')

## Disclaimer 
<font size=4 color=888888>No matter what happened, I didn't do it, I don't know anything ∠( ᐛ 」∠)＿ </font>

## Contact me
<span style="color:#00FF00">Don't ask me to go to work, don't write to me, I'm very busy, maybe I'm busy delivering food, or picking up recyclables for money (๑•́ ₃ •̀๑)< /span>
annbigbig@gmail.com<br>
But I probably won't get back to you 'cause I'm too busy picking garbages to survive

## Donate to sponsor me
<font size=4>Your practical encouragement is the driving force behind my continuous cultivation, thank you very much, I am really short of money, and I look forward to going further after solving the money problem</font>

   - [國泰世華銀行收款帳號](#CathayBank) **<span style="color:#0000FF">銀行代碼 013 帳號 001-50-235346-9 戶名 KUN AN HSU 館前分行</span>**  <br><br>
   - [Alipay(支付寶)](#alipay) **<span style="color:#0000FF">annbigbig@gmail.com</span>**  <br><br>
   - [BitCoin](#Bitcoin)  ![BitcoinIcon](images/Bitcoin.png?raw=true "Thank you")  
      **<span style="color:#0000FF">1FGEtWkZpo3WHzQqDw6aJvsaDyxNmX4H9</span>** <br><br>
   - [Ethereum (or ERC20 tokens)](#Ethereum)  ![EthereeumIcon](images/Ethereum.png?raw=true "Thank you")  
      **<span style="color:#0000FF">0x4150D09d9E72F97dD0BEe15c76EB8e58bAC69830</span>** <br><br>
  - [BEP20 Tokens](#BEP20)  ![BEP20](images/BEP20.png?raw=true "Thank you")  
      **<span style="color:#0000FF">0x4150D09d9E72F97dD0BEe15c76EB8e58bAC69830</span>**
