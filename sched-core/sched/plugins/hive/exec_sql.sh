#!/bin/bash
#
# 执行hive sql语句插件


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $SHELL_HOME/common/db/hive/hive_util.sh
source $SCHED_HOME/plugins/exec_sql.sh


# 执行sql语句
function exec_sql()
{
    debug "Execute sql and record verbose log to file: $log_path/exec_sql.log"
    execute_src < $log_path/src_sql.tmp "" "--verbose=true" > $log_path/exec_sql.log
}

# 执行sql语句获取数据
function get_data()
{
    debug "Execute sql to get data to file: $data_path/data.tmp"
    execute_src < $log_path/src_sql.tmp > $data_path/data.tmp

    debug "Convert hive special characters"
    hive_data_conv < $data_path/data.tmp > $data_path/data.txt
}
