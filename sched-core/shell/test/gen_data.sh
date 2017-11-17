#!/bin/bash
#
# 生成数据


MYSQL_HOST=localhost
MYSQL_PORT=3308
MYSQL_USER=root
MYSQL_PASSWD=mysql
MYSQL_DB=gamestand
MYSQL_CHARSET=utf8

# 产品ID 产品名
PRODS="adv_n 广告平台国内
adver 广告平台海外
browser_n 知玩浏览器
clock 闹钟
compass 指南针
file 文件管理
light 手电筒
market_n 知玩市场
recorder 录音机
shop Fishda电商平台"

# android id表名
TBL_AID=android_id
# android id文件名
FILE_AID=android_id

# 表前缀
# 预分配
TP_ALLOT=l_all_
# 新增统计
TP_NEW_CNT=l_add_cnt_
# 留存预分配
TP_KEEP_PRE=l_add_pre_
# 留存真实分配
TP_KEEP_FACT=l_add_fact_
# 新增
TP_NEW=l_add_daily_

# 数据文件目录
DATADIR=$HOME/data
# 临时文件目录
TMPDIR=$HOME/tmp

# 次数分布
# 1次 2次 3次 4-10次
TIMES_RANGE=(40+10 25+5 10+5 5+n)
# 4次 5次 6次 7次 8次 9次 10次
TIMES_RANGE1="45,22,13,8,6,4,2"


# 记录日志
function log()
{
    echo "$(date +'%F %T') [ $@ ]"
}

# 在方法执行前后记录日志
function log_fn()
{
    log "Function call begin [ $@ ]"
    $@
    log "Function call end [ $@ ]"
}

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

# 初始化
function init()
{
    mkdir -p $DATADIR
    mkdir -p $TMPDIR

    file_aid=$DATADIR/$FILE_AID
}

# 生成随机android id
# num 个数
# 例如生成100个: rand_aid 100
function rand_aid()
{
    echo "$@" | awk 'BEGIN{
        srand()

        # 初始化字符数组
        for(i=0;i<=9;i++){
            x[i]=i
        }
        x[10]="a"
        x[11]="b"
        x[12]="c"
        x[13]="d"
        x[14]="e"
        x[15]="f"
        size=length(x)
    }{
        num=$1
        for(i=0;i<num;i++){
            # 生成首位字符
            a = int(rand() * (size - 1)) + 1
            str = x[a]

            # 按比例随机15或16位
            c = int(rand() * 100)
            if(c < 6){
                digit = 15
            }else{
                digit = 16
            }

            # 生成其余字符
            for(j=1;j<digit;j++){
                b = int(rand() * size)
                str = str""x[b]
            }
            print str
        }
    }'
}

# 一、生成随机android id和连续id
# 生成规则:
# 1、随机字符由[0-9][a-f]组成
# 2、字符串首位字符由[1-9][a-f]组成
# 3、字符串长度为16位占94%，15位占6%
# 4、id为连续正整数
function gen_aid()
{
    local file_aid1=$TMPDIR/${FILE_AID}1
    local file_aid2=$TMPDIR/${FILE_AID}2
    local file_aid3=$TMPDIR/${FILE_AID}3
    local file_aid4=$TMPDIR/${FILE_AID}4

    # 生成新aid
    log "Generate new android id $aid_count"
    time(rand_aid $aid_count > $file_aid1)

    local max_id=0
    if [[ -s $file_aid ]]; then
        # 排序
        sort -u $file_aid1 -o $file_aid1
        sort -k 2 $file_aid > $file_aid2
        # 去重
        join -v 1 -2 2 $file_aid1 $file_aid2 > $file_aid3

        # 获取最大id
        max_id=`tail -n 1 $file_aid | cut -f 1`
    else
        sort -u $file_aid1 > $file_aid3
    fi

    local count=`wc -l $file_aid3 | awk '{print $1}'`
    # 循环生成直到满足指定个数aid_count为止
    while [[ $count -lt $aid_count ]]; do
        log "Generated duplicate android id, regenerate new android id"
        rand_aid $((aid_count - count)) > $file_aid1

        cat $file_aid3 >> $file_aid2

        sort -u $file_aid1 -o $file_aid1
        sort -u $file_aid2 -o $file_aid2

        join -v 1 $file_aid1 $file_aid2 >> $file_aid3
        count=`wc -l $file_aid3 | awk '{print $1}'`
    done

    # 打乱顺序
    # 生成连续id
    log "Disrupt the order and generate sequential id"
    awk 'BEGIN{
        srand()
    }{
        printf("%s\t%s\n",$1,int(rand() * count * 2))
    }' count=$aid_count $file_aid3 |
    sort -k 2 |
    awk 'BEGIN{
        OFS="\t"
    }{
        print NR + id,$1
    }' id=$max_id > $file_aid4

    # 合并aid
    cat $file_aid4 >> $file_aid

    # 导入数据库
    if [[ -n "$aid_load" ]]; then
        local sql="CREATE TABLE IF NOT EXISTS $TBL_AID (id BIGINT, aid VARCHAR(16));LOAD DATA LOCAL INFILE '$file_aid4' INTO TABLE $TBL_AID;"
        log "Load data into table: $TBL_AID"
        time(echo "$sql" | exec_sql)
    fi

    # 删除临时文件
    rm -f $file_aid1 $file_aid2 $file_aid3 $file_aid4
}

