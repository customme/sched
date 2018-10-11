#!/bin/bash
#
# 日期: 2018-09-03
# 描述: 停止启动服务
# 用法: sh migrate.sh stop/start


CODIS_HOME=/work/install/codis3.1
ZK_HOME=/work/install/zookeeper-3.4.9
KAFKA_HOME=/work/install/kafka_2.11-0.10.1.1


# 关闭
function stop()
{
    # nginx
    service nginx stop

    # tomcat
    /work/tomcats/tomcat1/bin/shutdown.sh
    /work/tomcats/tomcat2/bin/shutdown.sh
    /work/tomcats/tomcat3/bin/shutdown.sh
    /work/tomcats/tomcat4/bin/shutdown.sh
    /work/tomcats/tomcat5/bin/shutdown.sh
    /work/tomcats/tomcat6/bin/shutdown.sh
    /work/tomcats/tomcat7/bin/shutdown.sh

    # fdfs storage
    /usr/bin/stop.sh /usr/bin/fdfs_storaged /etc/fdfs/storage.conf
    # fdfs tracker
    /usr/bin/stop.sh /usr/bin/fdfs_trackerd /etc/fdfs/tracker.conf

    # mysql
    service mysql stop

    # kafka
    $KAFKA_HOME/bin/kafka-server-stop.sh

    # codis
    ps aux | grep codis-fe | grep -v grep | awk '{print $2}' | xargs -r kill
    ps aux | grep codis-da | grep -v grep | awk '{print $2}' | xargs -r kill
    ps aux | grep codis-pr | grep -v grep | awk '{print $2}' | xargs -r kill
    ps aux | grep codis-se | grep -v grep | awk '{print $2}' | xargs -r kill
    # zookeeper
    $ZK_HOME/bin/zkServer.sh stop

    # flume
    ps aux | grep flume | grep -v grep | awk '{print $2}' | xargs -r kill

    # www
    /work/www/rop-mobile-advs/work/bin/stop.sh
    /work/www/biz-advsstat-consumer/work/bin/stop.sh
    /work/www/diamond-server/work/bin/stop.sh
}

# 启动
function start()
{
    # nginx
    service nginx start

    # tomcat
    /work/tomcats/tomcat1/bin/startup.sh
    /work/tomcats/tomcat2/bin/startup.sh
    /work/tomcats/tomcat3/bin/startup.sh
    /work/tomcats/tomcat4/bin/startup.sh
    /work/tomcats/tomcat5/bin/startup.sh
    /work/tomcats/tomcat6/bin/startup.sh
    /work/tomcats/tomcat7/bin/startup.sh

    # fdfs tracker
    /usr/bin/fdfs_trackerd /etc/fdfs/tracker.conf
    # fdfs storage
    /usr/bin/fdfs_storaged /etc/fdfs/storage.conf

    # mysql
    service mysql start

    # zookeeper
    $ZK_HOME/bin/zkServer.sh start
    # codis
    cd $CODIS_HOME
    nohup ./bin/codis-dashboard --ncpu=1 --config=dashboard.toml --log=dashboard.log --log-level=WARN &
    nohup ./bin/codis-proxy --ncpu=1 --config=proxy.toml --log=proxy.log --log-level=WARN &
    ./bin/codis-server ./codis.conf
    nohup ./bin/codis-fe --ncpu=1 --log=fe.log --log-level=WARN --zookeeper=127.0.0.1:2181 --listen=113.106.90.72:18087 &
    cd -

    # kafka
    nohup $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties > $KAFKA_HOME/kafka.out 2>&1 &

    # flume
    nohup flume-ng agent --conf $FLUME_HOME/conf -f $ETL_HOME/nad/nad.agent -n nad > /work/logs/flume/nad.log 2>&1 &

    # www
    /work/www/diamond-server/work/bin/start.sh dev
    /work/www/biz-advsstat-consumer/work/bin/start.sh dev
    /work/www/rop-mobile-advs/work/bin/start.sh dev
}

(echo "$@" && $@ 2>&1) | tee -a ${1}.log &