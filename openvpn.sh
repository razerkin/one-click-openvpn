HOSTNAME="localhost"
PORT="3306"
USERNAME="root"
PASSWORD=""
DBUSER="vpnadmin"
DBPWD="vpnadminpwd"
GRANT="grant all on openvpn.* to "$DBUSER"@'localhost' identified by '"$DBPWD"';"
USERCERTNAME="vpnuser"
#DBNAME="openvpn"
#USERTABLENAME="vpnuser"
yum install -y epel-release 
yum install -y wget
wget https://mirrors.ustc.edu.cn/epel//7/x86_64/Packages/e/epel-release-7-11.noarch.rpm
rpm -ivh epel-release-7-11.noarch.rpm
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum clean all
rm -rf /var/cache/yum
yum makecache
yum update -y
yum install -y pkcs11-helper pkcs11-helper-devel lzo lzo-devel ntp
sudo ntpdate time.windows.com&
sudo systemctl enable ntpd
sudo systemctl start ntpd
sudo timedatectl set-ntp true
date
yum groupinstall -y "Development Tools"
yum install -y cyrus-sasl openssl mariadb mariadb-devel mariadb-server pam-devel libnss-mysql git
git clone https://github.com/razerkin/openvpn
cd /usr/local/src
cp ~/openvpn/pam_mysql-0.7RC1.tar.gz /usr/local/src
tar -zxvf pam_mysql-0.7RC1.tar.gz
cd pam_mysql-0.7RC1/
./configure --with-pam-mods-dir=/usr/lib64/security
make install
ls /usr/lib64/security/pam_mysql.so
chkconfig saslauthd on
rpm -Uvh http://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm
yum install -y mysql mysql-server mysql-devel mysql-libs
chkconfig mysqld on
service mysqld start
yum install -y vim lrzsz openvpn easy-rsa
cd ~
cp ~/openvpn/openvpn-2.0.7.tar.gz ~
tar xf openvpn-2.0.7.tar.gz 
cd openvpn-2.0.7/plugin/auth-pam/
make
cp openvpn-auth-pam.so /etc/openvpn/
mkdir -p  /etc/openvpn/easy-rsa/keys
cp -rf /usr/share/easy-rsa/3.0.3/* /etc/openvpn/easy-rsa/
cp /usr/share/doc/easy-rsa-3.0.3/vars.example /etc/openvpn/easy-rsa/
cd /etc/openvpn/easy-rsa
cp ~/openvpn/var vars
./easyrsa init-pki nopass
./easyrsa build-ca nopass
./easyrsa gen-dh nopass
openvpn --genkey --secret ta.key
cp -r ta.key /etc/openvpn/
./easyrsa  gen-req server decli nopass
./easyrsa sign-req server server
./easyrsa build-client-full $USERCERTNAME nopass
cp /etc/openvpn/easy-rsa/pki/ca.crt /etc/openvpn/server/
cp /etc/openvpn/easy-rsa/pki/private/server.key /etc/openvpn/server/
cp /etc/openvpn/easy-rsa/pki/issued/server.crt /etc/openvpn/server/
cp /etc/openvpn/easy-rsa/pki/dh.pem /etc/openvpn/server/
cp /etc/openvpn/easy-rsa/pki/ca.crt /etc/openvpn/client/
cp /etc/openvpn/easy-rsa/pki/issued/$USERCERTNAME.crt /etc/openvpn/client/
cp /etc/openvpn/easy-rsa/pki/private/$USERCERTNAME.key /etc/openvpn/client/
#cp /pki/ca.crt /etc/openvpn/server/
#cp /pki/private/server.key /etc/openvpn/server/
#cp /pki/issued/server.crt /etc/openvpn/server/
#cp /pki/dh.pem /etc/openvpn/server/
#cp /pki/ca.crt /etc/openvpn/client/
#cp /pki/issued/vpnuser.crt /etc/openvpn/client/
#cp /pki/private/vpnuser.key /etc/openvpn/client/
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p
yum install -y iptables iptables-services
systemctl stop firewalld
systemctl mask firewalld
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
iptables -A INPUT -i lo -p all -j ACCEPT
iptables -A INPUT -p all -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -i tun+ -j ACCEPT
iptables -A FORWARD -i tun+ -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 465 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 110 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 25 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
iptables -A INPUT -p udp --dport 1194 -j ACCEPT
iptables -A INPUT -s 10.8.0.0/24 -p all -j ACCEPT
iptables -A FORWARD -d 10.8.0.0/24 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 3306 -j ACCEPT
service iptables save
systemctl enable iptables.service
systemctl start iptables.service
cp ~/openvpn/server.conf /etc/openvpn/
mysql -h $HOSTNAME -u $USERNAME -p$PASSWORD -e "source ~/openvpn/mysql.sql";
mysql -h $HOSTNAME -u $USERNAME -p$PASSWORD -e "$GRANT";
mysql -h $HOSTNAME -u $USERNAME -p$PASSWORD -e "flush privileges";
touch /etc/pam.d/openvpn
echo 'auth sufficient pam_mysql.so user='$DBUSER' passwd='$DBPWD' host=localhost db=openvpn table=vpnuser usercolumn=name passwdcolumn=password [where=vpnuser.active=1] sqllog=0 crypt=2 sqllog=true logtable=logtable logmsgcolumn=msg logusercolumn=user logpidcolumn=pid loghostcolumn=host logrhostcolumn=rhost logtimecolumn=time' >> /etc/pam.d/openvpn
echo 'account required pam_mysql.so user='$DBUSER' passwd='$DBPWD' host=localhost db=openvpn table=vpnuser usercolumn=name passwdcolumn=password [where=vpnuser.active=1] sqllog=0 crypt=2 sqllog=true logtable=logtable logmsgcolumn=msg logusercolumn=user logpidcolumn=pid loghostcolumn=host logrhostcolumn=rhost logtimecolumn=time' >> /etc/pam.d/openvpn
saslauthd -a pam
testsaslauthd -u test1 -p test1 -s openvpn
cp ~/openvpn/server.conf /etc/openvpn/
service openvpn@server restart
sz /etc/openvpn/server/ca.crt
sz /etc/openvpn/client/$USERCERTNAME.key
sz /etc/openvpn/client/$USERCERTNAME.crt
sz /etc/openvpn/ta.key