# 二、统计新增
function stat_new()
{
    local tmp_dir=$TMPDIR/$prod_id
    mkdir -p $tmp_dir

    local file_allot=$tmp_dir/allot
    local file_new=$tmp_dir/new

    local table_allot=${TP_ALLOT}$prod_id
    local table_new=${TP_NEW_CNT}$prod_id

    # 获取开始日期
    local first_date=`echo "SELECT MIN(stattime) FROM $table_allot;" | exec_sql`

    local sql="SELECT
      stattime,
      adduser,
      CONCAT('"$first_date"', ',', stattime) a,
      stattime - INTERVAL 1 DAY a1,
      CONCAT(stattime - INTERVAL 7 DAY, ',', stattime - INTERVAL 2 DAY) a2,
      CONCAT(stattime - INTERVAL 30 DAY, ',', stattime - INTERVAL 8 DAY) a3,
      CONCAT(stattime - INTERVAL 60 DAY, ',', stattime - INTERVAL 31 DAY) a4,
      CONCAT(stattime - INTERVAL 90 DAY, ',', stattime - INTERVAL 61 DAY) a5,
      CONCAT(stattime - INTERVAL 180 DAY, ',', stattime - INTERVAL 91 DAY) a6
    FROM $table_allot;"
    log "Export data"
    time(echo "$sql" | exec_sql > $file_allot)

    # 生成数据
    log "Generate data"
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
    }' $file_allot $file_allot > $file_new

    # 导入数据库
    sql="LOAD DATA LOCAL INFILE '$file_new' INTO TABLE $table_new (stattime, adduser, a, a1, a2, a3, a4, a5, a6);"
    log "Load data into table: $table_new"
    time(echo "$sql" | exec_sql)

    # 删除临时文件
    rm -f $file_allot $file_new
}

