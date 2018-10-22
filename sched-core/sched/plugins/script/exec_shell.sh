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
    # 获取待执行命令
    log_task $LOG_LEVEL_INFO "Get command to execute"
    get_prop_value $task_id tar_cmd > $log_path/tar_cmd.tmp

    # 判断待执行命令是否为空
    if [[ ! -s $log_path/tar_cmd.tmp ]]; then
        error "The command to execute is empty"
        exit 1
    fi

    log_task $LOG_LEVEL_INFO "Execute command begin"
    if [[ -z "$tar_host" ]]; then
        # 执行命令
        chmod +x $log_path/tar_cmd.tmp
        source $log_path/tar_cmd.tmp
    else
        log_task "Target host: ${tar_user}@${tar_host} $tar_passwd"
        $SHELL_HOME/common/expect/autossh.exp "$tar_passwd" "${tar_user}@${tar_host}" `cat $log_path/tar_cmd.tmp`
    fi
    log_task $LOG_LEVEL_INFO "Execute command end"
}

source $SCHED_HOME/plugins/task_executor.sh