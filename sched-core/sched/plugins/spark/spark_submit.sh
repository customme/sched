#!/bin/bash
#
# Date: 2017-06-26
# Author: superz
# Description: 提交spark任务
# 环境变量:
#   SCHED_HOME    调度系统家目录
# 调度系统参数
#   task_id           任务ID
#   run_time          运行时间
#   log_path          任务日志目录
#   LOG_LEVEL_INFO    日志级别(info)
# 任务扩展属性:
#   main_class            应用程序主类
#   app_jar               应用程序jar
#   app_class             应用程序类
#   sched_version         调度系统spark插件版本
#   submit_user           提交spark任务用户
#   master_url            master地址
#   deploy_mode           部署模式
#   driver_classpath      driver类路径
#   executor_classpath    executor类路径
#   local_jars            driver本地jar
#   extra_params          其他参数


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile


function execute()
{
    # 参数解析
    sched_jar=$SCHED_HOME/plugins/spark/lib/sched-spark-${sched_version:-0.0.1}.jar
    jdbc_jar=`ls -c $SCHED_HOME/plugins/lib/mysql-connector-java-*.jar | head -n 1`

    submit_user=${submit_user:-spark}
    main_class=${main_class:-org.zc.sched.plugins.spark.TaskExecutor}
    master_url=${master_url:-local}
    deploy_mode=${deploy_mode:-client}

    extra_params="--master $master_url --deploy-mode $deploy_mode $extra_params"

    run_cmd="spark-submit --class $main_class --driver-class-path $jdbc_jar:$driver_classpath --jars $sched_jar,$local_jars,$executor_classpath $extra_params $app_jar $task_id $run_time $app_class"

    log_task $LOG_LEVEL_INFO "$run_cmd"
    if [[ `whoami` = $submit_user ]]; then
        $run_cmd
    elif [[ $UID -eq 0 ]]; then
        su -l $submit_user -c "$run_cmd"
    else
        sudo su -l $submit_user -c "$run_cmd"
    fi
}

source $SCHED_HOME/plugins/task_executor.sh