# 三、留存分配
function allot_keep()
{
    local table_allot=${TP_ALLOT}$prod_id
    local table_new=${TP_NEW_CNT}$prod_id
    local table_pre=${TP_KEEP_PRE}$prod_id
    local table_fact=${TP_KEEP_FACT}$prod_id

    # 预分配
    local sql="INSERT INTO $table_pre (stattime, adduser, briskuser, x1, x2, x3, y1, y2, y3)
    SELECT
      t.stattime,
      t.adduser,
      t.briskuser,
      t.x1,
      t.x2,
      t.x3,
      GREATEST(ROUND((t.briskuser - t.adduser - t.x1 - t.x2 - t.x3) * 0.6), 0) y1,
      GREATEST(ROUND((t.briskuser - t.adduser - t.x1 - t.x2 - t.x3) * 0.3), 0) y2,
      GREATEST(ROUND((t.briskuser - t.adduser - t.x1 - t.x2 - t.x3) * 0.1), 0) y3
    FROM (
      SELECT
        a.stattime,
        a.adduser,
        a.briskuser,
        ROUND(b.a1 * (35 + RAND() * (10 - 1) + 1) / 100) x1,
        ROUND(b.a2 * (20 + RAND() * (10 - 1) + 1) / 100) x2,
        ROUND(b.a3 * (8 + RAND() * (4 - 1) + 1) / 100) x3
      FROM $table_allot a
      INNER JOIN $table_new b
      ON a.stattime = b.stattime
    ) t;"
    log "Preallot"
    time(echo "$sql" | exec_sql)

    # 修正分配
    sql="INSERT INTO $table_fact (stattime, adduser, briskuser, x1, x2, x3, y1, y2, y3, u1, u2, u3, v1, v2, v3)
    SELECT
      a.stattime,
      a.adduser,
      a.briskuser,
      a.x1,
      a.x2,
      a.x3,
      a.y1,
      a.y2,
      a.y3,
      IF(a.briskuser - a.adduser > 0, LEAST(a.briskuser - a.adduser, a.x1), 0) u1,
      IF(a.briskuser - a.adduser - a.x1 > 0, LEAST(a.briskuser - a.adduser - a.x1, a.x2), 0) u2,
      IF(a.briskuser - a.adduser - a.x1 - a.x2 > 0, LEAST(a.briskuser - a.adduser - a.x1 - a.x2, a.x3), 0) u3,
      IF(a.briskuser - a.adduser - a.x1 - a.x2 - a.x3 > 0, LEAST(a.briskuser - a.adduser - a.x1 - a.x2 - a.x3, a.y1, b.a4), 0) v1,
      IF(a.briskuser - a.adduser - a.x1 - a.x2 - a.x3 - a.y1 > 0, LEAST(a.briskuser - a.adduser - a.x1 - a.x2 - a.x3 - a.y1, a.y2, b.a5), 0) v2,
      IF(a.briskuser - a.adduser - a.x1 - a.x2 - a.x3 - a.y1 - a.y2 > 0, LEAST(a.briskuser - a.adduser - a.x1 - a.x2 - a.x3 - a.y1 - a.y2, a.y2, b.a6), 0) v3
    FROM $table_pre a
    INNER JOIN $table_new b
    ON a.stattime = b.stattime;
    UPDATE $table_fact SET z = briskuser - adduser - u1 - u2 - u3 - v1 - v2 - v3;"
    log "Amend allocation"
    time(echo "$sql" | exec_sql)
}

# 导出新增用户
function export_new()
{
    range_date $min_date $end_date | while read the_date; do
        file_new=$data_dir/new.$the_date
        if [[ ! -s $file_new ]]; then
            echo "SELECT aidid, cuscode, city FROM $table_new WHERE ctime = '$the_date';" | exec_sql > $file_new
        fi
    done
}

