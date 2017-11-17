#!/bin/bash

function init_config()
{
    #hive数据源
    hive_db_name=default

    #oracle数据目标
    oracle_db_user=usr_ho_dts_server
    oracle_db_passwd=usr_ho_dts_server
    oracle_db_name=orcl

    #sql日志目录
    sql_log_path=~/tmp
    #临时文件目录
    tmp_path=~/tmp
    #数据文件目录
    data_path=~/data

    mkdir -p $sql_log_path 2> /dev/null
    mkdir -p $tmp_path 2> /dev/null
    mkdir -p $data_path 2> /dev/null

    #测试数据量
    test_limit="limit 10000"
}

#记录日志
function log()
{
    echo `date +'%Y-%m-%d %H:%M:%S'`" $@"
}

#在方法执行前后记录日志
function log_fn()
{
    echo `date +'%Y-%m-%d %H:%M:%S'`" $@ begin"
    $@
    echo `date +'%Y-%m-%d %H:%M:%S'`" $@ end"
}

#执行hive sql
function hive_executor()
{
    local sql="$1"
    if [ -z "$sql" ]; then
        sql=`cat`
    fi

    log "$sql" >> $sql_log_path/sql.log

    hive -S --database $hive_db_name -e "$sql"
}

#格式化字段
function format_columns()
{
    sed 's/^\([^ ]*\)[[:space:]]*\([^ ]*\)[[:space:]]*\(.*\)/\1\t\2\t\3/g;s/[[:space:]]*$//g'
}

#获取表字段
function get_columns()
{
    hive_executor "desc $table_name;" | format_columns > $tmp_path/$table_name.def
}

#整型转换
function conv_int()
{
    sed 's/\t[a-z]*int\t/\tnumber\t/ig'
}

#浮点类型转换
function conv_float()
{
    sed 's/\tdouble\t/\tfloat\t/ig;s/\tdecimal\(([a-z]*)\)\t/\tnumber\1\t/ig'
}

#字符类型转换
function conv_string()
{
    sed 's/\tvarchar\(([0-9]*)\)\t/\tvarchar2\1\t/ig;s/\tstring\t/\tvarchar2(2000)\t/ig'
}

#日期类型转换
function conv_date()
{
    sed 's/\ttimestamp\t/\tdate\t/ig'
}

#数据类型转换
function conv_data_type()
{
    conv_int | conv_float | conv_string | conv_date
}

#生成建表语句
function build_create_sql()
{
    echo "CREATE TABLE $table_name("
    cat $tmp_path/$table_name.def | conv_data_type | awk -F '\t' '{
        printf("    %s %s,",$1,$2)
    }' | awk 'BEGIN{RS=","}{printf("%s,\n",$0)}' | sed '$s/,$//'
    echo ");"

    cat $tmp_path/$table_name.def | sed 's/\t[^ ]*\t/\t/g' |
    sed "s/^\([^\t]*\)[[:space:]]*\(.*\)/comment on column ${table_name}\.\1 is \'\2\';/g"
}

#创建表
function create_table()
{
    build_create_sql | tee $data_path/$table_name.ctl | oracle_executor
}

#获取字段分隔符
function get_field_separator()
{
    hive_executor "show create table $table_name;" | grep -i "FIELDS TERMINATED BY" | sed "s/.*'\(.*\)'.*/\1/"
}

#导出数据
function export_data()
{
    hive_executor "select * from $table_name $test_limit;" > $data_path/$table_name.txt
}
