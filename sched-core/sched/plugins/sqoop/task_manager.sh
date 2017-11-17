#!/bin/bash
#
# 任务管理器


DIR=`pwd`

source $DIR/config.sh
source $DIR/common.sh
source $DIR/task_config.sh
source $DIR/task_common.sh


# 获取待运行任务
# Globals:
# Arguments:
# Returns:
function get_tasks()
{
    execute_meta "SELECT id from t_task WHERE status IN ($TASK_STATUS_INIT) AND valid = $TASK_VALID LIMIT $TASK_FETCH_SIZE"
}

# 启动任务
# Globals:
# Arguments:
# Returns:
function execute()
{
    get_tasks | while read task_id; do
        #检查当前任务并发数
        if [ `ps -ef | grep "task_runner\.sh" | wc -l` -le $MAX_THREAD_COUNT ]; then
            nohup sh task_runner.sh $task_id > $TASK_LOG_DIR/${task_id}.log 2> $TASK_LOG_DIR/${task_id}.err &
        else
            break
        fi
    done
}

function main()
{
    while :; do
        execute
        sleep $TASK_CHECK_INTERVAL
    done
}
main "$@"
