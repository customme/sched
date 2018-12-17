#!/bin/bash
#
# Date: 2015-09-26
# Author: superz
# Description: 本地文件上传到hdfs
# 环境变量:
#   SCHED_HOME    调度系统家目录
# 调度系统变量
#   log_path           任务日志目录
# 任务扩展属性:
#   src_dir      源文件目录
#   src_file     源文件名(默认为*)
#   tar_dir      目标文件目录
#   hdfs_user    hdfs用户(默认为hdfs)
#   min_count    最小记录数


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile


# 执行hdfs命令
function exec_hdfs()
{
    local run_cmd="$1"

    if [[ `whoami` = $hdfs_user ]]; then
        $run_cmd
    elif [[ $UID -eq 0 ]]; then
        su -l $hdfs_user -c "$run_cmd"
    else
        sudo su -l $hdfs_user -c "$run_cmd"
    fi
}

function execute()
{
    # hdfs用户
    hdfs_user=${hdfs_user:-hdfs}

    # 最小记录数
    if [[ -n "$min_count" ]]; then
        # 检测数据行数
        info "Check data amount"
        local row_count=`find $src_dir -maxdepth 1 -type f -name "${src_file:-*}" | xargs -r cat | awk -F '\t' '{
            print $"'$time_index'"
        }' | grep "$prev_day1 $the_hour" | wc -l`

        if [[ $row_count -lt $min_count ]]; then
            error "Can not fetch enough data, expected minimum row count: $min_count, but got: $row_count"
            # 短信告警
            if [[ $is_alarm -gt 0 && $alarm_way -gt 0 && -n "$sub_mobiles" ]]; then
                echo "从数据源：$src_dir/$src_file获取不到足够数据，预期最小行数：$min_count，实际行数：$row_count" > $log_path/sms.tmp
            fi
            return 1
        fi
    fi

    # 创建目标文件目录
    info "Create target file directory: $tar_dir"
    exec_hdfs "hdfs dfs -mkdir -p $tar_dir"

    # 上传
    info "Upload file to hdfs"
    find $src_dir -maxdepth 1 -type f -name "${src_file:-*}" | xargs -r ls -cr | while read file_name; do
        debug "Upload file: $file_name"
        exec_hdfs "hdfs dfs -put -f $file_name $tar_dir" || return $?
    done
}

source $SCHED_HOME/plugins/task_executor.sh