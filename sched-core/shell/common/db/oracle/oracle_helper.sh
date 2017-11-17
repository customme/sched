#!/bin/bash
#
# oracle元数据整理工具


#元数据库
meta_db_host=172.17.210.180
meta_db_port=3306
meta_db_user=dc_scheduler_cli
meta_db_pass=dc_scheduler_cli
meta_db_name=dc_scheduler_client
meta_db_charset=utf8

# 待查找的数据库（$host $port $user $password $db $charset）
SERVERS="172.17.17.81 1521 u_sd_bl belle DEVZBSHOES utf8"


#执行sql语句
function execute_meta()
{
    local sql="$1"

    if [ -z "$sql" ]
    then
        cat | mysql -h $meta_db_host -u $meta_db_user -p$meta_db_pass -P$meta_db_port -D $meta_db_name --default-character-set=$meta_db_charset -s -N --local-infile
    else
        echo "$sql" | mysql -h $meta_db_host -u $meta_db_user -p$meta_db_pass -P$meta_db_port -D $meta_db_name --default-character-set=$meta_db_charset -s -N --local-infile
    fi
}

#oracle sql执行器
function oracle_executor()
{
    local sql="$1"

    if [ -z "$sql" ]; then
        sql=`cat`
    fi

    sqlplus -S -L /nolog << EOF
    connect $src_db_user/$src_db_pass@$src_db_host:$src_db_port/$src_db_name
    set echo off;
    set feedback off;
    set heading off;
    set wrap off;
    set pagesize 0;
    set linesize 10000;
    set numwidth 16;
    set termout off;
    set timing off;
    set trimout on;
    set trimspool on;
    set colsep'|||';
    $sql
    commit;
    quit
EOF
}

#格式化输出
#1、去掉两边空格
#2、把空字符串替换成NULL
#3、输出分隔符改为\t
function format_data()
{
  awk -F '\\|\\|\\|' '{
    for(i=1;i<NF;i++){
      gsub(/^[[:space:]]*/,"",$i);
      gsub(/[[:space:]]*$/,"",$i);
      gsub(/^$/,"NULL",$i);
      printf("%s\t",$i)
    }
    gsub(/^[[:space:]]*/,"",$NF);
    gsub(/[[:space:]]*$/,"",$NF);
    gsub(/^$/,"NULL",$NF);
    printf("%s\n",$NF)
  }'
}

# 获取表信息
# Globals:
# Arguments:
# Returns:
function find_tables()
{
    oracle_executor "SELECT TABLE_NAME,COMMENTS FROM all_tab_comments WHERE OWNER=upper('$src_db_owner') AND TABLE_TYPE='TABLE';" | format_data | while read table_name comments; do
        table_rows=`oracle_executor "SELECT count(1) FROM $src_db_owner.$table_name;"`
        echo "replace into meta_tables values('$src_db_host','$src_db_owner.$src_db_name','$table_name',$table_rows,null,'$comments');"
    done | execute_meta
}

# 获取字段信息
# Globals:
# Arguments:
# Returns:
function find_columns()
{
    oracle_executor "SELECT a.table_name,
        a.column_name,
        a.data_type,
        a.data_length,
        a.data_precision,
        a.data_scale,
        b.comments
        FROM all_tab_columns a
        LEFT JOIN all_col_comments b
        ON a.owner = b.owner
        AND a.table_name = b.table_name
        AND a.column_name = b.column_name
        WHERE a.owner = upper('$src_db_owner')
    ;" | format_data | awk -F '\t' 'BEGIN{
        OFS=FS
        IGNORECASE=1
    }{
        if($3 == "NUMBER"){
            column_type="NUMBER("$5","$6")"
        }else if($3 ~ /CHAR|CLOB/){
            column_type=$3"("$4")"
        }else if($3 == "DATE"){
            column_type="DATE"
        }
        print host,db,$1,$2,column_type,"YES","NULL",$7
    }' host="$src_db_host" db="${src_db_owner}.${src_db_name}" > columns.txt

    execute_meta "load data local infile 'columns.txt' replace into table meta_columns;"
}

# 查找所有
# Globals:
# Arguments:
# Returns:
function find_all()
{
    echo "$SERVERS" | grep -v "#" | while read src_db_host src_db_port src_db_user src_db_pass src_db_name src_db_charset; do
        src_db_owner=$src_db_user
        if [[ "$src_db_name" =~ "." ]]; then
            src_db_owner=${src_db_name%.*}
            src_db_name=${src_db_name##*.}
        fi

        find_tables
        find_columns
    done
}

# 
# Globals:
# Arguments:
# Returns:
function main()
{
    find_all
}
main "$@"
