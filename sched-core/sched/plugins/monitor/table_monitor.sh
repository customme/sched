#!/bin/bash
#
# 表监控告警


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $SHELL_HOME/common/db/mysql/mysql2mysql.sh


# 检测表是否有数据
function check_table()
{
    # 总记录数
    local total_count=$(execute_src "SELECT COUNT(*) FROM $src_table WHERE 1 = 1 $src_filter")
    if [[ $total_count -lt $min_row_count ]]; then
        error "Can not fetch enough data, expected minimum row count: $min_row_count, but got: $total_count"
        # 短信告警
        if [[ $is_alarm -gt 0 && $alarm_way -gt 0 && -n "$sub_mobiles" ]]; then
            echo "从服务器：${src_db[1]}，数据库：${src_db[5]}，表：${src_table}，不能获取足够的数据，预期最小行数为：$min_row_count，但只得到：$total_count" > $log_path/sms.tmp
        fi
        return 1
    fi
}

# 发送告警
function send_alarm()
{
    # 发送电子邮件
    if [[ -s $log_path/mail_content.tmp ]]; then
        if [[ -n "$sub_emails" ]]; then
            mail_subject="数据异常"
            mail_content=`awk '{printf("%s<BR/>",$0)}' $log_path/mail_content.tmp`
            $SHELL_HOME/common/mail_sender.py "$sub_emails" "$mail_subject" "$mail_content"
        else
            warn "There is no email subscribers"
        fi
    else
        info "Everything seems ok"
    fi

    # 发送手机短信
    if [[ -s $log_path/sms_content.tmp ]]; then
        if [[ -n "$sub_mobiles" ]]; then
            sms_content=`cat $log_path/sms_content.tmp`
            $SHELL_HOME/common/sms_sender.sh "$sub_mobiles" "$sms_content"
        else
            warn "There is no sms subscribers"
        fi
    else
        info "Everything seems ok"
    fi
}

function execute()
{
    # 获取源数据库连接
    get_src_db

    # 获取任务上次运行周期
    the_time=$(format_time $run_time)
    local last_cycle=$(get_next_cycle $run_time $task_cycle ago)
    prev_time=$(format_time $last_cycle)

    if [[ -n "$src_time_columns" ]]; then
        time_filter=`echo "$src_time_columns" | awk -F"," '{
            for(i=1;i<=NF;i++){
                printf("( %s >= '\''%s'\'' AND %s < '\''%s'\'' ) OR ",$i,prev_time,$i,the_time)
            }
        }' the_time="$the_time" prev_time="$prev_time" is_first=$is_first | sed 's/ OR $//'`
        debug "Got time incremental conditions: $time_filter"
        src_filter="AND ( $time_filter ) $src_filter"
    else
        warn "There is no time columns"
    fi

    # 最小记录数
    min_row_count=${min_row_count:-1}

    # 出错不要立即退出
    set +e
    debug "Check tables one by one"
    for src_table in ${src_tables//,/ }; do
        check_table
    done
    # 出错立即退出
    set -e

    # 发送告警
    send_alarm
}

source $SCHED_HOME/plugins/task_executor.sh