# 生成一天活跃
function gen_active1()
{
    local date1=`date +%F -d "$the_date 1 day ago"`
    local date2=`date +%F -d "$the_date 7 day ago"`
    local date3=`date +%F -d "$the_date 30 day ago"`
    local date4=`date +%F -d "$the_date 60 day ago"`
    local date5=`date +%F -d "$the_date 90 day ago"`
    local date6=`date +%F -d "$the_date 181 day ago"`

    local file_active=$data_dir/active.$the_date

    # 匹配新增日期
    rm -f $file_new1 $file_u1 $file_u2 $file_u3 $file_v1 $file_v2 $file_v3
    awk -F '\t' 'BEGIN{
        OFS=FS
        srand()
    }{
        if($1 == date0){
            print $2,$3,$4 >> "'$file_new1'"
        }else if($1 == date1){
            print $2,$3,$4,rand() >> "'$file_u1'"
        }else if($1 < date1 && $1 >= date2){
            print $2,$3,$4,rand() >> "'$file_u2'"
        }else if($1 < date2 && $1 >= date3){
            print $2,$3,$4,rand() >> "'$file_u3'"
        }else if($1 < date3 && $1 >= date4){
            print $2,$3,$4,rand() >> "'$file_v1'"
        }else if($1 < date4 && $1 >= date5){
            print $2,$3,$4,rand() >> "'$file_v2'"
        }else if($1 < date5 && $1 >= date6){
            print $2,$3,$4,rand() >> "'$file_v3'"
        }
    }' date0=$the_date date1=$date1 date2=$date2 date3=$date3 date4=$date4 date5=$date5 date6=$date6 $file_new

    # 随机取指定数量用户
    # new u1 u2 u3 v1 v2 v3
    rm -f $file_active1
    if [[ -s $file_new1 ]]; then
        cp -f $file_new1 $file_active1
    fi
    local arr=(`echo "SELECT u1, u2, u3, v1, v2, v3, z FROM $table_fact WHERE stattime = '$the_date';" | exec_sql`)
    if [[ ${arr[0]} -gt 0 && -s $file_u1 ]]; then
        sort -t $'\t' -k 4 $file_u1 | head -n ${arr[0]} | sed 's/\(.*\)\t.*$/\1/' >> $file_active1
    fi
    if [[ ${arr[1]} -gt 0 && -s $file_u2 ]]; then
        sort -t $'\t' -k 4 $file_u2 | head -n ${arr[1]} | sed 's/\(.*\)\t.*$/\1/' >> $file_active1
    fi
    if [[ ${arr[2]} -gt 0 && -s $file_u3 ]]; then
        sort -t $'\t' -k 4 $file_u3 | head -n ${arr[2]} | sed 's/\(.*\)\t.*$/\1/' >> $file_active1
    fi
    if [[ ${arr[3]} -gt 0 && -s $file_v1 ]]; then
        sort -t $'\t' -k 4 $file_v1 | head -n ${arr[3]} | sed 's/\(.*\)\t.*$/\1/' >> $file_active1
    fi
    if [[ ${arr[4]} -gt 0 && -s $file_v2 ]]; then
        sort -t $'\t' -k 4 $file_v2 | head -n ${arr[4]} | sed 's/\(.*\)\t.*$/\1/' >> $file_active1
    fi
    if [[ ${arr[5]} -gt 0 && -s $file_v3 ]]; then
        sort -t $'\t' -k 4 $file_v3 | head -n ${arr[5]} | sed 's/\(.*\)\t.*$/\1/' >> $file_active1
    fi

    cp -f $file_active1 $file_active

    # z
    if [[ ${arr[6]} -gt 0 ]]; then
        sort -t $'\t' -k 1 $file_active1 -o $file_active1
        sed 's/^[^ ]\{10\}\t\(.*\)/\1/' $file_new | sort -t $'\t' -k 1 > $file_new2
        join -t "$sep" -v 1 $file_new2 $file_active1 | awk -F '\t' 'BEGIN{
            srand()
            OFS=FS
        }{
            print $0,rand()
        }' |
        sort -t $'\t' -k 4 | head -n ${arr[6]} | sed 's/\(.*\)\t.*$/\1/' >> $file_active
    fi
}

# 四、根据新增用户和留存用户生成活跃用户
function gen_active()
{
    local data_dir=$DATADIR/$prod_id
    local tmp_dir=$TMPDIR/$prod_id
    mkdir -p $data_dir
    mkdir -p $tmp_dir

    local file_new=$tmp_dir/new
    local file_new1=$tmp_dir/new1
    local file_new2=$tmp_dir/new2
    local file_u1=$tmp_dir/u1
    local file_u2=$tmp_dir/u2
    local file_u3=$tmp_dir/u3
    local file_v1=$tmp_dir/v1
    local file_v2=$tmp_dir/v2
    local file_v3=$tmp_dir/v3
    local file_active1=$tmp_dir/active1

    local table_new=${TP_NEW}$prod_id
    local table_fact=${TP_KEEP_FACT}$prod_id

    local min_date=`echo "SELECT MIN(ctime) FROM $table_new;" | exec_sql`

    # 导出新增
    log "Export new"
    time(export_new)

    # 合并截止开始日期前一天的新增
    rm -f $file_new
    log "Merge history new"
    range_date $min_date $start_date | sed '$d' | while read the_date; do
        sed "s/^/${the_date}\t/" $data_dir/new.$the_date >> $file_new
    done

    # 按天生成活跃
    log "Generate active day by day"
    range_date $start_date $end_date | while read the_date; do
        # 合并当天新增
        log "Merge new for day $the_date"
        sed "s/^/${the_date}\t/" $data_dir/new.$the_date >> $file_new

        log "Generate active for day $the_date"
        time(gen_active1)
    done

    # 删除临时文件
    rm -f $file_new $file_new1 $file_new2 $file_u1 $file_u2 $file_u3 $file_v1 $file_v2 $file_v3 $file_active1
}

