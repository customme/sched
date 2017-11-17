#!/bin/bash
#数据同步通用脚本，从oracle到mysql

source /etc/profile
source ~/.bash_profile
export LC_ALL=C

#初始化时间参数
function initDate()
{
  theDay=`date +%Y%m%d`
}

#初始化目录
function initDir()
{
  if [ ! -d tmp ]; then
    mkdir tmp
  fi
}

#初始化oracle数据库连接信息
function initSDB()
{
  oracle_usr=usr_ho_scheduler_new
  oracle_pwd=usr_ho_scheduler_new01
  oracle_sid=orcl
}

#执行源数据库sql语句
function executeSqlS()
{
  sql="$1"
  if [ -z "$sql" ]; then
    return
  fi

sqlplus -S -L /nolog << EOF
connect $oracle_usr/$oracle_pwd@$oracle_sid
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
$sql;
commit;
quit
EOF
}

#执行目标数据库sql语句
function executeSqlD()
{
  sql="$1"

  if [ -z "$sql" ]
  then
    cat | mysql -h172.17.210.180 -udc_scheduler_cli -pdc_scheduler_cli dc_scheduler_client -N -q --local-infile
  else
    echo "$sql" | mysql -h172.17.210.180 -udc_scheduler_cli -pdc_scheduler_cli dc_scheduler_client -N -q --local-infile
  fi
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

#将大写转换成小写
function toLowerCase()
{
  tr "[:upper:]" "[:lower:]"
}

#oracle数据类型到mysql转换
#number(3)->tinyint
#number(5)->smallint
#number(7)->mediumint
#number(19)->bigint
#number(n)->int
#number(m,n)->decimal(m,n)
#char/nchar/varchar2/nvarchar2->varchar
#date->date
function dataTypeConverter()
{
  awk 'BEGIN{IGNORECASE=1}{
    if($2 == "NUMBER"){
      if($5 <= 0){
        if($4 == 3){
          printf("%s tinyint\n",$1)
        }else if($4 == 5){
          printf("%s smallint\n",$1)
        }else if($4 == 7){
          printf("%s mediumint\n",$1)
        }else if($4 == 19){
          printf("%s bigint\n",$1)
        }else{
          printf("%s int\n",$1)
        }
      }else{
        printf("%s decimal(%s,%s)\n",$1,$4+$5,$5)
      }
    }else if($2 ~/char/){
      printf("%s varchar(%s)\n",$1,$3)
    }else if($2 == "DATE"){
      printf("%s datetime\n",$1)
    }
  }'
}

#获取字段名称和字段类型
function getColumns()
{
  executeSqlS "select column_name,data_type,data_length,data_precision,data_scale from user_tab_columns where table_name=upper('$sTable') order by column_id"
}

#根据字段名和类型生成建表语句
function buildCreateSql()
{
  awk 'BEGIN{
    print("drop table if exists '$dTable';")
    print("create table if not exists '$dTable'(")
  }{
    a[++i]=$0
  }END{
    for(j=1;j<i;j++){
      print a[j]","
    }
    print a[i]
    print ")"
  }'
}

#在目标库中创建表
function createTable()
{
  getColumns | formatOutput | dataTypeConverter | buildCreateSql | toLowerCase | executeSqlD
}

#生成过滤条件
function getFilter()
{
  if [ -n "$timeCol" ]; then
    timeFlag=`executeSqlD "select ifnull(max($timeCol),0) from ${dTable};"`
    filter="and ${timeCol}>'${timeFlag}'"
  else
    filter=""
  fi

  if [ -n "$extras" ]; then
    filter="$filter $extras"
  fi
}

#生成查询语句
function buildSelectSql()
{
  getColumns | formatOutput | awk '{
    a[++i]=$1
  }END{
    for(j=1;j<i;j++){
      printf("%s || '\''|||'\'' || ",a[j])
    }
    printf(a[i])
  }'
}

#$1源表名
#$2目标表名(默认跟源表名相同)
#$3用来判断增量更新的列名
#$4过滤条件(where条件)
function transferTable()
{
  sTable="$1"
  dTable="$2"
  timeCol="$3"
  extras="$4"

  if [ -z "$dTable" ]; then
    dTable="$sTable"
  fi
  dTable=`echo $dTable | toLowerCase`

  createTable
  getFilter

  executeSqlS "select `buildSelectSql` from $sTable where 1=1 $filter" > tmp/$sTable.tmp
  echo "load data local infile 'tmp/$sTable.tmp' replace into table $dTable fields terminated by '|||'" | executeSqlD

  echo `date +'%Y-%m-%d %H:%M:%S'`" $sTable done"
}

function init()
{
  initDate
  initDir
}

function main()
{
  init

  initSDB

  transferTable T_CLASS
  transferTable T_COURSE
  transferTable T_STUDENT
  transferTable T_STUDENT_STAT
  transferTable T_STU_COURSE_SCORE
  transferTable T_TEACHER
  transferTable T_TEACH_COURSE
}

main
