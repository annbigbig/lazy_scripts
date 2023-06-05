# Lazy Script

[繁體中文](README.md) | [简体中文](README_CN.md) | [English](README_EN.md) 

这个专案是很多个Shell Script档案的集合，Shell Script又称Shell脚本/命令稿，可以用来在Linux主机上安装/配置网路服务 (或是其他任何的主机管理工作)，每一支Shell Script有它自已的任务，由于主机管理人员普通的工作日常，大概就是：指令1 Enter 指令2 Enter 指令3 Enter ..... 指令N Enter，如此朴实无华而枯燥，而Shell Script可以理解成，我一次性把所有要执行的指令，写在这个脚本里面，假设脚本里有800个指令，那么执行一次此脚本，就能把所有完成任务所需要的800个指令全都跑完，除了方便系统管理员操作之外，它还能防呆，日子久了之后，打开某一支Shell Script看看里面的指令，就能立刻回想起这个服务是怎么安装配置的，除了便利性，还兼具防呆的功用，实为系统管理员必备技能，即使日后有Docker这样的技术奇异点横空出世，Shell Script还是因为其简单易学，而有它继续存在的必要性，注意这里的所有Shell Script脚本都是专门为Ubuntu 22.04而写的，不管是Server版或是Desktop版.


### 目录里的档案

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

只有 UXX-xxxxxxxx_xxxxxxx.sh 这样的档案才是喔，每一个Shell Script有它的主要任务，档案的命名我大致遵循下列原则： 以U00-optimize_ubuntu.sh这支档案为例，U开头代表这是给Ubuntu使用的，00表示它的执行优先顺序要先于其他支Shell Script，optimize_ubuntu表示它的主线任务是什么，以下再次简述每一支Shell Script的任务：
|  檔名 | 主線任務  | 優先等級 (數字愈小愈優先) | 必要性 |
|--------|---------------|-------|-------|
|  U00-optimize_ubuntu.sh | 优化刚安装完成的Ubuntu系统，像是更新/安装必要软体/调整时区/防火墙设定/降级GCC编译器...  | 0 | 是 |
|  U10-install_openssh_server.sh | 安装/配置SSH服务，SFTP chroot jail 环境配置 | 10 | 是 |
|  U20-install_memcached_server.sh | 安装/配置Memcached服务 | 20 | 否(可选) |
|  U30-install_mariadb_server.sh | 安装/配置Mariadb服务（单一节点或是Galera Cluster) | 30 | 否(可选) |
|  U35_install_mysql_server.sh | 安装/配置MySQL服务（单一节点或是Galera Cluster) | 35 | 否(可选) |
|  U40-install_tomcat.sh |  安装/配置Tomcat服务，在此之前会先安装好JDK | 40 | 否(可选) |
|  U50-install_nginx_with_php_support.sh | 安装/配置Nginx+PHPFPM服务 | 50 | 否(可选) |
|  U60-install_primary_dns_server.sh | 安装DNS服务，配置为DNS Master | 60 | 否(可选) |
|  U61-install_secondary_dns_server.sh | 安装DNS服务，配置为DNS Slave | 61 | 否(可选) |
|  U70-install_modoboa_mail_server.sh | 安装Modoboa (MailServer) | 70 | 否(可选) |
|  U80-install_netdata.sh | 安装/配置Netdata服务  | 80 | 否(可选) |
|  U81-install_snort.sh | 安装/配置Snort3 (入侵检测软体) | 81 | 否(可选) |
|  U91-openvpn_ca_operations.sh | 安装/配置OpenVPN Certificate Authority | 91 | 否(可选) |
|  U92-openvpn_server_operations.sh | 安装/配置OpenVPN Server | 92 | 否(可选) |
|  U93-openvpn_client_operations.sh | 安装/配置OpenVPN Client | 93 | 否(可选) |
|  U94-ikev2vpn_server_operations.sh | 安装/配置IKEv2 VPN Server | 94 | 否(可选) |
|  U95-ikev2vpn_client_operations.sh | 安装/配置IKEv2 VPN Client | 95 | 否(可选) |

## Running Guide
如何让这里的Shell Script开始工作呢？只有两个步骤<br>
1.设定好参数 <br>
2.以root权限执行<br>
每一支Shell Script的最上方，有一些参数要设定，因为你的网路环境，主机名称之类的东西不会和我的一样<br>
以U00-optimize_ubuntu.sh这一支为例，我使用 vi 编辑器打开脚本：
```bash
$ vi U00-optimize_ubuntu.sh
```

