#!/bin/bash
#
# 任务运行器
# 1、调用任务执行器执行任务
# 2、获取任务执行状态并更新
# 3、发送电子邮件、手机短信告警
#
# 注意:
# 1、任务执行器必须放在$SCHED_HOME/plugins目录下


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
trap 'kill_task' TERM


# 发送告警
function send_alarm()
{
    # 发送电子邮件
    if [[ -n "$sub_emails" ]]; then
        info "Send email notification to: $sub_emails"
        echo "$mail_content" | $SHELL_HOME/common/mail_sender.py "$sub_emails" "$mail_subject"
    fi

    # 发送手机短信
    if [[ -n "$sub_mobiles" ]]; then
        info "Send sms notification to: $sub_mobiles"
        echo "$sms_content" | $SHELL_HOME/common/sms_sender.sh "$sub_mobiles"
    fi
}

# 任务成功
function succeed_task()
{
    # 告警、成功告警
    if [[ $is_alarm -eq 1 || $is_alarm -eq 2 ]]; then
        # 电子邮件
        if [[ -s $log_path/mail.tmp ]]; then
            mail_subject=`head -n 1 $log_path/mail.tmp`
            mail_content=`sed '1 d' $log_path/mail.tmp`
        else
            mail_subject="任务: ($task_id, $run_time) 执行成功"
            mail_content=`awk '{printf("%s<br/>",$0)}' $log_path/task.info`
        fi

        # 手机短信
        if [[ -s $log_path/sms.tmp ]]; then
            sms_content=`cat $log_path/sms.tmp`
        else
            sms_content="任务: ($task_id, $run_time) 执行成功"
        fi

        # 发送告警
        send_alarm
    fi
}

# 任务失败
function fail_task()
{
    if [[ $last_try -eq 1 ]]; then
        # 告警、失败告警
        if [[ $is_alarm -eq 1 || $is_alarm -eq 3 ]]; then
            # 电子邮件
            if [[ -s $log_path/mail.tmp ]]; then
                mail_subject=`head -n 1 $log_path/mail.tmp`
                mail_content=`sed '1 d' $log_path/mail.tmp`
            else
                mail_subject="任务: ($task_id, $run_time) 执行失败"
                mail_content=`awk '{printf("%s<br/>",$0)}' $log_path/task.info $log_path/task.error`
            fi

            # 手机短信
            if [[ -s $log_path/sms.tmp ]]; then
                sms_content=`cat $log_path/sms.tmp`
            elif [[ -s $log_path/task.error ]]; then
                sms_content="任务: ($task_id, $run_time) 执行失败, "`tail -n 1 $log_path/task.error | sed 's/^.* \[ \(.*\) \]$/\1/'`
            else
                sms_content="$mail_subject"
            fi

            # 发送告警
            send_alarm
        fi
    else
        debug "The try does not reach the maximum"
    fi
}

# 更新任务
function update_task()
{
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
        error "Update task state failed (task_id, run_time) ($task_id, $run_time)"
    fi
}

# 杀死任务
function kill_task()
{
    log_task $LOG_LEVEL_INFO "Task: (task_id, run_time) ($task_id, $run_time) is killed"
    task_state=$TASK_STATE_KILLED
    fail_task
    update_task
}

function main()
{
    info "Current working directory: $BASE_DIR, invoke script: $0 $@"

    # 参数判断
    if [[ $# -lt 2 ]]; then
        error "Invalid arguments: $@, usage: $0 <task id> <run time>"
        exit 1
    fi

    task_id="$1"
    run_time="$2"
    last_try="${3:-0}"

    # 流水号
    seq_no=$(date +'%s')

    # 判断任务是否存在且正常
    info "Check if exists valid task: $task_id"
    if [[ $(exists_task $task_id) -eq 0 ]]; then
        log_task $LOG_LEVEL_ERROR "Can not find valid task by id: $task_id"
        task_state=$TASK_STATE_FAILED
        fail_task
        update_task
        exit 1
    fi

    # 任务运行器
    info "Get task executor"
    task_executor=$(get_task_executor $task_id)
    if [[ -z "$task_executor" ]]; then
        log_task $LOG_LEVEL_ERROR "Can not find task executor for task: $task_id"
        task_state=$TASK_STATE_FAILED
        fail_task
        update_task
        exit 1
    fi

    # 告警
    debug "Get alarm switch"
    is_alarm=$(get_prop_value $task_id is_alarm)
    is_alarm=${is_alarm/NULL/0}
    if [[ $is_alarm -gt 0 ]]; then
        debug "Alarm switch is on"
        # 告警方式
        alarm_way=$(get_prop_value $task_id alarm_way)
        if [[ $alarm_way -eq 0 ]]; then
            sub_emails=$(get_prop_value $task_id sub_emails)
        elif [[ $alarm_way -eq 1 ]]; then
            sub_mobiles=$(get_prop_value $task_id sub_mobiles)
        elif [[ $alarm_way -eq 2 ]]; then
            sub_emails=$(get_prop_value $task_id sub_emails)
            sub_mobiles=$(get_prop_value $task_id sub_mobiles)
        else
            warn "Unsupported alarm way: $alarm_way"
        fi
    else
        debug "Alarm switch is off"
    fi

    # 更新任务状态为“正在运行”
    result=$(update_task_instance $task_id $run_time "task_state = $TASK_STATE_RUNNING, start_time = NOW(), end_time = NULL")
    if [[ $result -ne 1 ]]; then
        error "Update task state failed (task_id, run_time) ($task_id, $run_time)"
        exit 1
    fi

    # 创建任务日志目录
    cur_date=$(date +%Y%m%d)
    log_path=$TASK_LOG_DIR/$cur_date/${task_id}-${run_time}
    mkdir -p $log_path

    # 启动任务
    info "Invoke task executor: $SCHED_HOME/plugins/$task_executor $task_id $run_time $seq_no > $log_path/task.info 2> $log_path/task.error"
    $SCHED_HOME/plugins/$task_executor $task_id $run_time $seq_no > $log_path/task.info 2> $log_path/task.error
    status=$?

    # 删除mysql警告日志
    sed -i '/.*password.*command.*insecure/d' $log_path/task.error

    # 判断任务执行结果
    if [[ $status -eq 0 ]]; then
        log_task $LOG_LEVEL_INFO "Task: (task_id, run_time) ($task_id, $run_time) done successfully"
        task_state=$TASK_STATE_SUCCESS
        succeed_task
    else
        log_task $LOG_LEVEL_ERROR `sed 's/^.* \[ \(.*\) \]$/\1/' $log_path/task.error | awk '{printf("%s\\\n",$0)}'`
        task_state=$TASK_STATE_FAILED
        fail_task
    fi

    # 更新任务，状态、结束时间
    update_task
}
main "$@"