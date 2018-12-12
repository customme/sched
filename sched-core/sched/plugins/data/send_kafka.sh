#!/bin/bash
#
# 将扁平格式数据转换成json格式并发送到kafka


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile


DATA_DIR=/var/ad/data

ZK_LIST=yygz-65.gzserv.com:2181,yygz-66.gzserv.com:2181,yygz-67.gzserv.com:2181

BROKER_LIST=yygz-65.gzserv.com:9092,yygz-66.gzserv.com:9092,yygz-67.gzserv.com:9092


function execute()
{
    # 数据文件目录
    data_dir=${data_dir:-$DATA_DIR}
    # zookeeper
    zk_list=${zk_list:-$ZK_LIST}
    # broker
    broker_list=${broker_list:-$BROKER_LIST}
    # topic
    topic=${topic:-$product_code}

    # 解析运行时参数
    start_date=`awk -F '=' '$1 == "start_date" {print $2}' $log_path/run_params`
    start_date=${start_date:-${run_time:0:8}}
    end_date=`awk -F '=' '$1 == "end_date" {print $2}' $log_path/run_params`
    end_date=${end_date:-$start_date}

    # 创建topic
    log_task $LOG_LEVEL_INFO "$KAFKA_HOME/bin/kafka-topics.sh --create --replication-factor 2 --partitions 3 --topic $topic --zookeeper $zk_list"
    $KAFKA_HOME/bin/kafka-topics.sh --create --replication-factor 2 --partitions 3 --topic $topic --zookeeper $zk_list

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