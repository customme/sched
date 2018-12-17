#!/bin/bash
#
# Date: 2015-09-26
# Author: superz
# Description: 备份mysql表到文件
# 环境变量:
#   SCHED_HOME    调度系统家目录
# 调度系统变量
#   log_path           任务日志目录
# 任务扩展属性:
#   src_db_id       源数据库id
#   src_tables      源表名（多个用逗号隔开）
#   tar_dir         目标文件目录
#   backup_count    备份文件保留个数
#   tar_host        目标服务器
#   tar_user        目标服务器用户
#   tar_passwd      目标服务器密码
#   tar_port        目标服务器ssh端口


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $SHELL_HOME/common/db/db_util.sh
source $SCHED_HOME/plugins/db_util.sh


function execute()
{
    # 获取源数据库连接
    get_src_db

    # 获取数据，并压缩
    debug "Get source data and gzip to directory: $tar_dir"
    for src_table in ${src_tables//,/ }; do
        sql="SELECT * FROM $src_table"
        execute_src "$sql" > $data_path/${src_table}.$run_time
        gzip -f $data_path/${src_table}.$run_time
    done

    # 备份数，默认3个
    backup_count=${backup_count:-3}

    if [[ -z "$tar_host" || "$tar_host" = "$LOCAL_IP" || "$tar_host" = "$HOSTNAME" ]]; then
        # 创建目录
        mkdir -p $tar_dir

        # 移动数据到目标目录
        debug "Move data files to target directory"
        mv $data_path/*.gz $tar_dir

        # 删除历史备份
        debug "Adjust backup files to proper count"
        for src_table in ${src_tables//,/ }; do
            ls -c $tar_dir/${src_table}.*.gz | sed "1,${backup_count} d" | xargs -r rm -f
        done
    else
        # ssh端口
        tar_port=${tar_port:-22}

        # 创建目录
        $SHELL_HOME/common/expect/autossh.exp "$tar_passwd" "${tar_user}@${tar_host}" "mkdir -p $tar_dir" $tar_port

        for src_table in ${src_tables//,/ }; do
            # 复制数据到远程服务器
            $SHELL_HOME/common/expect/autoscp.exp "$tar_passwd" "$data_path/${src_table}.${run_time}.gz" "${tar_user}@${tar_host}:${tar_dir}" $tar_port

            # 删除历史备份
            debug "Adjust backup files to proper count"
            $SHELL_HOME/common/expect/autossh.exp "$tar_passwd" "${tar_user}@${tar_host}" "ls -c $tar_dir/${src_table}.*.gz | sed \"1,${backup_count} d\" | xargs -r rm -f" $tar_port

            # 删除本地数据
            rm -f $data_path/${src_table}.${run_time}.gz
        done
    fi
}

source $SCHED_HOME/plugins/task_executor.sh