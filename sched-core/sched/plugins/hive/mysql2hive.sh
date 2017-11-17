#!/bin/bash
#
# mysql到hive数据同步插件


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $SHELL_HOME/common/db/hive/mysql2hive.sh
source $SCHED_HOME/plugins/data_sync.sh