#!/bin/bash
#
# 任务运行器代理
# 1、启动任务定时器
# 2、定时器退出时判断任务执行状态并更新


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $SHELL_HOME/common/include.sh
source $SHELL_HOME/common/db/config.sh
source $SHELL_HOME/common/db/mysql/mysql_util.sh
source $SCHED_HOME/common/task_util.sh
source $SCHED_HOME/scheduler/schedule_util.sh


function main()
{
    info "Current working directory: $BASE_DIR, invoke script: $0 $@"

    # 参数判断
    if [[ $# -lt 3 ]]; then
        error "Invalid arguments: $@, usage: $0 <task id> <run time> <cycle value> [timeout]"
        exit 1
    fi

    task_id="$1"
    run_time="$2"
    cycle_value="$3"
    timeout="$4"

    # 更新任务状态为“正在运行”
    update_task_instance $task_id $run_time "task_state = $TASK_STATE_RUNNING, start_time = NOW(), end_time = NULL" > /dev/null

    # 休眠1秒，避免产生重复任务实例
    sleep 1

    # 启动定时器
    $SHELL_HOME/common/timer.sh "$SCHED_HOME/task_starter.sh $task_id" $cycle_value $timeout

    # 判断任务执行结果
    if [[ $? -eq 0 ]]; then
        log_task $LOG_LEVEL_INFO "Task: (task_id) ($task_id) done successfully"
        task_state=$TASK_STATE_SUCCESS
    else
        log_task $LOG_LEVEL_WARN "Task: (task_id) ($task_id) failed"
        task_state=$TASK_STATE_FAILED
    fi

    # 更新任务，状态、结束时间
    info "Update task: (task_id, run_time) ($task_id, $run_time) set task_state = $task_state"
    result=$(update_task_instance $task_id $run_time "task_state = $task_state, end_time = NOW()")
    counter=1
    while [[ $result -ne 1 && $counter -lt 10 ]]; do
        sleep 30
        counter=$((counter + 1))
        result=$(update_task_instance $task_id $run_time "task_state = $task_state, end_time = NOW()")
    done
    if [[ $result -eq 1 ]]; then
        info "Update task: (task_id, run_time) ($task_id, $run_time) successfully"
    else
        error "Update task: (task_id, run_time) ($task_id, $run_time) failed: $result"
    fi
}
main "$@"