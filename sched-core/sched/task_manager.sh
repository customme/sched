#!/bin/bash
#
# 任务管理器
# 1.清理任务池一段时间的历史任务
# 2.根据任务周期实例化任务到任务池
# 3.检查状态为“等待”的任务的依赖关系，满足执行条件则更新状态为“就绪”


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
source $SCHED_HOME/manager/manage_util.sh


# 捕捉kill信号
trap 'warn "$0 is killed, pid: $$, and will exit after current execution";unset RUN_MODE' TERM


# 清理任务管理器日志
function clean_daemon_log()
{
    debug "Clean up the daemon log"
    find $SCHED_LOG_DIR -maxdepth 1 -type f -name "task_manager.log.*" | xargs -r ls -c | sed "1,${LOG_FILE_KEEP_NUM} d" | xargs -r rm -f
    find $SCHED_LOG_DIR -maxdepth 1 -type f -name "task_manager.sql.*" | xargs -r ls -c | sed "1,${LOG_FILE_KEEP_NUM} d" | xargs -r rm -f
}

# 拆分任务执行日志
# 每个月一次，成功后会生成一个空的flag文件
function split_task_log()
{
    local flag_file=$SCHED_LOG_DIR/task_log_split_flag.$(date +%Y%m)
    debug "Check if exists flag file: $flag_file"
    if [[ ! -f $flag_file ]]; then
        rm -f $SCHED_LOG_DIR/task_log_split_flag.*
        # 清理历史任务日志，并生成flag文件
        debug "Clean history task log from table: t_task_log and generate flag file: $flag_file"
        split_log && touch $flag_file
    fi
}

# 清理任务池一段时间的历史任务
# 每天一次，成功后会生成一个空的flag文件
function clean_task_pool()
{
    local flag_file=$SCHED_LOG_DIR/task_pool_clean_flag.$(date +%Y%m%d)
    debug "Check if exists flag file: $flag_file"
    if [[ ! -f $flag_file ]]; then
        rm -f $SCHED_LOG_DIR/task_pool_clean_flag.*
        # 清理历史任务实例，并生成flag文件
        debug "Clean history task instance from table: t_task_pool and generate flag file: $flag_file"
        clean_task_instance && touch $flag_file
    fi
}

# 实例化任务
function init_task()
{
    debug "Get tasks and instantiate one by one"
    get_tasks | while read task_id create_by task_cycle cycle_value start_time end_time date_serial priority max_try_times; do
        debug "Begin instantiate task: (task_id, task_cycle, cycle_value, start_time, end_time) ($task_id, $task_cycle, $cycle_value, $start_time, $end_time)"
        make_task_instance $task_id $task_cycle $cycle_value $start_time $end_time | while read task_id run_time; do

            debug "Insert task: (task_id, run_time, task_state, priority, max_try_times, create_by) ($task_id, $run_time, $first_cycle, $TASK_STATE_INITIAL, $priority, $max_try_times, $create_by)"
            insert_task $task_id $run_time $TASK_STATE_INITIAL $priority $max_try_times $create_by
        done
    done
}

# 检查状态为“初始化”的任务的依赖关系
function check_task_deps()
{
    debug "Get initial tasks and check one by one"
    get_initial_tasks | while read task_id run_time task_cycle first_time date_serial; do

        debug "Begin check task: (task_id, run_time, task_cycle, first_time, date_serial) ($task_id, $run_time, $task_cycle, $first_time, $date_serial)"
        task_state=$(check_dependence $task_id $run_time $task_cycle $first_time $date_serial)

        debug "Done check task: (task_id, run_time) ($task_id, $run_time) task_state = $task_state"
        if [[ -z "$task_state" ]]; then
            debug "Update task: (task_id, run_time) ($task_id, $run_time) set task_state = \$TASK_STATE_READY"
            update_task_instance $task_id $run_time "task_state = $TASK_STATE_READY" > /dev/null
        fi
    done
}

# 执行操作
function execute()
{
    clean_daemon_log

    log_fn split_task_log

    log_fn clean_task_pool

    log_fn init_task

    log_fn check_task_deps
}

# 滚动日志
function roll_log()
{
    local cur_date=$(date +'%Y-%m-%d')
    local prev_date=$(date +'%Y-%m-%d' -d "$cur_date 1 day ago")
    if [[ -s $log_file && ! -f $log_file.$prev_date ]]; then
        sed "/${cur_date}/Q" $log_file > $log_file.$prev_date
        sed -n "/${cur_date}/,\$p" $log_file > $log_file.tmp
        mv -f $log_file.tmp $log_file
    fi
}

# 用法
function usage()
{
    echo "Usage: $0 [-l log level<0:debug/1:info/2:warn/3:error>] [-m run mode<once/loop>]"
}

function main()
{
    info "Current working directory: $BASE_DIR, invoke script: $0 $@"

    while getopts ":l:m:" name; do
        case "$name" in
            l)
                LOG_LEVEL="$OPTARG";;
            m)
                RUN_MODE="$OPTARG";;
            ?)
                usage
                exit 1;;
        esac
    done

    # 出错立即退出
    set -e

    # 创建日志文件目录
    mkdir -p $SCHED_LOG_DIR
    log_file=$SCHED_LOG_DIR/task_manager.log

    if [[ "$RUN_MODE" = "$RUN_MODE_LOOP" ]]; then
        info "Script will execute periodically"

        while [[ "$RUN_MODE" = "$RUN_MODE_LOOP" ]]; do
            execute 2>&1 | grep -v ".*password.*command.*insecure" >> $log_file

            roll_log

            if [[ "$RUN_MODE" != "$RUN_MODE_LOOP" ]]; then
                break
            fi

            info "$0 sleep for $TASK_CHECK_INTERVAL"
            sleep $TASK_CHECK_INTERVAL
            info "$0 wake up"
        done
    else
        info "Script will execute one time and exit"

        execute 2>&1 | grep -v ".*password.*command.*insecure"
    fi
}
main "$@"