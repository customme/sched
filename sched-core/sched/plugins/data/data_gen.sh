#!/bin/bash
#
# Date: 2018-10-21
# Author: superz
# Description: 生成数据(Android ID/新增用户/活跃用户/访问日志/广告展示、点击、激活日志)
# 环境变量:
#   ETL_HOME    etl程序家目录
# 调度系统变量
#   log_path    任务日志目录
#   prev_day    run_time前一天
# 任务扩展属性:
#   data_type       生成数据类型(aid:Android ID,new:新增用户,active:活跃用户,visit:访问日志,ad:广告展示、点击、激活日志)
#   script_dir      数据生成脚本目录
#   product_code    产品编码
# 任务实例参数:
#   start_date    开始日期
#   end_date      结束日期
#   number        Android ID个数
#   rate0         60~日留存
#   rand0         留存占比浮动值


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile


function execute()
{
    # 数据生成脚本目录
    script_dir=${script_dir:-$ETL_HOME/data-gen}

    # 开始日期
    start_date=`awk -F '=' '$1 == "start_date" {print $2}' $log_path/run_params`
    start_date=${start_date:-$prev_day}
    # 结束日期
    end_date=`awk -F '=' '$1 == "end_date" {print $2}' $log_path/run_params`
    end_date=${end_date:-$start_date}

    case "$data_type" in
        aid)
            # Android ID个数
            number=`awk -F '=' '$1 == "number" {print $2}' $log_path/run_params`
            # 生成Android ID
            log_task $LOG_LEVEL_INFO "Invoke script: sh $script_dir/gen_aid.sh -n $number"
            sh $script_dir/gen_aid.sh -n $number;;
        new)
            # 生成新增用户
            log_task $LOG_LEVEL_INFO "Invoke script: sh $script_dir/gen_new.sh -g -p $product_code -d $start_date,$end_date -la"
            sh $script_dir/gen_new.sh -g -p $product_code -d $start_date,$end_date -la;;
        active)
            # 60~日留存
            rate0=`awk -F '=' '$1 == "rate0" {print $2}' $log_path/run_params`
            if [[ -n "$rate0" ]]; then
                extras="-r $rate0 "
            fi
            # 留存占比浮动值
            rand0=`awk -F '=' '$1 == "rand0" {print $2}' $log_path/run_params`
            if [[ -n "$rand0" ]]; then
                extras="${extras}-f $rand0"
            fi
            # 生成活跃用户
            log_task $LOG_LEVEL_INFO "Invoke script: sh $script_dir/gen_active.sh -g -p $product_code -d $start_date,$end_date -la $extras"
            sh $script_dir/gen_active.sh -g -p $product_code -d $start_date,$end_date -la $extras;;
        visit)
            # 生成访问日志
            log_task $LOG_LEVEL_INFO "Invoke script: sh $script_dir/gen_visit.sh -g -p $product_code -d $start_date,$end_date -s"
            sh $script_dir/gen_visit.sh -g -p $product_code -d $start_date,$end_date -s;;
        ad)
            # 生成广告展示、点击、激活日志
            log_task $LOG_LEVEL_INFO "Invoke script: sh $script_dir/gen_ad.sh -ag -d $start_date,$end_date -sl"
            sh $script_dir/gen_ad.sh -ag -d $start_date,$end_date -sl;;
        *)
            log_task $LOG_LEVEL_ERROR "Unsupported data type: $data_type"
            return 1;;
    esac
}

source $SCHED_HOME/plugins/task_executor.sh