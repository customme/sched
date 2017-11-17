#!/bin/bash

#数据同步通用脚本，从oracle到oracle
#功能：
#1、自动建表，支持表注释、字段注释
#2、自动按天分区
#3、按指定时间字段增量抽取

source /etc/profile
source ~/.bash_profile
export LC_ALL=C

#初始化配置信息
function initConfig()
{
  #源数据库连接
  #src_db_url="cx_xxzx/8212579@ds_db"
  src_db_url="ssfx/ssfx@ds_test"

  #目标数据库连接
  tar_db_url="ds_data/ds_data@ds_dw"

  #开启sql日志
  sql_log=on
}

#初始化时间参数
function initDate()
{
  theDay=`date +%Y%m%d`
  prevDay=`date +%Y%m%d -d "1 day ago"`
  nextDay=`date +%Y%m%d -d "1 day"`
}

#初始化目录
function initDir()
{
  if [ ! -d $theDay ]; then
    mkdir -p $theDay/ctl
    mkdir -p $theDay/tmp
    mkdir -p $theDay/log
    mkdir -p $theDay/bad
  fi

  #数据文件保留2天
  local tmpDate=`date +%Y%m%d -d "$theDay 3 days ago"`
  if [ -d $tmpDate/tmp ]; then
    rm -r $tmpDate/tmp
  fi

  #日志文件保留9天
  local logDate=`date +%Y%m%d -d "$theDay 10 days ago"`
  if [ -d $logDate ]; then
    rm -r $logDate
  fi
}

#记录日志
function log()
{
  echo `date +'%Y-%m-%d %H:%M:%S'`" $@"
}

#执行源数据库sql语句
function execute_src()
{
  local sql="$1"

  if [ -z "$sql" ]; then
    sql=`cat`
  fi

  if [ "$sql_log" = "on" ]; then
    log "sql:[$sql]" >> $theDay/log/sql.log
  fi

sqlplus -S -L /nolog << EOF
connect $src_db_url
set echo off;
set feedback off;
set heading off;
set pagesize 0;
set linesize 1000;
set numwidth 16;
set termout off;
set timing off;
set trimout on;
set trimspool on;
set colsep'|';
$sql
commit;
quit
EOF
}

#执行目标数据库sql语句
function execute_tar()
{
  local sql="$1"

  if [ -z "$sql" ]; then
    sql=`cat`
  fi

  if [ "$sql_log" = "on" ]; then
    log "sql:[$sql]" >> $theDay/log/sql.log
  fi

sqlplus -S -L /nolog << EOF
connect $tar_db_url
set echo off;
set feedback off;
set heading off;
set pagesize 0;
set linesize 1000;
set termout off;
set timing off;
set define off;
set serverout off;
$sql
commit;
quit
EOF
}

#格式化输出
#去掉两边空格
function formatOutput()
{
  awk -F"|" '{
    for(i=1;i<NF;i++){
      sub(/^[[:blank:]]*/,"",$i);
      sub(/[[:blank:]]*$/,"",$i);
      printf("%s\t",$i)
    }
    sub(/^[[:blank:]]*/,"",$NF);
    sub(/[[:blank:]]*$/,"",$NF);
    printf("%s\n",$NF)
  }'
}

#获取字段名称和字段类型
function getColumns()
{
  if [ -n "$cols" ]; then
    cols=`echo "$cols" | sed 's/^[[:blank:]]*/ /g;s/[[:blank:]]*$/ /g;s/[[:blank:]]*,[[:blank:]]*/,/g'`
  fi
  cols=`echo "$cols" | sed "s/ /\\\`/g;s/,/\\\`|\\\`/g"`

  execute_src "select '\`' || column_name || '\`',data_type,data_length,data_precision,data_scale from all_tab_columns where owner=upper('$sUser') and table_name=upper('$sTable') order by column_id asc;" |
  formatOutput | grep -Ei "$cols" | sed 's/`//ig'

  cols=`echo "$cols" | sed "s/\(^\\\`\|\\\`$\)/ /g;s/\\\`|\\\`/,/g"`
}

#获取注释
function getComments()
{
  #表注释
  execute_src "select 'comment on table $dTable is ''' || comments || ''';' from all_tab_comments where owner=upper('$sUser') and table_name=upper('$sTable');"

  if [ -n "$cols" ]; then
    cols=`echo "$cols" | sed 's/^[[:blank:]]*/ /g;s/[[:blank:]]*$/ /g;s/[[:blank:]]*,[[:blank:]]*/,/g'`
  fi
  cols=`echo "$cols" | sed "s/ /\\\`/g;s/,/\\\`|\\\`/g"`

  #字段注释
  execute_src "select 'comment on column $dTable.\`' || column_name || '\` is ''' || comments || ''';' from all_col_comments where owner=upper('$sUser') and table_name=upper('$sTable');" |
  grep -Ei "$cols" | sed 's/`//ig'

  cols=`echo "$cols" | sed "s/\(^\\\`\|\\\`$\)/ /g;s/\\\`|\\\`/,/g"`
}

