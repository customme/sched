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


flume_conf=${$flume_conf:-$FLUME_HOME/conf}
submit_user=${submit_user:-spark}


function execute()
{
    run_cmd="nohup flume-ng agent --conf $flume_conf -f $agent_conf -n $agent_name > /dev/null 2>&1 &"

    if [[ `whoami` = $submit_user ]]; then
        $run_cmd
    elif [[ $UID -eq 0 ]]; then
        su -l $submit_user -c "$run_cmd"
    else
        sudo su -l $submit_user -c "$run_cmd"
    fi
}

source $SCHED_HOME/plugins/task_executor.sh