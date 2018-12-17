#!/bin/bash
#
# Date: 2015-09-15
# Author: superz
# Description: 执行mysql sql语句
# 环境变量:
#   SCHED_HOME    调度系统家目录
# 调度系统变量
#   log_path           任务日志目录
# 任务扩展属性:
#   src_db_id         源数据库id
#   src_sql           待执行sql语句
#   tar_db_id         目标数据库id
#   tar_table_name    目标表名
#   tar_columns       目标字段
#   tar_load_mode     装载模式
#   source_file       通过source命令引入的文件


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $SCHED_HOME/plugins/exec_sql.sh