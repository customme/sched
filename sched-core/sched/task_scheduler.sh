#!/bin/bash

# 任务调度器
# 1、调度任务周期为“时间间隔”的任务
# 2、调度任务状态为“就绪”或“失败”且尝试次数小于最大尝试次数的任务


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


# 捕捉kill信号
trap 'warn "$0 is killed, pid: $$, and will exit after current execution";unset RUN_MODE' TERM


# 清理日志文件
function clean_log()
{
    debug "Clean up the log"
    find $SCHED_LOG_DIR -maxdepth 1 -type f -name "task_scheduler.log.*" | xargs -r ls -c | sed "1,${LOG_FILE_KEEP_NUM} d" | xargs -r rm -f
    find $SCHED_LOG_DIR -maxdepth 1 -type f -name "task_scheduler.sql.*" | xargs -r ls -c | sed "1,${LOG_FILE_KEEP_NUM} d" | xargs -r rm -f
    find $SCHED_LOG_DIR -maxdepth 1 -type f -name "task_runner.log.*" | xargs -r ls -c | sed "1,${LOG_FILE_KEEP_NUM} d" | xargs -r rm -f
    find $SCHED_LOG_DIR -maxdepth 1 -type f -name "task_runner.sql.*" | xargs -r ls -c | sed "1,${LOG_FILE_KEEP_NUM} d" | xargs -r rm -f
    find $SCHED_LOG_DIR -maxdepth 1 -type f -name "task_proxy.log.*" | xargs -r ls -c | sed "1,${LOG_FILE_KEEP_NUM} d" | xargs -r rm -f
    find $SCHED_LOG_DIR -maxdepth 1 -type f -name "task_proxy.sql.*" | xargs -r ls -c | sed "1,${LOG_FILE_KEEP_NUM} d" | xargs -r rm -f
    find $SCHED_LOG_DIR -maxdepth 1 -type f -name "task_starter.log.*" | xargs -r ls -c | sed "1,${LOG_FILE_KEEP_NUM} d" | xargs -r rm -f
    find $SCHED_LOG_DIR -maxdepth 1 -type f -name "task_starter.sql.*" | xargs -r ls -c | sed "1,${LOG_FILE_KEEP_NUM} d" | xargs -r rm -f

    # 清理任务运行日志目录
    if [[ -d $TASK_LOG_DIR ]]; then
        ls -c $TASK_LOG_DIR | sed "1,${TASK_LOG_KEEP_DAY} d" | xargs -r -I {} rm -rf $TASK_LOG_DIR/{}
    fi
    if [[ -d $TASK_DATA_DIR ]]; then
        ls -c $TASK_DATA_DIR | sed "1,${TASK_LOG_KEEP_DAY} d" | xargs -r -I {} rm -rf $TASK_DATA_DIR/{}
    fi
}

# kill超时任务
function kill_task()
{
    get_task_timeout | while read task_id run_time; do
        pname="$SCHED_HOME/task_runner.sh $task_id $run_time"
        pid=`ps -ef | grep "$pname" | grep -v grep | awk '{print $2}'`
        if [[ -n "$pid" ]]; then
            info "Kill task $pid $pname"
            kill $pid
        fi
        while [[ -n "$pid" ]]; do
            sleep 1
            pid=`ps -ef | grep "$pname" | grep -v grep | awk '{print $2}'`
        done
        info "Task $task_id $run_time is killed"
        update_task_instance $task_id $run_time "task_state = $TASK_STATE_KILLED"
    done
}

# 调度周期为“时间间隔”的任务
# 每次只获取一个任务
function schedule_interval_task()
{
    get_task_interval | while read task_id run_time cycle_value timeout; do
        # 启动任务代理
        cur_date=$(date +'%Y-%m-%d')
        info "Invoke task proxy: $SCHED_HOME/task_proxy.sh $task_id $run_time $cycle_value $timeout >> $SCHED_LOG_DIR/task_proxy.log.${cur_date} 2>&1 &"
        $SCHED_HOME/task_proxy.sh $task_id $run_time $cycle_value $timeout >> $SCHED_LOG_DIR/task_proxy.log.${cur_date} 2>&1 &
    done
}

# 调度状态为“就绪”的任务
# 任务状态为“失败”或“被杀死”并且已尝试次数小于最大尝试次数
# 根据服务器的最大并发数和当前并发数
function schedule_ready_task()
{
    get_task_ready | while read task_id run_time last_try; do
        # 启动任务
        cur_date=$(date +'%Y-%m-%d')
        info "Invoke task runner: $SCHED_HOME/task_runner.sh $task_id $run_time $last_try >> $SCHED_LOG_DIR/task_runner.log.${cur_date} 2>&1 &"
        $SCHED_HOME/task_runner.sh $task_id $run_time $last_try >> $SCHED_LOG_DIR/task_runner.log.${cur_date} 2>&1 &
    done
}

# 执行操作
function execute()
{
    # 发送心跳
    local result=$(send_heartbeat)
    if [[ $result -ne 1 ]]; then
        error "Unregistered server (id, ip) ($SERVER_ID, $LOCAL_IP)"
        exit 1
    fi

    # 清理日志
    clean_log

    # 杀死超时任务
    kill_task

    # 调度时间间隔任务
    log_fn schedule_interval_task

    # 调度就绪任务
    log_fn schedule_ready_task
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

# 打印用法
function print_usage()
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
                print_usage
                exit 1;;
        esac
    done

    # 出错立即退出
    set -e

    # 创建日志文件目录
    mkdir -p $SCHED_LOG_DIR
    log_file=$SCHED_LOG_DIR/task_scheduler.log

    if [[ "$RUN_MODE" = "$RUN_MODE_LOOP" ]]; then
        info "Script will execute periodically"

        while [[ "$RUN_MODE" = "$RUN_MODE_LOOP" ]]; do
            execute >> $log_file 2>&1

            roll_log

            if [[ "$RUN_MODE" != "$RUN_MODE_LOOP" ]]; then
                break
            fi

            info "$0 sleep for $TASK_SCHEDULE_INTERVAL"
            sleep $TASK_SCHEDULE_INTERVAL
            info "$0 wake up"
        done
    else
        info "Script will execute one time and exit"

        execute
    fi
}
main "$@"