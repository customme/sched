#!/bin/bash
#
# 常用工具

# 记录日志
function log()
{
    echo "$(date +'%Y-%m-%d %H:%M:%S') INFO [$@]"
}

# 记录日志到错误输出
function err()
{
    echo "$(date +'%Y-%m-%d %H:%M:%S') ERROR [$@]" >&2
}

# 在方法执行前后记录日志
function log_fn()
{
    echo "$(date +'%Y-%m-%d %H:%M:%S') [$@] begin"
    $@ || return $?
    echo "$(date +'%Y-%m-%d %H:%M:%S') [$@] end"
}

# hive转义特殊字符
function hive_escape()
{
    sed "s/\('\|;\)/\\\\\1/g"
}

# 执行hive sql
function hive_executor()
{
    local sql="$1"
    if [ -z "$sql" ]; then
        sql=`cat`
    fi

    [[ "$SQL_LOG" = "on" ]] && log "$sql" >> $LOG_DIR/sql.$(date +%Y-%m-%d).log

    echo "$sql" | hive -S
}
