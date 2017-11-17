#!/bin/bash

# 定时器


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $SHELL_HOME/common/include.sh


# 捕捉kill信号
trap 'warn "$0 is killed, pid: $$, script will exit soon";timeout=-1' TERM


# 执行操作
function execute()
{
    # 开始时间
    begin_time=$(date +%s)
    for ((;;)); do
        # 执行命令
        $cmd

        # 判断是否被kill
        if [[ $timeout -eq -1 ]]; then
            warn "$0 is killed, pid: $$, script will exit";
            exit 1
        fi

        # 结束时间
        end_time=$(date +%s)

        # 判断是否超时
        time_diff=$((end_time - begin_time + interval))
        if [[ $time_diff -ge $timeout ]]; then
            info "Time is up, $0 will exit"
            exit
        fi

        # 休眠
        sleep $interval

        # 唤醒后判断是否被kill
        if [[ $timeout -eq -1 ]]; then
            warn "$0 is killed, pid: $$, script will exit";
            exit 1
        fi
    done
}

function main()
{
    info "Current working directory: $BASE_DIR, invoke script: $0 $@"

    # 参数判断
    if [[ $# -lt 2 ]]; then
        error "Invalid arguments: $@, usage: $0 <cmd> <interval> [timeout]"
        exit 1
    fi

    # 出错立即退出
    set -e

    # 要执行的命令
    cmd="$1"
    # 执行频率（单位为秒）
    interval="$2"
    # 多久超时（单位为秒，默认超时时间为一年）
    timeout="${3:-31536000}"

    execute
}
main "$@"