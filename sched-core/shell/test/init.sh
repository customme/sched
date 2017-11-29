#!/bin/bash

#系统初始化

####创建普通用户帐号，并授权使用sudo -i切换到root

LOG=/tmp/system_init.log


####关闭防火墙

iptables_stop()
{
    service iptables stop > /dev/null
	chkconfig iptables off
}

####关闭SELinux
selinux_stop()
{
  sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
  sed -i 's/SELINUXTYPE=targeted/#SELINUXTYPE=targeted/g' /etc/sysconfig/selinux
}

####内核优化
kernel_optimize()
{

echo -e "net.ipv4.tcp_max_tw_buckets = 5000" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_sack = 1" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_window_scaling = 1" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_rmem = 4096 87380 4194304" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_wmem = 4096 16384 4194304" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_max_syn_backlog = 65535" >> /etc/sysctl.conf
echo -e "net.core.netdev_max_backlog = 32768" >> /etc/sysctl.conf
echo -e "net.core.somaxconn = 65535" >> /etc/sysctl.conf
echo -e "net.core.wmem_default = 8388608" >> /etc/sysctl.conf
echo -e "net.core.rmem_default = 8388608" >> /etc/sysctl.conf
echo -e "net.core.rmem_max = 16777216" >> /etc/sysctl.conf
echo -e "net.core.wmem_max = 16777216" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_timestamps = 0" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_synack_retries = 2" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_syn_retries = 2" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_tw_recycle = 1" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_tw_reuse = 1" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_mem = 94500000 915000000 927000000" >> /etc/sysctl.conf
echo -e "net.ipv4.tcp_max_orphans = 3276800" >> /etc/sysctl.conf
echo -e "net.ipv4.ip_local_port_range = 1024 65000" >> /etc/sysctl.conf

modprobe bridge
sysctl -p >> $LOG
}

####同步系统时间

ntp_time()
{
	/usr/sbin/ntpdate 1.asia.pool.ntp.org;/usr/sbin/hwclock -w
	[ -f /var/spool/cron/root ] || touch /var/spool/cron/root
	if ! grep -q /usr/sbin/ntpdate /var/spool/cron/root
	then
	echo "0 */4 * * * /usr/sbin/ntpdate 1.asia.pool.ntp.org;/usr/sbin/hwclock -w" >> /var/spool/cron/root
	fi
	/etc/init.d/crond restart >> $LOG || ERROR "crond restart "
	chkconfig ntpd on
}

####修改系统打开文件的限制

modify_limits()
{
    if ! grep -q ^* /etc/security/limits.conf
	then
	    echo -e "* soft nproc unlimited" >> /etc/security/limits.conf
		echo -e "* hard nproc unlimited" >> /etc/security/limits.conf
		echo -e "* soft nofile 65535" >> /etc/security/limits.conf
		echo -e "* hard nofile 65535" >> /etc/security/limits.conf
	fi
	if ! grep -q pam_limits.so /etc/pam.d/login
	then
	echo "session    required    pam_limits.so" >> /etc/pam.d/login
	fi
}

####删除不必要的用户和组
delete_users_groups()
{
	userdel adm > /dev/null
	userdel lp > /dev/null
	userdel sync > /dev/null
	userdel shutdown > /dev/null
	userdel halt > /dev/null
	userdel operator > /dev/null
	userdel gopher > /dev/null
	groupdel adm > /dev/null
	groupdel lp > /dev/null
}

#关闭不必要的服务
close_services()
{
	/etc/init.d/auditd stop > /dev/null
	chkconfig auditd off > /dev/null
	/etc/init.d/autofs stop > /dev/null
	chkconfig autofs off > /dev/null
	/etc/init.d/postfix stop > /dev/null
	chkconfig postfix off > /dev/null
	/etc/init.d/cpuspeed stop > /dev/null
	chkconfig cpuspeed off > /dev/null
	/etc/init.d/haldaemon stop > /dev/null
	chkconfig haldaemon off > /dev/null
	/etc/init.d/ip6tables stop > /dev/null
	chkconfig ip6tables off > /dev/null
	/etc/init.d/messagebus stop > /dev/null
	chkconfig messagebus off > /dev/null
	/etc/init.d/netfs stop > /dev/null
	chkconfig netfs off > /dev/null
	/etc/init.d/nfs stop > /dev/null
	chkconfig nfs off > /dev/null
	/etc/init.d/nfslock stop > /dev/null
	chkconfig nfslock off > /dev/null
	/etc/init.d/restorecond stop > /dev/null
	chkconfig restorecond off > /dev/null
	chkconfig rpcbind off > /dev/null
	chkconfig rpcgssd off > /dev/null
	chkconfig cups off > /dev/null
}

modify_datetime()
{
cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
}

modify_hostname(){
lastip=`ifconfig eth0 | sed -n '/inet addr/s/^[^:]*:\([0-9.]\{7,15\}\) .*/\1/p' | awk -F'.' '{print $4}'`
hname="yygz-"$lastip.gzserv.com
hostname $hname
sed -i "s/HOSTNAME=localhost.localdomain/HOSTNAME=$hname/g" /etc/sysconfig/network
}

modify_dnsserver(){
echo "nameserver 10.10.10.8" > /etc/resolv.conf
echo "nameserver 114.114.114.114" >> /etc/resolv.conf
}

kstatus=`grep tcp_synack_retries /etc/sysctl.conf | wc -l`


echo "Stop iptables..."
iptables_stop
echo "Stop Selinux..."
selinux_stop
echo "modify dnsserver"
modify_dnsserver
echo "modify datetime"
modify_datetime
echo "optimize kernel..."
if [ $kstatus -gt 0 ]; then
    echo "kernel yes"
else
    kernel_optimize
fi
echo "ntpdate Time..."
ntp_time
echo "modify limits..."
modify_limits
echo "delete users and groups..."
delete_users_groups
echo "close services..."
close_services
echo "modify hostname"
modify_hostname

