# Lazy Script

[繁體中文](README.md) | [简体中文](README_CN.md) | [English](README_EN.md) 

這個專案是很多個Shell Script檔案的集合，Shell Script又稱Shell腳本/命令稿，可以用來在Linux主機上安裝/配置網路服務 (或是其他任何的主機管理工作)，每一支Shell Script有它自已的任務，由於主機管理人員普通的工作日常，大概就是：指令1 Enter 指令2 Enter 指令3 Enter ..... 指令N Enter，如此樸實無華而枯燥，而Shell Script可以理解成，我一次性把所有要執行的指令，寫在這個腳本裡面，假設腳本裡有800個指令，那麼執行一次此腳本，就能把所有完成任務所需要的800個指令全都跑完，除了方便系統管理員操作之外，它還能防呆，日子久了之後，打開某一支Shell Script看看裡面的指令，就能立刻回想起這個服務是怎麼安裝配置的，除了便利性，還兼具防呆的功用，實為系統管理員必備技能，即使日後有Docker這樣的技術奇異點橫空出世，Shell Script還是因為其簡單易學，而有它繼續存在的必要性，注意這裡的所有Shell Script腳本都是專門為Ubuntu 24.04而寫的，不管是Server版或是Desktop版.


### 目錄裡的檔案

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

只有 UXX-xxxxxxxx_xxxxxxx.sh 這樣的檔案才是喔，每一個Shell Script有它的主要任務，檔案的命名我大致遵循下列原則：
以U00-optimize_ubuntu.sh這支檔案為例，U開頭代表這是給Ubuntu使用的，00表示它的執行優先順序要先於其他支Shell Script，optimize_ubuntu表示它的主線任務是什麼，以下再次簡述每一支Shell Script的任務：
|  檔名 | 主線任務  | 優先等級 (數字愈小愈優先) | 必要性 |
|--------|---------------|-------|-------|
|  U00-optimize_ubuntu.sh | 優化剛安裝完成的Ubuntu系統，像是更新/安裝必要軟體/調整時區/防火牆設定/降級GCC編譯器...  | 0 | 是 |
|  U10-install_openssh_server.sh | 安裝/配置SSH服務，SFTP chroot jail 環境配置  | 10 | 是 |
|  U20-install_memcached_server.sh | 安裝/配置Memcached服務  | 20 | 否(可選) |
|  U30-install_mariadb_server.sh | 安裝/配置Mariadb服務（單一節點或是Galera Cluster)  | 30 | 否(可選) |
|  U35_install_mysql_server.sh | 安裝/配置MySQL服務（單一節點或是Galera Cluster)  | 35 | 否(可選) |
|  U40-install_tomcat.sh | 安裝/配置Tomcat服務，在此之前會先安裝好JDK  | 40 | 否(可選) |
|  U50-install_nginx_with_php_support.sh | 安裝/配置Nginx+PHPFPM服務  | 50 | 否(可選) |
|  U60-install_primary_dns_server.sh | 安裝DNS服務，配置為DNS Master  | 60 | 否(可選) |
|  U61-install_secondary_dns_server.sh | 安裝DNS服務，配置為DNS Slave  | 61 | 否(可選) |
|  U70-install_modoboa_mail_server.sh | 安裝Modoboa (MailServer)  | 70 | 否(可選) |
|  U80-install_netdata.sh | 安裝/配置Netdata服務  | 80 | 否(可選) |
|  U81-install_snort.sh | 安裝/配置Snort3 (入侵檢測軟體)  | 81 | 否(可選) |
|  U91-openvpn_ca_operations.sh | 安裝/配置OpenVPN Certificate Authority  | 91 | 否(可選) |
|  U92-openvpn_server_operations.sh | 安裝/配置OpenVPN Server  | 92 | 否(可選) |
|  U93-openvpn_client_operations.sh | 安裝/配置OpenVPN Client  | 93 | 否(可選) |
|  U94-ikev2vpn_server_operations.sh | 安裝/配置IKEv2 VPN Server  | 94 | 否(可選) |
|  U95-ikev2vpn_client_operations.sh | 安裝/配置IKEv2 VPN Client  | 95 | 否(可選) |

## Running Guide
如何讓這裡的Shell Script開始工作呢？只有兩個步驟<br>
1.設定好參數 <br>
2.以root權限執行<br>
每一支Shell Script的最上方，有一些參數要設定，因為你的網路環境，主機名稱之類的東西不會和我的一樣<br>
以U00-optimize_ubuntu.sh這一支為例，我使用 vi 編輯器打開腳本：
```bash
$ vi U00-optimize_ubuntu.sh
```