# 导出地区ip
function export_ip()
{
    if [[ "$prod_id" =~ _n$ ]]; then
        echo "SELECT city, CONCAT(ip_start, ':', ip_end) FROM l_ip_native;"
    else
        echo "SELECT city, CONCAT(inet_aton(ipb), ':', inet_aton(ipe)) FROM l_ip_abroad;"
    fi | exec_sql | awk '{
        if($1 == city){
            ips = ips","$2
        }else{
            if(ips != "") print city,ips
            ips = $2
        }
        city = $1
    }END{
        print city,ips
    }' > $file_ip
}

# 导出地区时段分布
function export_hours()
{
    local prod_name=`echo "$PRODS" | grep "$prod_id " | awk '{print $2}'`
    echo "SELECT city, GROUP_CONCAT(hour, ':', rate) FROM l_hour_rand WHERE proname = '$prod_name' GROUP BY city;" | exec_sql > $file_hours

    if [[ "$prod_id" =~ _n$ ]]; then
        echo "SELECT city FROM l_pro_city WHERE proname = '$prod_name' GROUP BY city;" | exec_sql | awk 'BEGIN{OFS="\t"}{print $1,hours}' hours=`awk '{print $2}' $file_hours` > $file_hours
    fi
}

# 次数占比
function range_times()
{
    echo "${TIMES_RANGE[@]}" | awk 'BEGIN{
        srand()
    }{
        split($1,arr1,"+")
        split($2,arr2,"+")
        split($3,arr3,"+")

        range1 = arr1[1] + int(rand() * (arr1[2] + 1))
        range2 = arr2[1] + int(rand() * (arr2[2] + 1))
        range3 = arr3[1] + int(rand() * (arr3[2] + 1))

        # 四舍五入
        count1 = int(total_active * range1 / 100 + 0.5)
        count2 = int(total_active * range2 / 100 + 0.5)
        count3 = int(total_active * range3 / 100 + 0.5)
        count4 = total_active - count1 - count2 - count3

#        print $1,$2,$3,$4
#        print range1,range2,range3,100 - range1 - range2 - range3
#        print count1,count2,count3,count4
        print "1,"count1,count1 + 1","count1 + count2,count1 + count2 + 1","count1 + count2 + count3,count1 + count2 + count3 + 1","total_active
    }' total_active=$total_active
}

# 生成访问次数
function gen_times()
{
    # 当天活跃用户数
    local total_active=`wc -l $file_active | awk '{print $1}'`

    # 次数分布
    local times_range=(`range_times`)

    # 按随机数排序
    awk -F '\t' 'BEGIN{
        srand()
        OFS=FS
    }{
        print $0,rand()
    }' $file_active |
    sort -t $'\t' -k 4 > $file_active1

    # 按访问次数占比分配
    rm -f $file_active2
    for((i=0;i<${#times_range[@]};i++)) do
        sed -n "${times_range[$i]} p" $file_active1 |
        awk -F '\t' 'BEGIN{
            srand()
            OFS=FS

            split("'$TIMES_RANGE1'",arr,",")
            size=length(arr)
            for(i=0;i<size;i++){
                w[i] = w[i-1] + arr[i+1]
            }
        }{
            num = idx + 1
            if(idx == 3){
                rnd = int(rand() * 100 + 1)
                if(rnd <= w[0]){
                    num += 0
                }else if(rnd <= w[1]){
                    num += 1
                }else if(rnd <= w[2]){
                    num += 2
                }else if(rnd <= w[3]){
                    num += 3
                }else if(rnd <= w[4]){
                    num += 4
                }else if(rnd <= w[5]){
                    num += 5
                }else{
                    num += 6
                }
            }

            for(i=1;i<=num;i++){
                print $1,$2,$3
            }
        }' idx=$i >> $file_active2
    done
}

# 时段占比
function range_hours()
{
    awk 'BEGIN{
        srand()
    }{
        # 初始化city访问次数数组
        if(NR == 1){
            split(cities_times,city_times," ")
            for(i in city_times){
                split(city_times[i],city_arr,":")
                city[city_arr[1]] = city_arr[2]
#                print "step 1",city_arr[1],city_arr[2]
            }
        }

        if(city[$1] > 0){
            # 按时段占比分配
            split($2,hours_rate,",")
            sum = 0
            for(j in hours_rate){
                split(hours_rate[j],hour_rate,":")
#                print "step 2",hour_rate[1],hour_rate[2]

                # 随机浮动10
                sign = rand()
                num = int(rand() * (10 + 1))
                if(sign < 0.5) num = -num

                count[hour_rate[1]] = int(city[$1] * (hour_rate[2] + num) / 10000)
                sum += count[hour_rate[1]]
#                print "step 3",hour_rate[1],count[hour_rate[1]]
            }

            # 多减少加
            r = int(rand() * 24)
            count[r] += city[$1] - sum
#            print "step 4",r,count[r]

            # 输出行号区间
            acc = 0
            pacc = 0
            printf("%s ",$1)
            for(k=0;k<=23;k++){
                acc += count[k]
                pacc += count[k-1]
                printf("%d,%d ",pacc + 1,acc)
            }
            printf("\n")
        }
    }' cities_times="$cities_times" $file_hours
}

