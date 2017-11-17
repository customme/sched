#!/bin/bash
#
# 数据同步插件（hive到mysql）


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $SHELL_HOME/common/db/mysql/hive2mysql.sh
source $SCHED_HOME/plugins/data_sync.sh