# Lazy Scripts
these shell scripts will help you setup and configure LEMP stack && Tomcat on Ubuntu 20.04 LTS with less painful,  
after executing all of the shell scripts provided here, you will have a ready-to-use PHP/JavaEE deployment environment for your webapps.  
 > <font color=0000FF>使用這裡的shell scripts快速建立LEMP stack + JavaEE/Tomcat開發環境,  
   不用再被學長姐嫌棄連開發環境都搞不定 (ノ▼Д▼)ノ  
   可使用於Ubuntu 20.04 LTS AMD64架構</font>  


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
LAN="192.168.0.0/24" # The local network that you allow packets come in from there  
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
 https://blog.dq5rocks.com  
but that's my personal choice, you could buy domain/vps from other providers you preferred.

## Disclaimer Clause  
<font size=4 color=888888>不管發生什麼事，都不是我幹的，我什麼都不知道  ∠( ᐛ 」∠)＿ </font>  
i don't guarantee these shell scripts would work properly as you expected,  
review the code and set the proper parameters on top of the shell scripts  
carefully,  
every single node in cluster should have their own specific configuration,  
and sometimes these shell scripts may fail due to network connectivity  
or just the software package tar balls were updated to newer version  
and old ones were removed from URL links i wrote,  
you should know the risk and i have no resposibilities for that.  

## Contact me  
<font size=4 color=00FF00>沒有要叫我去上班，不要寫信給我，很忙，可能在忙著撿資源回收物換錢 (๑•́ ₃ •̀๑)</font>  
my E-mail address : [annbigbig@gmail.com](mailto:annbigbig@gmail.com)  
and my preferred language is Traditional Chinese (繁體中文),  
i could use English either but with very limited-skills.

## Donate to me
<font size=4>if these shell scripts actually help you a lot, you could buy me a beer :-D  
如果這裡的代碼，實質上幫助了你，比如說讓你<font color=#FF0000>保住了工作</font>或節省了你的時間，請不吝於打賞  
或是幫我介紹工作，之類的，您的實質鼓勵，是我持續耕耘的原動力，萬分感謝</font>  

   - [國泰世華銀行收款帳號](#CathayBank) **銀行代碼 013 帳號 001-50-235346-9 戶名 KUN AN HSU 館前分行**  


   - [Alipay(支付寶)](#alipay) **annbigbig@gmail.com**  


   - [BitCoin](#Bitcoin)  ![BitcoinIcon](images/Bitcoin.png?raw=true "Thank you")  

      **1FGEtWkZpo3WHzQqDw6aJvsaDyxNmX4H9**  

      (If this address can accumulate 1 bitcoin, I will write a CentOS version)  
       此地址累積到一個比特幣，我就寫一個給CentOS版本用的lazy_script  


   - [BitCoin Cash](#BitcoinCash)  ![BitcoinCashIcon](images/BitcoinCash.png?raw=true "Thank you")  
      **bitcoincash:qqrkre3qlz858x8zaq7ndykucldlve2lpc9lvvzgja**  


   - [Ethereum](#Ethereum)  ![EthereeumIcon](images/Ethereum.png?raw=true "Thank you")  
      **0x36077A217819cf747F938EbFad26Ec50e44cDC48**


   - [Dogecoin](#dogecoin) ![DogecoinIcon](images/doge.png?raw=true "Thank you")  
     **DJEZGrRP9BY6nnJJuFXoPFXzQdJZMe6n5d**  

## Hire me

<font size=4>  
可以叫我去上班喔，很缺錢  
寄信到 : [annbigbig@gmail.com](mailto:annbigbig@gmail.com)  
告訴我您是那家公司  
我把104的履歷寄給您  

能力值大概是這樣  
系維運維：🌑🌑🌑🌑🌕  
Java/Spring 後端Restful API開發：🌑🌑🌓🌕🌕  
系統設計UML模型圖導出：🌑🌑🌑🌑🌕  
UI：🌑🌓🌕🌕🌕  
文件整理：🌑🌑🌑🌕🌕  
</font>

