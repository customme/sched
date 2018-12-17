#!/bin/bash
#
# Date: 2018-10-12
# Author: superz
# Description: 启动flume agent
# 环境变量:
#   FLUME_HOME    flume家目录
# 调度系统参数
#   LOG_LEVEL_INFO    日志级别(info)
# 任务扩展属性:
#   flume_conf        flume配置文件目录
#   submit_user       执行flume命令用户
#   agent_conf        agent配置文件
#   agent_name        agent名称
#   log_file          agent日志文件


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile


function execute()
{
    flume_conf=${flume_conf:-$FLUME_HOME/conf}
    submit_user=${submit_user:-flume}
    log_file=${log_file:-${agent_name}.log}

    run_cmd="flume-ng agent --conf $flume_conf -f $agent_conf -n $agent_name -Dflume.log.file=$log_file"

    log_task $LOG_LEVEL_INFO "$run_cmd"
    if [[ `whoami` = $submit_user ]]; then
        $run_cmd
    elif [[ $UID -eq 0 ]]; then
        su -l $submit_user -c "$run_cmd"
    else
        sudo su -l $submit_user -c "$run_cmd"
    fi
}

source $SCHED_HOME/plugins/task_executor.sh