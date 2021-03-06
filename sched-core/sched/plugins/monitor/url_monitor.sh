#!/bin/bash
#
# Date: 2018-01-15
# Author: superz
# Description: url监控告警
# 环境变量:
#   SCHED_HOME    调度系统家目录
# 调度系统变量
#   log_path           任务日志目录
# 任务扩展属性:
#   src_urls     待监控地址(格式为:名称 地址)
#   try_times    尝试次数


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile


# 检测url是否可访问
# 200 成功
# 30x 重定向
function check_url()
{
    info "Check $name url: $url"
    tried_times=1
    rm -f $log_path/response.tmp
    response=($(curl --connect-timeout 10 -m 20 -o $log_path/response.tmp -s -w "%{http_code} %{time_connect} %{time_starttransfer} %{time_total}" "$url"))
    while [[ ! "${response[0]}" =~ ^200|30[0-9]$ && $tried_times -lt $try_times ]]; do
        tried_times=`expr $tried_times + 1`
        debug "Current try times: $tried_times"
        rm -f $log_path/response.tmp
        response=($(curl --connect-timeout 10 -m 20 -o $log_path/response.tmp -s -w "%{http_code} %{time_connect} %{time_starttransfer} %{time_total}" "$url"))
    done

    # http状态码判断
    if [[ "${response[0]}" =~ ^200|30[0-9]$ ]]; then
        info "$name url: $url is reachable, http_code: ${response[0]}, time_connect: ${response[1]}, time_starttransfer: ${response[2]}, time_total: ${response[3]}"
    else
        # 邮件告警内容
        if [[ -s $log_path/response.tmp ]]; then
            cat $log_path/response.tmp >> $log_path/mail_content.tmp
        else
            echo "Error accessing url $name: $url, http status code: ${response[0]}" | tee -a $log_path/mail_content.tmp | xargs -r -I {} echo `date +'%F %T'`" ERROR [ "{}" ]" >&2
        fi

        # 短信告警内容
        echo "访问${name}出错: $url, 状态码: ${response[0]}" >> $log_path/sms_content.tmp
    fi
}

# 发送告警
function send_alarm()
{
    # 发送电子邮件
    if [[ -s $log_path/mail_content.tmp ]]; then
        if [[ -n "$sub_emails" ]]; then
            mail_subject="URL访问异常"
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
    # 获取urls
    debug "Get urls"
    echo -e `get_prop_value $task_id src_urls` > $log_path/src_urls.tmp
    dos2unix -q $log_path/src_urls.tmp

    # 尝试次数
    try_times=${try_times:-1}

    debug "Check urls one by one"
    # 出错不要立即退出
    set +e
    while read name url; do
        check_url
    done < $log_path/src_urls.tmp
    # 出错立即退出
    set -e

    # 发送告警
    send_alarm
}

source $SCHED_HOME/plugins/task_executor.sh