#!/bin/bash
#
# 生成活跃用户


MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWD=mysql
MYSQL_DB=test
MYSQL_CHARSET=utf8

TMPDIR=/tmp


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

# 导出一天新增
function export_day()
{
    echo "SELECT ctime, proname, cuscode, city, aid, ip, ipid, aidid FROM l_add_daily_clock WHERE ctime = '$the_date';" | exec_sql > $TMPDIR/new.${the_date}.txt
}

# 合并新增
function get_new()
{
    > $TMPDIR/new.txt
    range_date $min_date ${the_date//-/} | while read the_day; do
        cat $TMPDIR/new.${the_day}.txt >> $TMPDIR/new.txt
    done
}

# 生成一天活跃用户
function gen_day()
{
    echo `date +'%F %T'`" [ Generate day: $the_date ]"
    local date1=`date +%F -d "$the_date 1 day ago"`
    local date2=`date +%F -d "$the_date 7 day ago"`
    local date3=`date +%F -d "$the_date 30 day ago"`
    local date4=`date +%F -d "$the_date 60 day ago"`
    local date5=`date +%F -d "$the_date 90 day ago"`
    local date6=`date +%F -d "$the_date 181 day ago"`

    # 删除临时文件
    rm -f $TMPDIR/new.tmp
    rm -f $TMPDIR/u1.tmp
    rm -f $TMPDIR/u2.tmp
    rm -f $TMPDIR/u3.tmp
    rm -f $TMPDIR/v1.tmp
    rm -f $TMPDIR/v2.tmp
    rm -f $TMPDIR/v3.tmp

    # 获取新增
    get_new

    # 匹配新增日期
    awk -F '\t' 'BEGIN{
        OFS=FS
        srand()
    }{
        if($1 == date0){
            print $0 >> "'$TMPDIR'/new.tmp"
        }else if($1 == date1){
            print $0,rand() >> "'$TMPDIR'/u1.tmp"
        }else if($1 < date1 && $1 >= date2){
            print $0,rand() >> "'$TMPDIR'/u2.tmp"
        }else if($1 < date2 && $1 >= date3){
            print $0,rand() >> "'$TMPDIR'/u3.tmp"
        }else if($1 < date3 && $1 >= date4){
            print $0,rand() >> "'$TMPDIR'/v1.tmp"
        }else if($1 < date4 && $1 >= date5){
            print $0,rand() >> "'$TMPDIR'/v2.tmp"
        }else if($1 < date5 && $1 >= date6){
            print $0,rand() >> "'$TMPDIR'/v3.tmp"
        }
    }' date0=$the_date date1=$date1 date2=$date2 date3=$date3 date4=$date4 date5=$date5 date6=$date6 $TMPDIR/new.txt

    local sql="SELECT u1, u2, u3, v1, v2, v3, z FROM zw_clock_daily_fat WHERE stattime = '$the_date';"
    local arr=(`echo "$sql" | exec_sql`)

    # 随机取指定数量用户
    # new u1 u2 u3 v1 v2 v3
    if [[ -s $TMPDIR/new.tmp ]]; then
        cp -f $TMPDIR/new.tmp $TMPDIR/active.tmp
    else
        > $TMPDIR/active.tmp
    fi
    if [[ ${arr[0]} -gt 0 && -s $TMPDIR/u1.tmp ]]; then
        sort -t $'\t' -k 9 -n $TMPDIR/u1.tmp | head -n ${arr[0]} >> $TMPDIR/active.tmp
    fi
    if [[ ${arr[1]} -gt 0 && -s $TMPDIR/u2.tmp ]]; then
        sort -t $'\t' -k 9 -n $TMPDIR/u2.tmp | head -n ${arr[1]} >> $TMPDIR/active.tmp
    fi
    if [[ ${arr[2]} -gt 0 && -s $TMPDIR/u3.tmp ]]; then
        sort -t $'\t' -k 9 -n $TMPDIR/u3.tmp | head -n ${arr[2]} >> $TMPDIR/active.tmp
    fi
    if [[ ${arr[3]} -gt 0 && -s $TMPDIR/v1.tmp ]]; then
        sort -t $'\t' -k 9 -n $TMPDIR/v1.tmp | head -n ${arr[3]} >> $TMPDIR/active.tmp
    fi
    if [[ ${arr[4]} -gt 0 && -s $TMPDIR/v2.tmp ]]; then
        sort -t $'\t' -k 9 -n $TMPDIR/v2.tmp | head -n ${arr[4]} >> $TMPDIR/active.tmp
    fi
    if [[ ${arr[5]} -gt 0 && -s $TMPDIR/v3.tmp ]]; then
        sort -t $'\t' -k 9 -n $TMPDIR/v3.tmp | head -n ${arr[5]} >> $TMPDIR/active.tmp
    fi

    cp -f $TMPDIR/active.tmp $TMPDIR/active.txt

    # z
    if [[ ${arr[6]} -gt 0 ]]; then
        sort -t $'\t' -k 8 $TMPDIR/active.tmp -o $TMPDIR/active.tmp
        sort -t $'\t' -k 8 $TMPDIR/new.txt -o $TMPDIR/new.txt
        join -t "$sep" -1 8 -2 8 -v 1 $TMPDIR/new.txt $TMPDIR/active.tmp | sort -t $'\t' -k 9 -n | head -n ${arr[6]} >> $TMPDIR/active.txt
    fi

    # 导入数据库
    sql="ALTER TABLE l_act_daily_clock DISABLE KEYS;
LOAD DATA LOCAL INFILE '$TMPDIR/active.txt' INTO TABLE l_act_daily_clock (ctime, proname, cuscode, city, aid, ip, ipid, aidid, atime) SET atime='$the_date';
ALTER TABLE l_act_daily_clock ENABLE KEYS;"
    echo `date +'%F %T'`" [ Load active ]"
    time(echo "$sql" | exec_sql)
}

# 统计时间
function stat()
{
    egrep real | awk 'BEGIN{OFS="\t"}{
        split($2,arr,"m")
        seconds = arr[1] * 60 + substr(arr[2], 1, length(arr[2]) - 1)

        if(NR % 2 > 0){
            printf("%s\t", seconds)
        }else{
            printf("%s\n", seconds)
        }
    }'
}

function main()
{
    start_date="${1:-20161207}"
    end_date="${2:-20170430}"

    export LC_ALL=C
    sep=`echo -e "\t"`

    # 按天导出新增
    local dates=(`echo "SELECT MIN(ctime), MAX(ctime) FROM l_add_daily_clock;" | exec_sql`)
    min_date=${dates[0]//-/}
    max_date=${dates[1]//-/}
    if [[ ! -f $TMPDIR/new.$min_date.txt || ! -f $TMPDIR/new.$max_date.txt ]]; then
        echo `date +'%F %T'`" [ Export new ]"
        range_date $min_date $max_date | while read the_date; do
            time(export_day)
        done
    fi

    # 按天生成活跃
    range_date $start_date $end_date | while read the_date; do
        time(gen_day)
    done

    echo `date +'%F %T'`" [ Generate done ]"

    # 统计时间
    #cat nohup.out | stat
}
main "$@"