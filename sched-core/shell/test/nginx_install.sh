#!/bin/bash

####

#yum -y install make apr* autoconf automake curl-devel gcc gcc-c++ zlib-devel openssl openssl-devel pcre-devel gd autotools-dev automake autoconf2.13 m4 perl libperl5.14 gd-devel

cd /work/soft/nginx

tar zxvf pcre-8.39.tar.gz
tar zxvf nginx-1.10.3.tar.gz
tar zxvf openssl-1.0.2j.tar.gz
tar zxvf ngx_cache_purge-2.3.tar.gz
tar xvf form-input-nginx-module-master.tar
tar xvf ngx_devel_kit-master.tar
unzip nginx-upstream-fair-master.zip
tar zxvf lua-nginx-module-0.10.6.tar.gz

cd nginx-1.10.3

groupadd www
useradd -g www www -s /bin/false

./configure --user=www --group=www \
--prefix=/work/install/nginx-1.10.3 \
--sbin-path=/usr/sbin/nginx \
--conf-path=/work/install/nginx-1.10.3/conf/nginx.conf \
--error-log-path=/work/install/nginx-1.10.3/logs/error.log \
--pid-path=/var/run/nginx.pid \
--lock-path=/var/lock/subsys/nginx \
--with-poll_module \
--with-http_ssl_module \
--with-http_sub_module \
--with-http_gzip_static_module \
--with-http_random_index_module \
--with-http_secure_link_module \
--with-http_stub_status_module \
--with-http_realip_module \
--with-http_image_filter_module \
--http-log-path=/work/install/nginx-1.10.3/logs/access.log \
--add-module=/work/soft/nginx/ngx_cache_purge-2.3 \
--add-module=/work/soft/nginx/ngx_devel_kit-master \
--add-module=/work/soft/nginx/form-input-nginx-module-master \
--add-module=/work/soft/nginx/nginx-upstream-fair-master \
--with-openssl=/work/soft/nginx/openssl-1.0.2j \
--with-pcre=/work/soft/nginx/pcre-8.39 \
--add-module=/work/soft/nginx/lua-nginx-module-0.10.6 \
--with-ld-opt="-Wl,-rpath,/usr/local/lib"

make
make install






#######

echo '''
#!/bin/bash
#
# nginx - this script starts and stops the nginx daemon
#
# chkconfig: - 85 15
# description: Nginx is an HTTP(S) server, HTTP(S) reverse
# proxy and IMAP/POP3 proxy server
# processname: nginx
# config: /etc/nginx/nginx.conf
# config: /etc/sysconfig/nginx
# pidfile: /var/run/nginx.pid

# Source function library.
. /etc/rc.d/init.d/functions

# Source networking configuration.
. /etc/sysconfig/network

# Check that networking is up.
[ "$NETWORKING" = "no" ] && exit 0

TENGINE_HOME="/work/install/nginx-1.10.3"
nginx="/usr/sbin/nginx"
prog=$(basename $nginx)

NGINX_CONF_FILE="/work/install/nginx-1.10.3/conf/nginx.conf"

[ -f /etc/sysconfig/nginx ] && /etc/sysconfig/nginx

lockfile=/var/lock/subsys/nginx

start() {
    [ -x $nginx ] || exit 5
    [ -f $NGINX_CONF_FILE ] || exit 6
    echo -n $"Starting $prog: "
    daemon $nginx -c $NGINX_CONF_FILE
    retval=$?
    echo
    [ $retval -eq 0 ] && touch $lockfile
    return $retval
}

stop() {
    echo -n $"Stopping $prog: "
    killproc $prog -QUIT
    retval=$?
    echo
    [ $retval -eq 0 ] && rm -f $lockfile
    return $retval
    killall -9 nginx
}

restart() {
    configtest || return $?
    stop
    sleep 1
    start
}

reload() {
    configtest || return $?
    echo -n $"Reloading $prog: "
    killproc $nginx -HUP
    RETVAL=$?
    echo
}

force_reload() {
    restart
}

configtest() {
    $nginx -t -c $NGINX_CONF_FILE
}

rh_status() {
    status $prog
}

rh_status_q() {
    rh_status >/dev/null 2>&1
}

case "$1" in
start)
    rh_status_q && exit 0
    $1
;;
stop)
    rh_status_q || exit 0
    $1
;;
restart|configtest)
    $1
;;
reload)
    rh_status_q || exit 7
	$1
;;
force-reload)
    force_reload
;;
status)
    rh_status
;;
condrestart|try-restart)
    rh_status_q || exit 0
;;
*)

echo $"Usage: $0 {start|stop|status|restart|condrestart|try-restart|reload|force-reload|configtest}"
exit 2
esac
''' > /etc/init.d/nginx

chmod +x /etc/init.d/nginx


/etc/init.d/realserver start


centos7

vim /lib/systemd/system/nginx.service

===


[Unit]
Description=The nginx HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx -c /work/install/nginx-1.10.3/conf/nginx.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target


===

chmod 745 /lib/systemd/system/nginx.service

systemctl start nginx.service
systemctl restart nginx.service

systemctl status nginx.service