# 生成ip
function gen_ip()
{
    awk -F '\t' 'BEGIN{
        srand()
        OFS=FS
    }{
        if(NR == 1){
            split(city_ips,ips_arr,",")
            size = length(ips_arr)
        }

        # 取随机ip段
        i_ips = int(rand() * size + 1)
        ips = ips_arr[i_ips]

        # 从ip段随机取ip
        split(ips,ip_arr,":")
        diff = ip_arr[2] - ip_arr[1]
        ip = ip_arr[1] + int(rand() * (diff + 1))
        ipa = rshift(and(ip, 0xFF000000), 24)"."rshift(and(ip, 0xFF0000), 16)"."rshift(and(ip, 0xFF00), 8)"."and(ip, 0xFF)

        print $1,$2,$3,ipa,rand()
#        print $1,$2,$3,ip,ipa
    }' city_ips="$city_ips"
}

# 生成访问时段 ip
function gen_hours()
{
    # 当天按city访问次数
    local cities_times=`awk -F '\t' '{
        city[$3]++
    }END{
        for(key in city){
            printf("%s:%d ",key,city[key])
        }
    }' $file_active2`

    # 时段分布
    rm -f $file_active4
    range_hours | while read city others; do
        # 随机获取城市100个ip段
        city_ips=`awk 'BEGIN{
            srand()
        } $1 == "'$city'" {
            split($2,arr,",")
            for(i in arr){
                print arr[2],rand()
            }
        }' $file_ip |
        sort -k 2 | head -n 100`
        if [[ -z "$city_ips" ]]; then
            echo "WARN: can not find ip for city: $city" >&2
            continue
        fi

        # 生成ip
        sed -n "/\t${city}$/p" $file_active2 | gen_ip > $file_active3

        # 按随机数排序
        sort -k 5 $file_active3 -o $file_active3

        hours_range=($others)
        for((i=0;i<${#hours_range[@]};i++)) do
            sed -n "${hours_range[$i]} p" $file_active3 |
            awk -F '\t' 'BEGIN{
                srand()
                OFS=FS
            }{
                hour = idx
                minute = int(rand() * 10 * 6)
                second = int(rand() * 10 * 6)

                if(hour < 10) hour = "0"hour
                if(minute < 10) minute = "0"minute
                if(second < 10) second = "0"second

                print $1,$2,$3,$4,"'$the_date' "hour":"minute":"second
            }' idx=$i >> $file_active4
        done
    done
}

# 替换aid
function replace_aid()
{
    # 排序
    sort $file_active4 -o $file_active4

    # 关联得到aid
    join -t "$sep" -o 2.2 1.2 1.3 1.4 1.5 $file_active4 $file_aid | sort -t $'\t' -k 5 > $file_visit
}

# 生成一天访问日志
function gen_visit1()
{
    local file_active=$data_dir/active.$the_date
    local file_visit=$data_dir/visit.$the_date

    # 生成访问次数
    log "Generate visit times"
    time(gen_times)

    # 生成访问时段
    log "Generate hours distribution"
    time(gen_hours)

    # 替换aid
    log "Replace android id"
    time(replace_aid)
}

# 生成访问日志
function gen_visit()
{
    local data_dir=$DATADIR/$prod_id
    local tmp_dir=$TMPDIR/$prod_id
    mkdir -p $data_dir
    mkdir -p $tmp_dir

    local file_active1=$tmp_dir/active1
    local file_active2=$tmp_dir/active2
    local file_active3=$tmp_dir/active3
    local file_active4=$tmp_dir/active4

    # 导出地区ip
    local file_ip=$DATADIR/ip
    if [[ "$prod_id" =~ _n$ ]]; then
        file_ip=$DATADIR/nip
    fi
    if [[ ! -f $file_ip ]]; then
        log "Export city ip"
        time(export_ip)
    fi

    # 导出产品地区时段分布
    local file_hours=$data_dir/hours
    if [[ ! -f $file_hours ]]; then
        log "Export city hours"
        time(export_hours)
    fi

    # 排序android id
    log "Sort android id"
    sort $file_aid -o $file_aid

    # 按天生成访问日志
    log "Generate visit day by day"
    range_date $start_date $end_date | while read the_date; do
        log "Generate visit for day $the_date"
        time(gen_visit1)
    done

    # 删除临时文件
    rm -f $file_active1 $file_active2 $file_active3 $file_active4
}

# 校验访问次数
function check_times()
{
    awk -F '\t' '{
        # 单个id出现的次数
        id[$1]++
    }END{
        # 每种次数出现的id数
        for(i in id){
            times=id[i]
            if(times < 10) times="0"times
            atimes[times]++
        }

        # 按次数排序
        size=asorti(atimes,itimes);
        printf("次数\t")
        for(i=1;i<=size;i++){
            total+=atimes[itimes[i]]
            printf("%d\t",itimes[i])
        }
        printf("total\n")

        printf("用户数\t")
        for(i=1;i<=size;i++){
            printf("%d\t",atimes[itimes[i]])
        }
        printf("%d\n",total)

        printf("占比\t")
        for(i=1;i<=size;i++){
            pct=int(atimes[itimes[i]] / total * 100 + 0.5)
            total_pct+=pct
            printf("%d\t",pct)
        }
        printf("%d\n",total_pct)
    }' $file_visit

    echo "设定 ${TIMES_RANGE[@]}" | tr ' ' '\t'
}

# 校验时段分布
function check_hours()
{
    awk -F '\t' '{
        if(NR == FNR){
            split($5,arr,":")
            city[$3]++
            cityh[$3,arr[1]]++
        }else{
            split($2,ahours,",")
            for(i in ahours){
                split(ahours[i],ahour,":")
                hour=ahour[1]
                if(hour < 10) hour="0"hour
                hours[hour]=ahour[2]
            }
            size=asorti(hours,ihours)
            printf("%s\t",$1)
            for(i=1;i<=size;i++){
#                printf("%s:%d\t",ihours[i],hours[ihours[i]])
                printf("%d\t",hours[ihours[i]])
            }
            printf("10000\n")
        }
    }END{
        size=asorti(cityh,icity)
        for(i=1;i<=size;i++){
            split(icity[i],acity,SUBSEP)
            pct=int(cityh[icity[i]] / city[acity[1]] * 10000 + 0.5)

            if(acity[1] == cname){
                tpct+=pct
#                printf("%s:%d\t",acity[2],pct)
                printf("%d\t",pct)
            }else{
                if(cname != "") printf("%d\n",tpct)
#                printf("%s\t%s:%d\t",acity[1],acity[2],pct)
                printf("%s\t%d\t",acity[1],pct)
                tpct=pct
            }
            cname=acity[1]
        }
        printf("%d\n",tpct)
    }' $file_visit $file_hours |
    sort | awk -F '\t' '{
        print $0
        if($1 == city){
            printf("DIF\t")
            for(i=0;i<=24;i++){
                printf("%d\t",hour[i] - $(i+2))
            }
            printf("\n")
        }else{
            for(i=0;i<=24;i++){
                hour[i]=$(i+2)
            }
        }
        city=$1
    }'
}

