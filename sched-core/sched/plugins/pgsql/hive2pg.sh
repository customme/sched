#!/bin/bash
#
# hive到postgresql数据同步插件


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source $SHELL_HOME/common/include.sh
source $SHELL_HOME/common/date_util.sh
source $SHELL_HOME/common/db/mysql/mysql_util.sh
source $SHELL_HOME/common/db/postgresql/hive2pg.sh
source $SCHED_HOME/common/task_util.sh
source $SCHED_HOME/plugins/data_sync.sh


# 获取数据源
function get_src_db()
{
    # 获取源数据库信息
    debug "Get source database connection by src_db_id: $src_db_id"
    src_db=($(get_db $src_db_id))
    debug "Got source database connection: ${src_db[@]}"
    # 源数据库连接字符串
    src_db_url=$(make_hive_url "${src_db[5]}")
    debug "Source database connection url: $src_db_url"
    # 源数据库编码
    src_db_charset=${src_db[6]}
}

# 获取数据目标
function get_tar_db()
{
    # 获取目标数据库信息
    debug "Get target database connection by tar_db_id: $tar_db_id"
    tar_db=($(get_db $tar_db_id))
    debug "Got target database connection: ${tar_db[@]}"
    # 目标数据库连接字符串
    tar_db_url=$(make_pg_url "${tar_db[1]}" "${tar_db[3]}" "${tar_db[4]}" "${tar_db[5]}" "${tar_db[2]}")
    debug "Target database connection url: $tar_db_url"
    # 数据库编码
    tar_db_charset=${tar_db[6]}
}

# 构建过滤条件
function build_filter()
{
    # 拼接增量条件
    debug "Check incremental time columns"
    if [[ -n "$src_time_columns" ]]; then
        local f_prev_day=`format_time $prev_day`
        local f_the_day=`format_time $the_day`
        time_filter=`echo "$src_time_columns" | awk -F"," '{
            for(i=1;i<=NF;i++){
                printf("( %s >= '\''%s'\'' AND %s < '\''%s'\'' ) OR ",$i,f_prev_day,$i,f_the_day)
            }
        }' f_prev_day="$f_prev_day" f_the_day="$f_the_day" | sed 's/ OR $//'`
        debug "Got incremental conditions: $time_filter"
        src_filter="AND ( $time_filter ) $src_filter"
        debug "All conditions: $src_filter"
    fi
}

function main()
{
    debug "Current base directory: $BASE_DIR, begin invoke shell: $0 $@"

    task_id="$1"
    run_time="$2"
    task_cycle="$3"

    # 开始执行
    execute
}
main "$@"
