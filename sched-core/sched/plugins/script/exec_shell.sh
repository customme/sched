#!/bin/bash
#
# 执行shell脚本插件


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile


function execute()
{
    if [[ -z "$tar_host" ]]; then
        # 获取待执行命令
        log_task $LOG_LEVEL_INFO "Get command to execute"
        get_prop_value $task_id tar_cmd > $log_path/tar_cmd.tmp

        # 判断待执行命令是否为空
        if [[ ! -s $log_path/tar_cmd.tmp ]]; then
            error "The command to execute is empty"
            exit 1
        fi

        # 执行命令
        log_task $LOG_LEVEL_INFO "Execute command begin"
        chmod +x $log_path/tar_cmd.tmp
        source $log_path/tar_cmd.tmp
        log_task $LOG_LEVEL_INFO "Execute command end"
    else
        warn "Run shell in remote host is yet to be implemented"
    fi
}

source $SCHED_HOME/plugins/task_executor.sh