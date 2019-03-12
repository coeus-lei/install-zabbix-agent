#!/bin/bash
#read pcip
#add zabbix yum-repo 
set -u
VERSION=`awk -F"[. ]+" '{print $4}' /etc/centos-release`
if [[ "$1" == "local" ]];then
	pcip=$2
elif [[ "$1" == "net" ]]; then
	pcip=`curl -Lks curlip.me | awk -F"[: ]+" 'NR==1{print $NF}'`
fi

#install zabbix-agent zabbix-sender
[ -f /tmp/yum.conf ] && :>/tmp/yum.conf
echo -e "[zabbix]\nname = zabbix\nbaseurl = http://repo.zabbix.com/zabbix/4.0/rhel/$VERSION/x86_64\n" > /tmp/yum.conf
yum -c /tmp/yum.conf -y install zabbix-agent zabbix-sender
#setting configuration
sed -ri "s/^(Server(Active)?=).*/\1$SERVER_IP/" /etc/zabbix/zabbix_agentd.conf
#reset $SERVER_IP first
sed -ri "s/^(Hostname=).*/\1$HOSTNAME/" /etc/zabbix/zabbix_agentd.conf

scripts_path=/etc/zabbix/scripts/
UserParameter1=/etc/zabbix/zabbix_agentd.d/
mkdir -p $scripts_path
curl -Lks4 https://raw.githubusercontent.com/coeus-lei/centos_init/master/fdisk/disk.pl -o ${scripts_path}disk.pl
curl -Lks4 https://raw.githubusercontent.com/coeus-lei/centos_init/master/fdisk/disktcp.conf -o ${UserParameter1}disktcp.conf
chmod 755 ${scripts_path}disk.pl

(crontab -l; echo -e "*/1 * * * * /usr/sbin/ss  -tan|awk 'NR>1{++S[\$1]}END{for (a in S) print a,S[a]}' > /tmp/tcp-status.txt\n*/1 * * * * /usr/sbin/ss -o state established '( dport = :http or sport = :http )' |grep -v Netid > /tmp/httpNUB.txt") | crontab -

echo 'zabbix ALL=(root)NOPASSWD:/usr/bin/cksum /root/.ssh/authorized_keys' >>/etc/sudoers
echo "UserParameter=authorized_keys,sudo /usr/bin/cksum /root/.ssh/authorized_keys|awk '{print \$1}'" >> /etc/zabbix/zabbix_agentd.conf
echo "UserParameter=iptables_lins,/usr/bin/sudo iptables -S |md5sum|awk '{print \$1}'" >> /etc/zabbix/zabbix_agentd.conf 
echo 'zabbix ALL=(root)NOPASSWD:/usr/sbin/iptables,/usr/bin/cksum /etc/sysconfig/iptables' >>/etc/sudoers 
echo "UserParameter=iptables_file,/usr/bin/sudo /usr/bin/cksum /etc/sysconfig/iptables|awk '{print \$1}'"  >>/etc/zabbix/zabbix_agentd.conf

[ "$VERSION" = "7" ] && { systemctl enable zabbix-agent.service && systemctl start zabbix-agent.service; }
[ "$VERSION" = "6" ] && { chkconfig zabbix-agent on && service zabbix-agent start; }