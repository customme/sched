#!/bin/bash
#
# 数据同步插件模板
#
# 步骤:
# 1 获取源数据库连接
# 2 获取目标数据库连接
# 3 同步数据


source $SCHED_HOME/plugins/db_util.sh


# 检查条件
function check_cond()
{
    # 最小记录数
    if [[ $min_count -gt 0 ]]; then
        # 总记录数
        debug "Get data count"
        local total_count=$(execute_src "SELECT COUNT(*) FROM $src_table WHERE 1 = 1 $src_filter")
        debug "Got data count: $total_count"
        if [[ -z "$total_count" ]]; then
            return 1
        fi
        if [[ $total_count -lt $min_count ]]; then
            error "Can not fetch enough data, expected minimum row count: $min_count, but got: $total_count"
            # 短信告警
            if [[ $is_alarm -gt 0 && $alarm_way -gt 0 && -n "$sub_mobiles" ]]; then
                echo "从服务器：${src_db[1]}，数据库：${src_db[5]}，表：${src_table}，不能获取足够的数据，预期最小行数为：$min_count，但只得到：$total_count" > $log_path/sms.tmp
            fi
            return 1
        fi
    fi
}

# 同步页
function sync_page()
{
    # 抽取数据
    log_task $LOG_LEVEL_INFO "Extract data from source table: $src_table, page: $page_no"
    get_data || return $?

    # 装载数据
    log_task $LOG_LEVEL_INFO "Load data to target table: $tar_table, page: $page_no"
    load_data
}

# 同步数据
# 步骤:
# 1、构造时间增量条件
# 2、解析表名
# 3、创建表
# 4、预装载数据
# 5、获取数据
# 6、装载数据
function sync_data()
{
    # 获取业务时间
    biz_date=$(get_biz_date $run_time $task_cycle)

    # 构建过滤条件
    build_filter
    log_task $LOG_LEVEL_INFO "Got time incremental conditions: $src_filter"

    # 解析表名
    log_task $LOG_LEVEL_INFO "Parse table: $src_table_name"
    for src_table in `table_parser "$src_table_name" $src_table_type`; do
        # 目标表名
        tar_table=${tar_table_name:-$src_table}

        # 检查条件
        debug "Check data"
        check_cond || return $?

        # 创建目标表
        debug "Build target table: $tar_table"
        build_table || return $?

        # 预装载数据
        debug "Preload data"
        preload || return $?

        # 同步表
        log_task $LOG_LEVEL_INFO "Synchronize data from source table: $src_table to target table: $tar_table"
        sync_table || return $?
    done
}

function execute()
{
    # 获取源数据库连接
    get_src_db

    # 获取目标数据库连接
    get_tar_db

    # 同步数据
    log_task $LOG_LEVEL_INFO "Synchronize data begin"
    sync_data
    log_task $LOG_LEVEL_INFO "Synchronize data end"
}

source $SCHED_HOME/plugins/task_executor.sh