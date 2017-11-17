#!/bin/bash
#
# 生成活跃用户


MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWD=mysql
MYSQL_DB=test
MYSQL_CHARSET=utf8

# 临时文件目录
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

    echo "SET $MYSQL_CHARSET;$sql" | mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASSWD $MYSQL_DB $params
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

    local sql="SELECT u1, u2, u3, v1, v2, v3, z FROM zw_clock_daily_fat WHERE stattime = '$the_date';"
    echo "$sql" | exec_sql | while read u1 u2 u3 v1 v2 v3 z; do
        sql="SELECT ctime, proname, cuscode, city, aid, ip, ipid, aidid, '$the_date' FROM l_add_daily_clock WHERE ctime = '$the_date';"
        echo `date +'%F %T'`" [ Generate new ]"
        time(echo "$sql" | exec_sql > $TMPDIR/tmp_active.tmp)

        sql="SELECT ctime, proname, cuscode, city, aid, ip, ipid, aidid, '$the_date' FROM l_add_daily_clock WHERE ctime = '$date1' ORDER BY RAND() LIMIT $u1;"
        echo `date +'%F %T'`" [ Generate u1 ]"
        time(echo "$sql" | exec_sql >> $TMPDIR/tmp_active.tmp)

        sql="SELECT ctime, proname, cuscode, city, aid, ip, ipid, aidid, '$the_date' FROM l_add_daily_clock WHERE ctime >= '$date2' AND ctime < '$date1' ORDER BY RAND() LIMIT $u2;"
        echo `date +'%F %T'`" [ Generate u2 ]"
        time(echo "$sql" | exec_sql >> $TMPDIR/tmp_active.tmp)

        sql="SELECT ctime, proname, cuscode, city, aid, ip, ipid, aidid, '$the_date' FROM l_add_daily_clock WHERE ctime >= '$date3' AND ctime < '$date2' ORDER BY RAND() LIMIT $u3;"
        echo `date +'%F %T'`" [ Generate u3 ]"
        time(echo "$sql" | exec_sql >> $TMPDIR/tmp_active.tmp)

        sql="SELECT ctime, proname, cuscode, city, aid, ip, ipid, aidid, '$the_date' FROM l_add_daily_clock WHERE ctime >= '$date4' AND ctime < '$date3' ORDER BY RAND() LIMIT $v1;"
        echo `date +'%F %T'`" [ Generate v1 ]"
        time(echo "$sql" | exec_sql >> $TMPDIR/tmp_active.tmp)

        sql="SELECT ctime, proname, cuscode, city, aid, ip, ipid, aidid, '$the_date' FROM l_add_daily_clock WHERE ctime >= '$date5' AND ctime < '$date4' ORDER BY RAND() LIMIT $v2;"
        echo `date +'%F %T'`" [ Generate v2 ]"
        time(echo "$sql" | exec_sql >> $TMPDIR/tmp_active.tmp)

        sql="SELECT ctime, proname, cuscode, city, aid, ip, ipid, aidid, '$the_date' FROM l_add_daily_clock WHERE ctime >= '$date6' AND ctime < '$date5' ORDER BY RAND() LIMIT $v3;"
        echo `date +'%F %T'`" [ Generate v3 ]"
        time(echo "$sql" | exec_sql >> $TMPDIR/tmp_active.tmp)

        sql="DROP TABLE IF EXISTS tmp_active;
CREATE TABLE tmp_active LIKE l_act_daily_clock;
ALTER TABLE tmp_active ENGINE=MyISAM;
ALTER TABLE tmp_active DROP COLUMN id;
ALTER TABLE tmp_active DISABLE KEYS;
LOAD DATA LOCAL INFILE '$TMPDIR/tmp_active.tmp' INTO TABLE tmp_active;
ALTER TABLE tmp_active ENABLE KEYS;"
        echo `date +'%F %T'`" [ Load tmp active ]"
        time(echo "$sql" | exec_sql)

        sql="SELECT ctime, proname, cuscode, city, aid, ip, ipid, aidid, '$the_date' FROM l_add_daily_clock a WHERE ctime < '$the_date' AND NOT EXISTS
  (SELECT 1 FROM tmp_active b WHERE a.aidid = b.aidid AND b.atime = '$the_date') ORDER BY RAND() LIMIT $z;"
        echo `date +'%F %T'`" [ Generate z ]"
        time(echo "$sql" | exec_sql >> $TMPDIR/tmp_active.tmp)

        sql="ALTER TABLE l_act_daily_clock DISABLE KEYS;
LOAD DATA LOCAL INFILE '$TMPDIR/tmp_active.tmp' INTO TABLE l_act_daily_clock (ctime, proname, cuscode, city, aid, ip, ipid, aidid, atime);
ALTER TABLE l_act_daily_clock ENABLE KEYS;"
        echo `date +'%F %T'`" [ Load active ]"
        time(echo "$sql" | exec_sql)
    done
}

# 统计时间
function stat()
{
    egrep real | awk 'BEGIN{OFS="\t"}{
        split($2,arr,"m")
        seconds = arr[1] * 60 + substr(arr[2], 1, length(arr[2]) - 1)

        if(NR % 11 > 0){
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

    range_date $start_date $end_date | while read the_date; do
        time(gen_day)
    done

    echo `date +'%F %T'`" [ Generate done ]"

    # 统计时间
    #cat nohup.out | stat
}
main "$@"