### 脚本参数设定

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
这是U00-optimize_ubuntu.sh最上方，需要设定好参数的地方，在你执行此脚本之前，请一定先把这些参数设定好，参数的意义在其值的后面有简单的介绍，应该很好懂，LAN要设定成你的内网网段，例如172.28.117.0/24，如果你不需要额外新增SWAP空间，ADD_SWAP可以设定成no，如果IP_PROTOCOL设定成了dhcp，那后面的ADDRESS / NETMASK / GATEWAY可以不用管他 (或是直接给空字串也行)，确定每一个参数都是对的之后，按下:wq存档离开 vi 文字编辑器

### 以root权限执行脚本
以sudoer群组的用户，执行脚本
```bash
$ sudo ./U00-optimize_ubuntu.sh
```
或是直接切换成root用户，提示符会从$变成#，然后直接执行它<br>
```bash
# ./U00-optimize_ubuntu.sh
```
然后它就会开始为你工作了 : ) <br>

[提示:] 不要忘记U00-optimize_ubuntu.sh在Linux主机上应该是要有执行权限的，<br>
如果没有，可以用下面的指令为它加上执行权限
```bash
$ sudo chmod +x ./U00-optimize_ubuntu.sh
```
## 系统架构图
你可以用这里的脚本，来完成这样的系统架构<br>
图示是只有2个节点，但是可以依你的需求再扩充
![Network Topology Diagram](images/system_architecture_0.jpg?raw=true  'horizontal scaling')

## VPN部署示意图
这里提供两种VPN实作，OpenVPN和IKEv2 VPN<br>
VPN连接成功之后，除了Public IP会改变<br>
VPN Client可以存取到VPN Server内网的设备
![VPN deployment](images/000_VPN_deployment.jpg?raw=true  'VPN deployment')

## 免责条款
<font size=4 color=888888>不管发生什么事，都不是我干的，我什么都不知道  ∠( ᐛ 」∠)＿ </font>  

## Contact me  
<span style="color:#00FF00">没有要叫我去上班，不要写信给我，很忙，可能在忙着外送，或是捡资源回收物换钱 (๑•́ ₃ •̀๑)</span>  
annbigbig@gmail.com<br>
但是我可能不会回你，因为我忙着捡角求生存

## 求职
  
可以叫我去上班喔，很缺钱  
寄信到 : [annbigbig@gmail.com](mailto:annbigbig@gmail.com)  
<font size=4>
告诉我您是那家公司<br>
我会先看贵公司在104上面的简介<br>
合适的话我会把104的履历寄给您<br><br>
能力值大概是这样  
* 系维运维：🌕🌕🌕🌕🌑  
* Java/Spring 后端Restful API开发：🌕🌕🌗🌑🌑  
* 系统设计UML模型图导出：🌕🌕🌕🌗🌑   
* UI：🌕🌑🌑🌑🌑   
* 文件整理：🌕🌕🌕🌗🌑    
</font>

## 捐款赞助我
<font size=4>您的实质鼓励，是我持续耕耘的原动力，万分感谢，在下真的很缺钱，期待解决钱的问题之后，可以走得更远</font>  

   - [国泰世华银行收款帐号](#CathayBank) **<span style="color:#0000FF">银行代码 013 帐号 001-50-235346-9 户名 KUN AN HSU 馆前分行</span>**  <br><br>
   - [Alipay(支付宝)](#alipay) **<span style="color:#0000FF">annbigbig@gmail.com</span>**  <br><br>
   - [BitCoin](#Bitcoin)  ![BitcoinIcon](images/Bitcoin.png?raw=true "Thank you")  
      **<span style="color:#0000FF">1FGEtWkZpo3WHzQqDw6aJvsaDyxNmX4H9</span>** <br><br>
   - [Ethereum (或是ERC20代币)](#Ethereum)  ![EthereeumIcon](images/Ethereum.png?raw=true "Thank you")  
      **<span style="color:#0000FF">0x4150D09d9E72F97dD0BEe15c76EB8e58bAC69830</span>** <br><br>
  - [BEP20代币](#BEP20)  ![BEP20](images/BEP20.png?raw=true "Thank you")  
      **<span style="color:#0000FF">0x4150D09d9E72F97dD0BEe15c76EB8e58bAC69830</span>**
