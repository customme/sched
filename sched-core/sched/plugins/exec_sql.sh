#!/bin/bash
#
# 执行sql语句插件模板
#
# 步骤:
# 1 获取待执行sql语句
# 2 获取源数据库连接信息
# 3.1
#    a、获取目标数据库连接信息
#    b、执行sql语句获取数据
#    c、装载数据到目标表
# 3.2 执行sql语句


source $SHELL_HOME/common/db/db_util.sh
source $SCHED_HOME/plugins/db_util.sh


# 执行sql语句
function exec_sql()
{
    debug "Execute sql and record verbose log to file: $log_path/exec_sql.log"
    execute_src < $log_path/src_sql.tmp "" "-vvv" > $log_path/exec_sql.log
}

# 执行sql语句获取数据
function get_data()
{
    debug "Execute sql to get data to file: $data_path/data.tmp"
    execute_src < $log_path/src_sql.tmp > $data_path/data.tmp

    debug "Convert mysql special characters"
    mysql_data_conv < $data_path/data.tmp > $data_path/data.txt
}

# 装载数据到目标表
function load_data()
{
    local sql="LOAD DATA LOCAL INFILE '$data_path/data.txt' $load_mode INTO TABLE $tar_table_name"

    if [[ -n "$tar_columns" ]]; then
        sql="$sql ( $tar_columns )"
    fi
    debug "Got sql: $sql"

    debug "Load data to target table: $tar_table_name and record verbose log to file: $log_path/load_data.log"
    execute_tar "$sql" "-vvv" > $log_path/load_data.log
}

function execute()
{
    # 获取待执行sql语句
    log_task $LOG_LEVEL_INFO "Get sql to be executed"
    get_prop_replace $task_id src_sql > $log_path/src_sql.tmp

    # 获取源数据库连接信息
    get_src_db

    if [[ -n "$tar_db_id" ]]; then
        # 获取目标数据库连接信息
        get_tar_db

        # 执行sql语句获取数据
        log_task $LOG_LEVEL_INFO "Execute sql to get data"
        get_data

        # 预装载数据
        debug "Preload data"
        preload

        # 装载数据到目标表
        log_task $LOG_LEVEL_INFO "Load data to target table"
        load_data
    else
        # 执行sql语句
        log_task $LOG_LEVEL_INFO "Execute sql"
        exec_sql
    fi
}

source $SCHED_HOME/plugins/task_executor.sh