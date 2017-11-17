#!/bin/bash
#
# 任务工具类


# 执行sql
# Globals:
# Arguments:
# Returns:
function execute_sql()
{
    local sql="$1"
    if [ -z "$sql" ]; then
        sql=`cat`
    fi

    echo "$sql" | mysql -h172.17.210.180 -udc_scheduler_cli -pdc_scheduler_cli dc_scheduler_client -s -N
}

# 表头表体
# Globals:
# Arguments:
# Returns:
function dtl_helper()
{
    execute_sql "SELECT id,schema_name,table_name FROM t_task WHERE table_name LIKE '%_dtl';" | while read id schema_name table_name; do
        echo "select $id,'$table_name',a.table_name,b.incr_columns from t_task a inner join t_task_config b on a.schema_name=b.schema_name and a.table_name=b.table_name and a.schema_name='$schema_name' and a.table_name='${table_name%_*}' and b.incr_columns > '';"
    done | execute_sql | while read id dtl header incrs; do
        sql="SELECT a.* FROM $dtl a INNER JOIN $header b ON a.bill_no = b.bill_no"
        incr_columns=`echo "$incrs" | sed 's/^/b./;s/,/,b./'`
        echo "update t_task set incr_columns='$incr_columns',query_sql='$sql' where id=$id;"
    done | execute_sql
}