# 校验aid
function check_aid()
{
    local count_active=`awk '{print $1}' $file_active | wc -l`
    local count_active1=`awk '{print $1}' $file_active | sort -u | wc -l`
    local count_visit=`awk '{print $1}' $file_visit | sort -u | wc -l`

    # 验证活跃用户是否重复
    if [[ $count_active -ne $count_active1 ]]; then
        log "Exists duplicate active user"
    fi

    # 验证访问日志用户跟活跃用户是否一致
    if [[ $count_active1 -ne $count_visit ]]; then
        log "The amount of active and visit does not match, active $count_active visit $count_visit"
    fi
}

# 校验ip
function check_ip()
{
    log "Generate ip between $1 and $2"
    echo "$@" | awk 'BEGIN{
        srand()
        OFS="\t"
    }{
        diff = $2 - $1
        for(i=0;i<diff;i++){
            ip = $1 + int(rand() * (diff + 1))
            ipa = rshift(and(ip, 0xFF000000), 24)"."rshift(and(ip, 0xFF0000), 16)"."rshift(and(ip, 0xFF00), 8)"."and(ip, 0xFF)
            print ip,ipa,$1 - ip,$2 - ip
        }
    }' | sort -k 3 -n
}

# 校验一天访问日志
function check_visit1()
{
    local file_hours=$DATADIR/$prod_id/hours
    local file_active=$DATADIR/$prod_id/active.$the_date
    local file_visit=$DATADIR/$prod_id/visit.$the_date

    # 校验访问次数
    log "Check visit times for day $the_date"
    check_times

    # 校验时段分布
    log "Check hours for day $the_date"
    check_hours

    # 校验aid
    log "Check aid of active and visit for day $the_date"
    check_aid
}

