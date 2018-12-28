#!/bin/bash
#
# Date: 2018-10-26
# Author: superz
# Description: 将扁平格式数据转换成json格式并发送到kafka
# 环境变量:
#   KAFKA_HOME    kafka家目录
# 调度系统参数
#   log_path    任务日志目录
#   prev_day    run_time前一天
# 任务扩展属性:
#   data_dir        扁平格式数据目录
#   zk_list         zookeeper列表
#   broker_list     broker列表
#   topic           topic名称
#   replica_num     topic副本数
#   part_num        topic分区数
#   product_code    产品编码
# 任务实例参数:
#   start_date    开始日期
#   end_date      结束日期


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile


ZK_LIST=yygz-65.gzserv.com:2181,yygz-66.gzserv.com:2181,yygz-67.gzserv.com:2181

BROKER_LIST=yygz-65.gzserv.com:9092,yygz-66.gzserv.com:9092,yygz-67.gzserv.com:9092


function execute()
{
    # 数据文件目录
    data_dir=${data_dir:-/var/ad/data}
    # zookeeper
    zk_list=${zk_list:-$ZK_LIST}
    # broker
    broker_list=${broker_list:-$BROKER_LIST}
    # topic
    topic=${topic:-$product_code}

    # 开始日期
    start_date=`awk -F '=' '$1 == "start_date" {print $2}' $log_path/run_params`
    start_date=${start_date:-$prev_day}
    # 结束日期
    end_date=`awk -F '=' '$1 == "end_date" {print $2}' $log_path/run_params`
    end_date=${end_date:-$start_date}

    # 副本数
    replica_num=${replica_num:-2}

    # broker个数
    broker_num=`echo "$broker_list" | awk -F ',' '{print NF}'`
    # 分区个数
    part_num=${part_num:-$broker_num}

    # 出错不要立即退出
    set +e

    # 创建topic
    log_task $LOG_LEVEL_INFO "$KAFKA_HOME/bin/kafka-topics.sh --create --replication-factor $replica_num --partitions $part_num --topic $topic --zookeeper $zk_list"
    $KAFKA_HOME/bin/kafka-topics.sh --create --replication-factor $replica_num --partitions $part_num --topic $topic --zookeeper $zk_list

    # 出错立即退出
    set -e

    # 转json格式并发送到kafka
    log_task $LOG_LEVEL_INFO "$KAFKA_HOME/bin/kafka-console-producer.sh --broker-list $broker_list --topic $topic"
    range_date ${start_date//-/} ${end_date//-/} | while read the_date; do
        the_date=`date +%F -d "$the_date"`
        file_visit=$data_dir/$product_code/visit.$the_date
        awk -F '\t' 'BEGIN{
            split("'$fields'",arr,",")
            size=length(arr)
        }{
            printf("{")
            for(i=1;i<size;i++){
                printf("\"%s\":\"%s\",",arr[i],$i)
            }
            printf("\"%s\":\"%s\"}\n",arr[size],$size)
        }' $file_visit |
        $KAFKA_HOME/bin/kafka-console-producer.sh --broker-list $broker_list --topic $topic
    done
}

source $SCHED_HOME/plugins/task_executor.sh