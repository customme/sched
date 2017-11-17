#!/bin/bash
#
# 执行mysql sql语句插件


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $SCHED_HOME/plugins/exec_sql.sh