#生成建表语句
function buildCreateSql()
{
  echo "create table $dTable("
  getColumns | awk 'BEGIN{IGNORECASE=1}{
    if($2 == "NUMBER"){
      if(NF == 3){
        printf("%s number,\n",$1)
      }else{
        printf("%s number(%s,%s),\n",$1,$4,$5)
      }
    }else if($2 ~/char/){
      printf("%s %s(%s),\n",$1,$2,$3)
    }else if($2 == "DATE"){
      printf("%s date,\n",$1)
    }
  }'
  echo -e "ftime number(9)\n)\npartition by range(ftime)(\npartition part_$theDay values less than($nextDay)\n);"

  #注释
  getComments
}

#在目标库中创建表
function createTable()
{
  existTable=`execute_tar "select count(1) from user_tables where table_name=upper('$dTable');"`
  if [[ "$existTable" -eq 0 ]]; then
    #表不存在则创建表
    buildCreateSql | execute_tar
    #分表合并，添加分表号
    if [ -n "$subNum" ]; then
      execute_tar "alter table $dTable add subNum varchar2(3);"
    fi
  else
    local existPart=`execute_tar "select count(1) from user_tab_partitions where table_name=upper('$dTable') and partition_name=upper('part_${theDay}')";`
    if [ "$existPart" -eq 0 ]; then
      #分区不存在则添加分区
      execute_tar "alter table $dTable add partition part_$theDay values less than($nextDay);"
    fi
  fi
}

#生成过滤条件
function getFilter()
{
  if [[ -n "$timeCol" && "$existTable" -gt 0 ]]; then
    filter="and $timeCol>=to_date('$prevDay','yyyy-mm-dd') and $timeCol<to_date('$theDay','yyyy-mm-dd')"
  fi
  filter="$filter $extras"
}

#生成控制文件字段
function buildCols()
{
  getColumns | awk 'BEGIN{
    print("(")
  }{
    if($2 ~/char|text/){
      printf("%s char(1000000) \"REPLACE(:%s,'\''\\\\n'\'',CHR(10))\",\n",$1,$1)
    }else{
      printf("%s nullif(%s=\"NULL\"),\n",$1,$1)
    }
  }END{
    printf("ftime \"nvl(null,'$theDay')\"\n")
    print(")")
  }'
}

#生成控制文件
function buildCtl()
{
  echo "load data
infile '$theDay/tmp/$sTable.tmp'
badfile '$theDay/bad/$sTable.bad'
append into table $dTable
fields terminated by '|||'
trailing nullcols
`buildCols`" > $theDay/ctl/$sTable.ctl

  if [ -n "$subNum" ]; then
    local addCol="subNum \"nvl(null,'${sTable##*_}')\""
    awk '{
      a[++i]=$0
    }END{
      for(j=1;j<i-1;j++){
        print a[j]
      }
      print a[i-1]","
      print addCol
      print a[i]
    }' addCol="$addCol" $theDay/ctl/$sTable.ctl > $theDay/ctl/$sTable.ctl.tmp
    mv $theDay/ctl/$sTable.ctl.tmp $theDay/ctl/$sTable.ctl
  fi
}

#生成查询字段
function buildSelectCols()
{
  echo "$cols" | awk -F "," '{
    printf("to_clob(%s)",$1)
    for(i=1;i<NF;i++){
      printf(" || '\''|||'\'' || %s",$(i+1))
    }
  }'
}

#load数据到oracle
function loadData()
{
  sqlldr userid=$tar_db_url control=$theDay/ctl/$sTable.ctl log=$theDay/log/$sTable.log errors=1000000 rows=100160 readsize=20971520 bindsize=20971520 parallel=true direct=true
}

#$1源表名
#$2目标表名(默认跟源表名相同)
#$3要同步的字段(字段间用“,”隔开)
#$4用来判断增量更新的列名
#$5过滤条件(where条件)
#$6分表数量(100、1000)
function transferTable()
{
  sTable="$1"
  dTable="$2"
  cols="$3"
  timeCol="$4"
  extras="$5"
  subNum="$6"

  sUser=${sTable%.*}
  sTable=${sTable##*.}

  if [ "$sUser" = "$sTable" ]; then
    sUser=${src_db_url%/*}
  fi

  if [ -z "$dTable" ]; then
    dTable="$sTable"
  fi

  createTable
  log "create table done"

  getFilter

  if [ -z "$cols" ]; then
    cols=`execute_src "select column_name from all_tab_columns where owner=upper('$sUser') and table_name=upper('$sTable') order by column_id asc;" | awk '{printf("%s,",$1)}' | sed 's/,$//'`
    log "get columns done"
  fi

  echo "select `buildSelectCols` from $sUser.$sTable where 1=1 $filter;" | execute_src > $theDay/tmp/$sTable.tmp
  log "extract data done"

  buildCtl
  log "build ctl done"

  loadData
  log "load data done"

  log "$sTable done"
}

function main()
{
  initConfig
  initDate
  initDir

  transferTable "$1" "$2" "$3" "$4" "$5" "$6"
}

main "$@"
