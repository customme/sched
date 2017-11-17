#!/bin/bash
#
# 任务公共脚本


# 执行sql语句
function execute_meta()
{
    local sql="$1"
    if [ -z "$sql" ]; then
        sql=`cat`
    fi

    [[ "$SQL_LOG" = "on" ]] && log "$sql" >> $SQL_LOG_DIR/sql_$(date +%Y%m%d).log

    echo "$sql" | mysql -h $META_DB_HOST -u $META_DB_USER -p$META_DB_PASS -D $META_DB_NAME --default-character-set=$META_DB_CHARSET $META_DB_PARAMS
}