# 校验访问日志
function check_visit()
{
    range_date $start_date $end_date | while read the_date; do
        check_visit1
    done

    # 校验ip
    log "Check ip"
    check_ip 1347423808 1347424015
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 [ -a 生成Android ID <个数,是否入库> ] [ -b 汇总新增 <产品ID> ] [ -c 分配留存 <产品ID> ] [ -d 生成活跃 <产品ID,开始日期,结束日期,生成访问日志,校验访问日志> ] [ -e 生成访问日志 <产品ID,开始日期,结束日期,校验访问日志> ] [ -f 校验访问日志 <产品ID,开始日期,结束日期> ]"
    echo "${PRODS[@]}" | awk 'BEGIN{
        print "产品列表:"
    }{
        size=13-length($1)+length($2)
        printf("  %s% *s\n",$1,size,$2)
    }'
    echo "日期格式: yyyyMMdd"
}

function main()
{
    if [[ $# -lt 1 ]]; then
        print_usage
        exit 1
    fi

    while getopts "a:b:c:d:e:f:v" opt; do
        args=(${OPTARG//,/ })
        case "$opt" in
            a)
                aid_count=${args[0]}
                aid_load=${args[1]};;
            b)
                prod_id=${args[0]}
                new_stat=1;;
            c)
                prod_id=${args[0]}
                keep_allot=1;;
            d)
                if [[ ${#args[@]} -lt 3 ]]; then
                    print_usage
                    exit 1
                fi
                prod_id=${args[0]}
                start_date=${args[1]}
                end_date=${args[2]}
                visit_gen=${args[3]}
                visit_check=${args[4]}
                active_gen=1;;
            e)
                if [[ ${#args[@]} -lt 3 ]]; then
                    print_usage
                    exit 1
                fi
                prod_id=${args[0]}
                start_date=${args[1]}
                end_date=${args[2]}
                visit_check=${args[3]}
                visit_gen=1;;
            f)
                if [[ ${#args[@]} -lt 3 ]]; then
                    print_usage
                    exit 1
                fi
                prod_id=${args[0]}
                start_date=${args[1]}
                end_date=${args[2]}
                visit_check=1;;
            v)
                debug_flag=1;;
            ?)
                print_usage
                exit 1;;
        esac
    done

    export LC_ALL=C
    sep=`echo -e "\t"`
    set -e

    # 初始化
    log_fn init

    # 生成aid
    [[ $aid_count ]] && log_fn gen_aid

    # 统计新增
    [[ $new_stat ]] && log_fn stat_new

    # 分配留存
    [[ $keep_allot ]] && log_fn allot_keep

    # 生成活跃
    [[ $active_gen ]] && log_fn gen_active

    # 生成访问日志
    [[ $visit_gen ]] && log_fn gen_visit

    # 校验访问日志
    [[ $visit_check ]] && log_fn check_visit
}
main "$@"