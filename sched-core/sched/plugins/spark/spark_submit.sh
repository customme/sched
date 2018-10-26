#!/bin/bash
#
# 提交spark任务插件


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile


sched_jar=`ls -c $SCHED_HOME/plugins/spark/lib/sched-spark*.jar | head -n 1`
jdbc_jar=`ls -c $SCHED_HOME/plugins/lib/mysql-connector-java*.jar | head -n 1`

# 默认参数
submit_user=${submit_user:-spark}
main_class=${main_class:-org.zc.sched.plugins.spark.TaskExecutor}
master_url=${master_url:-local}
deploy_mode=${deploy_mode:-client}


function execute()
{
    extra_params="--master $master_url --deploy-mode $deploy_mode $extra_params"

    run_cmd="spark-submit --class $main_class --driver-class-path $sched_jar:$jdbc_jar:$app_jar:$driver_classpath --jars $sched_jar,$local_jars,$executor_classpath $extra_params $app_jar $task_id $run_time $app_class"

    if [[ `whoami` = $submit_user ]]; then
        $run_cmd
    elif [[ $UID -eq 0 ]]; then
        su -l $submit_user -c "$run_cmd"
    else
        sudo su -l $submit_user -c "$run_cmd"
    fi
}

source $SCHED_HOME/plugins/task_executor.sh