### 腳本參數設定

```bash
#!/bin/bash
# This script will perform lots of work for optimizing Ubuntu 24.04 LTS you've just installed
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
這是U00-optimize_ubuntu.sh最上方，需要設定好參數的地方，在你執行此腳本之前，請一定先把這些參數設定好，參數的意義在其值的後面有簡單的介紹，應該很好懂，LAN要設定成你的內網網段，例如172.28.117.0/24，如果你不需要額外新增SWAP空間，ADD_SWAP可以設定成no，如果IP_PROTOCOL設定成了dhcp，那後面的ADDRESS / NETMASK / GATEWAY可以不用管他 (或是直接給空字串也行)，確定每一個參數都是對的之後，按下:wq存檔離開 vi 文字編輯器

### 以root權限執行腳本
以sudoer群組的用戶，執行腳本
```bash
$ sudo ./U00-optimize_ubuntu.sh
```
或是直接切換成root用戶，提示符會從$變成#，然後直接執行它<br>
```bash
# ./U00-optimize_ubuntu.sh
```
然後它就會開始為你工作了 : ) <br>

[提示:] 不要忘記U00-optimize_ubuntu.sh在Linux主機上應該是要有執行權限的，<br>
如果沒有，可以用下面的指令為它加上執行權限
```bash
$ sudo chmod +x ./U00-optimize_ubuntu.sh
```
## 系統架構圖
你可以用這裡的腳本，來完成這樣的系統架構<br>
圖示是只有2個節點，但是可以依你的需求再擴充
![Network Topology Diagram](images/system_architecture_0.jpg?raw=true  'horizontal scaling')

## VPN部署示意圖
這裡提供兩種VPN實作，OpenVPN和IKEv2 VPN<br>
VPN連接成功之後，除了Public IP會改變<br>
VPN Client可以存取到VPN Server內網的設備
![VPN deployment](images/000_VPN_deployment.jpg?raw=true  'VPN deployment')

## 免責條款 
<font size=4 color=888888>不管發生什麼事，都不是我幹的，我什麼都不知道  ∠( ᐛ 」∠)＿ </font>  

## Contact me  
<span style="color:#00FF00">沒有要叫我去上班，不要寫信給我，很忙，可能在忙著外送，或是撿資源回收物換錢 (๑•́ ₃ •̀๑)</span>  
annbigbig@gmail.com<br>
但是我可能不會回你，因為我忙著撿角求生存

## 求職
  
可以叫我去上班喔，很缺錢  
寄信到 : [annbigbig@gmail.com](mailto:annbigbig@gmail.com)  
<font size=4>
告訴我您是那家公司<br>
我會先看貴公司在104上面的簡介<br>
合適的話我會把104的履歷寄給您<br><br>
能力值大概是這樣  
* 系維運維：🌕🌕🌕🌕🌑  
* Java/Spring 後端Restful API開發：🌕🌕🌗🌑🌑  
* 系統設計UML模型圖導出：🌕🌕🌕🌗🌑   
* UI：🌕🌑🌑🌑🌑   
* 文件整理：🌕🌕🌕🌗🌑    
</font>

## 捐款贊助我
<font size=4>您的實質鼓勵，是我持續耕耘的原動力，萬分感謝，在下真的很缺錢，期待解決錢的問題之後，可以走得更遠</font>  

   - [國泰世華銀行收款帳號](#CathayBank) **<span style="color:#0000FF">銀行代碼 013 帳號 001-50-235346-9 戶名 KUN AN HSU 館前分行</span>**  <br><br>
   - [Alipay(支付寶)](#alipay) **<span style="color:#0000FF">annbigbig@gmail.com</span>**  <br><br>
   - [BitCoin](#Bitcoin)  ![BitcoinIcon](images/Bitcoin.png?raw=true "Thank you")  
      **<span style="color:#0000FF">1FGEtWkZpo3WHzQqDw6aJvsaDyxNmX4H9</span>** <br><br>
   - [Ethereum (或是ERC20代幣)](#Ethereum)  ![EthereeumIcon](images/Ethereum.png?raw=true "Thank you")  
      **<span style="color:#0000FF">0x4150D09d9E72F97dD0BEe15c76EB8e58bAC69830</span>** <br><br>
  - [BEP20代幣](#BEP20)  ![BEP20](images/BEP20.png?raw=true "Thank you")  
      **<span style="color:#0000FF">0x4150D09d9E72F97dD0BEe15c76EB8e58bAC69830</span>**
