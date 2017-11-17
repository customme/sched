#!/bin/bash
#
# 统计新增用户
# 统计指标:
# 1、当天新增用户
# 2、截至当天总用户
# 3、前一天新增用户
# 4、前2-7天新增用户
# 5、前8-30天新增用户
# 6、前31-60天新增用户
# 7、前61-90天新增用户
# 8、前91-180天新增用户


MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWD=mysql
MYSQL_DB=test
MYSQL_CHARSET=utf8

# 临时文件目录
TMPDIR=/tmp


# 执行sql
function exec_sql()
{
    local sql="${1:-`cat`}"
    local params="${2:--s -N --local-infile}"

    echo "SET NAMES $MYSQL_CHARSET;$sql" | mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASSWD $MYSQL_DB $params
}

function main()
{
    # 获取原始数据
    local first_date=`echo "SELECT MIN(stattime) FROM zw_clock_daily;" | exec_sql`
    local sql="SELECT
      stattime,
      adduser,
      CONCAT('"$first_time"', ',', stattime) a,
      stattime - INTERVAL 1 DAY a1,
      CONCAT(stattime - INTERVAL 7 DAY, ',', stattime - INTERVAL 2 DAY) a2,
      CONCAT(stattime - INTERVAL 30 DAY, ',', stattime - INTERVAL 8 DAY) a3,
      CONCAT(stattime - INTERVAL 60 DAY, ',', stattime - INTERVAL 31 DAY) a4,
      CONCAT(stattime - INTERVAL 90 DAY, ',', stattime - INTERVAL 61 DAY) a5,
      CONCAT(stattime - INTERVAL 180 DAY, ',', stattime - INTERVAL 91 DAY) a6
    FROM zw_clock_daily;"
    echo "$sql" | exec_sql > $TMPDIR/zw_clock_daily.tmp

    # 生成数据
    awk -F '\t' 'BEGIN{OFS=FS}{
        if(NR == FNR){
            x[$1]=$2
        }else{
            split($3, arr1, ",")
            split($5, arr2, ",")
            split($6, arr3, ",")
            split($7, arr4, ",")
            split($8, arr5, ",")
            split($9, arr6, ",")
            for(y in x){
                if(y >= arr1[1] && y <= arr1[2]) a += x[y]
                if(y == $4) a1 = x[y]
                if(y >= arr2[1] && y <= arr2[2]) a2 += x[y]
                if(y >= arr3[1] && y <= arr3[2]) a3 += x[y]
                if(y >= arr4[1] && y <= arr4[2]) a4 += x[y]
                if(y >= arr5[1] && y <= arr5[2]) a5 += x[y]
                if(y >= arr6[1] && y <= arr6[2]) a6 += x[y]
            }

            print $1,$2,a,a1,a2,a3,a4,a5,a6
            a=0;a1=0;a2=0;a3=0;a4=0;a5=0;a6=0
        }
    }' $TMPDIR/zw_clock_daily.tmp $TMPDIR/zw_clock_daily.tmp > $TMPDIR/zw_clock_daily_cnt.txt

    # 导入数据库
    echo "LOAD DATA LOCAL INFILE '$TMPDIR/zw_clock_daily_cnt.txt' INTO TABLE zw_clock_daily_cnt (stattime, adduser, a, a1, a2, a3, a4, a5, a6);" | exec_sql
}
main "$@"