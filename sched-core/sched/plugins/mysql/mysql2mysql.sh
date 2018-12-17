#!/bin/bash
#
# Date: 2015-09-26
# Author: superz
# Description: mysql到mysql数据同步
# 环境变量:
#   SCHED_HOME    调度系统家目录
# 调度系统变量
#   log_path           任务日志目录
# 任务扩展属性:
#   src_db_id           源数据库id
#   src_table_name      源表名
#   src_table_type      源表类型
#   src_columns         源表待同步字段
#   src_time_columns    源表增量时间字段（多个用逗号隔开）
#   src_filter          源数据过滤条件
#   page_size           分页大小
#   tar_db_id           目标数据库id
#   tar_table_name      目标表名
#   tar_table_type      目标表类型
#   tar_columns         目标表映射字段
#   tar_create_mode     目标表创建模式
#   tar_load_mode       目标数据装载模式


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $SHELL_HOME/common/db/mysql/mysql2mysql.sh
source $SCHED_HOME/plugins/data_sync.sh