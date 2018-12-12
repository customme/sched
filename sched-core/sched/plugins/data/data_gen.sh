#!/bin/bash
#
# 生成数据


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile


function execute()
{
    # 数据生成脚本基目录
    base_dir=${base_dir:-$ETL_HOME/data-gen}

    # 解析运行时参数
    number=`awk -F '=' '$1 == "number" {print $2}' $log_path/run_params`
    start_date=`awk -F '=' '$1 == "start_date" {print $2}' $log_path/run_params`
    start_date=${start_date:-${run_time:0:8}}
    end_date=`awk -F '=' '$1 == "end_date" {print $2}' $log_path/run_params`
    end_date=${end_date:-$start_date}
    rate0=`awk -F '=' '$1 == "rate0" {print $2}' $log_path/run_params`
    rand0=`awk -F '=' '$1 == "rand0" {print $2}' $log_path/run_params`

    case "$data_type" in
        aid)
            # 生成Android ID
            log_task $LOG_LEVEL_INFO "Invoke script: sh $base_dir/gen_aid.sh -n $number"
            sh $base_dir/gen_aid.sh -n $number;;
        new)
            # 生成新增
            log_task $LOG_LEVEL_INFO "Invoke script: sh $base_dir/gen_new.sh -g -p $product_code -d $start_date,$end_date -la"
            sh $base_dir/gen_new.sh -g -p $product_code -d $start_date,$end_date -la;;
        active)
            # 60~日留存
            if [[ -n "$rate0" ]]; then
                extras="-r $rate0 "
            fi
            # 留存占比浮动值
            if [[ -n "$rand0" ]]; then
                extras="${extras}-f $rand0"
            fi
            # 生成活跃
            log_task $LOG_LEVEL_INFO "Invoke script: sh $base_dir/gen_active.sh -g -p $product_code -d $start_date,$end_date -la $extras"
            sh $base_dir/gen_active.sh -g -p $product_code -d $start_date,$end_date -la $extras;;
        visit)
            # 生成访问日志
            log_task $LOG_LEVEL_INFO "Invoke script: sh $base_dir/gen_visit.sh -g -p $product_code -d $start_date,$end_date"
            sh $base_dir/gen_visit.sh -g -p $product_code -d $start_date,$end_date;;
        ad)
            # 生成广告展示、点击、激活日志
            log_task $LOG_LEVEL_INFO "Invoke script: sh $base_dir/gen_ad.sh -ag -d $start_date,$end_date -sl"
            sh $base_dir/gen_ad.sh -ag -d $start_date,$end_date -sl;;
        *)
            log_task $LOG_LEVEL_ERROR "Unsupported task type: $type"
            return 1;;
    esac
}

source $SCHED_HOME/plugins/task_executor.sh