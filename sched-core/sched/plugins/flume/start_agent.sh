#!/bin/bash
#
# 启动agent


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