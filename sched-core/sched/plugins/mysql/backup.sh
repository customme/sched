#!/bin/bash
#
# 备份mysql表到文件


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