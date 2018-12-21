#!/bin/bash
#
# mysql分区表自动创建删除分区


# 分区表
TABLES="ods_device_visitlog"

# 保留几个分区
KEEP_NUM=5


# 数据库连接信息
MYSQL_HOST=10.10.10.182
MYSQL_PORT=3316
MYSQL_USER=dba_ops
MYSQL_PASSWD=R2pqIYIfjAhWT6ar
MYSQL_DB=jz_ums


# 执行sql
function exec_sql()
{
    local sql="${1:-`cat`}"
    local params="${2:--s -N --local-infile}"

    echo "$sql" | mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASSWD $MYSQL_DB $params
}

# 创建/删除分区
function partition()
{
    if [[ $# -lt 1 ]]; then
        echo "错误: 请输入表名"
        return 1
    fi

    table="$1"
    the_date=${2:-`date +%Y%m%d -d "1 day ago"`}

    week_num=`date +%w -d "$the_date"`
    if [[ $week_num -ne 1 ]]; then
        echo "错误: 日期必须是周一"
        return 1
    fi

    next_week=`date +%Y%m%d -d "$the_date 1 week"`
    echo "ALTER TABLE $table ADD PARTITION (PARTITION p$the_date VALUES LESS THAN(TO_DAYS($next_week)));" | exec_sql

    delete_week=`date +%Y%m%d -d "$the_date $KEEP_NUM week ago"`
    echo "ALTER TABLE $table DROP PARTITION p$delete_week;" | exec_sql
}

# 初始化
function init()
{
    partition ods_device_visitlog 20181217
}

function main()
{
    echo "$TABLES" | while read table; do
        partition $table
    done
}
main "$@"