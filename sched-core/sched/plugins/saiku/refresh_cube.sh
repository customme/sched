#!/bin/bash
#
# Date: 2018-01-15
# Author: superz
# Description: 模拟saiku刷新Cube
# 环境变量:
#   SCHED_HOME    调度系统家目录
# 调度系统变量
#   log_path           任务日志目录
# 任务扩展属性:
#   src_db_id          saiku连接id
#   saiku_path         saiku服务路径
#   saiku_version      saiku版本(2.x/3.x)

BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile


# 获取源数据库连接
function get_src_db()
{
    if [[ -z "$src_db_id" ]]; then
        error "Empty source database id"
        return 1
    fi

    debug "Get source database by id: $src_db_id"
    src_db=($(get_db $src_db_id))
    if [[ -z "${src_db[@]}" ]]; then
        error "Can not find source database by id: $src_db_id"
        return 1
    fi
    debug "Got source database: ${src_db[@]}"

    # saiku连接信息
    saiku_url="http://${src_db[1]}:${src_db[2]}/$saiku_path"
    saiku_user="${src_db[3]}"
    saiku_passwd="${src_db[4]}"
    conn_name="${src_db[5]}"
    timeout=60
}

# 登录获取cookie
function login_saiku()
{
    login_url=$saiku_url/session

    curl -s --connect-timeout $timeout -c $log_path/cookie.tmp -d "username=$saiku_user&password=$saiku_passwd" $login_url

    # 判断cookie是否获取成功
    if [[ ! -s $log_path/cookie.tmp ]]; then
        error "Log into saiku failed"
        return 1
    fi
}

function execute()
{
    # 获取源数据库连接信息
    get_src_db

    # 登录获取cookie
    log_task $LOG_LEVEL_INFO "Log into saiku and get cookie"
    login_saiku

    # 刷新Cube
    log_task $LOG_LEVEL_INFO "Refresh cube"
    if [[ $saiku_version =~ 3 ]]; then
        refresh_url=$saiku_url/admin/datasources/${conn_name}/refresh?_=`date +%s`
    else
        refresh_url=$saiku_url/$saiku_user/discover/$conn_name/refresh?_=`date +%s`
    fi
    http_code=`curl -s -w %{http_code} --connect-timeout $timeout -b $log_path/cookie.tmp -o $log_path/output.tmp $refresh_url`
    if [[ ! "$http_code" =~ ^200|30[0-9]$ ]]; then
        error "Refresh cube failed, saiku server return http code: $http_code"
        exit 1
    fi
}

source $SCHED_HOME/plugins/task_executor.sh