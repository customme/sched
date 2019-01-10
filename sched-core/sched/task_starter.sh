#!/bin/bash

# 任务启动器
# 1、生成任务实例，并启动任务运行器
# 2、任务执行成功后，从任务依赖关系中获取子任务并依次启动


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $SHELL_HOME/common/include.sh
source $SHELL_HOME/common/date_util.sh
source $SHELL_HOME/common/db/config.sh
source $SHELL_HOME/common/db/mysql/mysql_util.sh
source $SCHED_HOME/common/task_util.sh
source $SCHED_HOME/scheduler/schedule_util.sh


# 实例化任务并启动
function run_task_interval()
{
    # 获取任务信息
    local task=($(get_task $task_id))
    local last_try=$((task[1] == 1 ? 1 : 0))
    local run_time=$(date +%Y%m%d%H%M%S)

    # 实例化任务
    echo "INSERT INTO t_task_pool (task_id, run_time, task_state, priority, max_try_times, tried_times, run_server, start_time, create_by, create_date) VALUES
    ($task_id, STR_TO_DATE('$run_time','%Y%m%d%H%i%s'), $TASK_STATE_RUNNING, ${task[0]}, ${task[1]}, 1, $SERVER_ID, NOW(), ${task[2]}, NOW());
    " | execute_meta

    # 启动任务运行器
    $SCHED_HOME/task_runner.sh $task_id $run_time $last_try 2>&1 >> $SCHED_LOG_DIR/task_runner.log.$(date +'%Y-%m-%d')
}

# 获取子任务并依次启动
function run_task_children()
{
    get_task_children $task_id | while read task_id; do
        run_task_interval $task_id
    done
}

function execute()
{
    run_task_interval $task_id
    run_task_children
}

function main()
{
    info "Current working directory: $BASE_DIR, invoke script: $0 $@"

    # 参数判断
    if [[ $# -lt 1 ]]; then
        error "Invalid arguments: $@, usage: $0 <task id>"
        exit 1
    fi

    task_id="$1"

    set -e

    execute
}
main "$@"