#!/bin/bash
#
# 文件导入mysql


MYSQL_HOST=localhost
MYSQL_PORT=3308
MYSQL_USER=root
MYSQL_PASSWD=mysql
MYSQL_DB=gamestand
MYSQL_CHARSET=utf8

# 数据文件目录
DATADIR=$HOME/data

# 表名前缀
TP_VISIT=l_visitlog_

# 文件名前缀
FP_VISIT=visit


# 生成日期序列
function range_date()
{
    local date_begin="$1"
    local date_end="$2"

    while [[ $date_begin -le $date_end ]]; do
        date +%F -d "$date_begin"
        date_begin=`date +%Y%m%d -d "$date_begin 1 day"`
    done
}

# 执行sql
function exec_sql()
{
    local sql="${1:-`cat`}"
    local params="${2:--s -N --local-infile}"

    echo "SET NAMES $MYSQL_CHARSET;$sql" | mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASSWD $MYSQL_DB $params
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 产品ID 开始日期 结束日期"
}

function main()
{
    if [[ $# -lt 3 ]]; then
        print_usage
        exit 1
    fi

    prod_id="$1"
    start_date="$2"
    end_date="$3"

    if [[ $# -lt 3 ]]; then
        local dates=`ls $DATADIR/${prod_id}.*.$FP_VISIT | xargs -r -I {} basename {} | awk -F '.' '{print $2}' | sort | awk '{date[++i]=$1}END{printf("%s %s",date[1],date[length(date)])}'`
        if [[ -z "$start_date" ]]; then
            start_date=${dates[0]//-/}
        fi
        end_date=${dates[1]//-/}
    fi

    table_visit=${TP_VISIT}$prod_id

    range_date $start_date $end_date | while read the_date; do
        file_visit=$DATADIR/$prod_id/${FP_VISIT}.$the_date
        echo "Load file: $file_visit into table: $table_visit"
        echo "LOAD DATA LOCAL INFILE '$file_visit' INTO TABLE $table_visit (aid, cuscode, city, ip, visittime);" | exec_sql
    done
}
main "$@"