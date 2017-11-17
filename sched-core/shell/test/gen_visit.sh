#!/bin/bash
#
# 生成访问日志


MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWD=mysql
MYSQL_DB=zhiwan
MYSQL_CHARSET=utf8

# 表名前缀
TBL_PREFIX="l_act_daily_"

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

# 临时文件目录
TMPDIR=/tmp

# 次数分布
# 1次 2次 3次 4-10次
TIMES_RANGE=(40+10 25+5 10+5 5+n)

# 数据量级
MAGNITUDE=1000000


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

# 导出一天活跃
function export_day()
{
    local sql="SELECT aidid, cuscode, city, CEIL(RAND() * $MAGNITUDE) FROM $tbl_name WHERE atime = '$the_date';"
    echo "$sql" | exec_sql > $active_file
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
    }' cities_times="$cities_times" $hours_file
}

# 导出地区时段分布
function export_hours()
{
    echo "SELECT city, GROUP_CONCAT(hour, ':', rate) FROM l_hour_rand WHERE proname = '$prod_name' GROUP BY city;" | exec_sql > $hours_file

    if [[ "$prod_id" =~ _n$ ]]; then
        echo "SELECT city FROM lt_pro_cus_city_$prod_id GROUP BY city;" | exec_sql | awk 'BEGIN{OFS="\t"}{print $1,hours}' hours=`awk '{print $2}' $hours_file` > $hours_file
    fi
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
    }' > $ip_file
}

# 导出设备id
function export_aid()
{
    echo "SELECT id, aid FROM l_aid;" | exec_sql > $aid_file
}

# 生成访问次数
function gen_times()
{
    # 当天活跃用户数
    local total_active=`wc -l $active_file | awk '{print $1}'`

    # 次数分布
    local times_range=(`range_times`)

    # 按随机数排序
    sort -t $'\t' -k 4 $active_file -o $active_file

    # 按访问次数占比分配
    for((i=0;i<${#times_range[@]};i++)) do
        sed -n "${times_range[$i]} p" $active_file | awk -F '\t' 'BEGIN{
            srand()
            OFS=FS
            w[0]=45
            w[1]=w[0] + 22
            w[2]=w[1] + 13
            w[3]=w[2] + 8
            w[4]=w[3] + 6
            w[5]=w[4] + 4
            w[6]=w[5] + 2
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
        }' idx=$i >> $active_file1
    done
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
    }' $active_file1`

    # 时段分布
    range_hours | while read city others; do
        # 随机获取城市100个ip段
        city_ips=`awk 'BEGIN{
            srand()
        } $1 == "'$city'" {
            split($2,arr,",")
            for(i in arr){
                print arr[2],rand()
            }
        }' $ip_file | sort -k 2 | head -n 100`
        if [[ -z "$city_ips" ]]; then
            echo "WARN: can not find ip for city: $city" >&2
            continue
        fi

        # 生成ip
        sed -n "/\t${city}$/p" $active_file1 | gen_ip > $active_file2

        # 按随机数排序
        sort -k 5 $active_file2 -o $active_file2

        hours_range=($others)
        for((i=0;i<${#hours_range[@]};i++)) do
            sed -n "${hours_range[$i]} p" $active_file2 | awk -F '\t' 'BEGIN{
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
            }' idx=$i >> $active_file3
        done
    done
}

# 生成一天访问日志
function gen_day()
{
    # 生成访问次数
    gen_times

    # 生成访问时段
    gen_hours
}

# 填充aid
function fill_aid()
{
    # 排序
    sort $active_file3 -o $active_file3

    # 关联得到aid
    join -t "$sep" -o 2.2 1.2 1.3 1.4 1.5 $active_file3 $aid_file | sort -t $'\t' -k 5 > $visit_file
}

# 删除临时文件
function clear_tmp()
{
    rm -f $active_file1
    rm -f $active_file2
    rm -f $active_file3
}

# 生成访问日志
function gen_visit()
{
    # 导出地区ip
    ip_file=$TMPDIR/ips
    if [[ "$prod_id" =~ _n$ ]]; then
        ip_file=$TMPDIR/nips
    fi
    if [[ ! -f $ip_file ]]; then
        echo `date +'%F %T'`" [ Export city ip ]"
        export_ip
    fi

    # 导出地区时段分布
    hours_file=$TMPDIR/${prod_id}.hours
    if [[ ! -f $hours_file ]]; then
        echo `date +'%F %T'`" [ Export city hours ]"
        export_hours
    fi

    # 导出设备id
    aid_file=$TMPDIR/aids
    if [[ ! -f $aid_file ]]; then
        echo `date +'%F %T'`" [ Export aid ]"
        export_aid
    fi
    sort $aid_file -o $aid_file

    # 按天生成
    range_date $start_date $end_date | while read the_date; do
        active_file=$TMPDIR/${prod_id}.${the_date}.active

        if [[ ! -f $active_file ]]; then
            echo `date +'%F %T'`" [ Export active for day $the_date ]"
            time(export_day)
        fi

        active_file1=${active_file}1
        rm -f $active_file1
        active_file2=${active_file}2
        active_file3=${active_file}3
        rm -f $active_file3

        visit_file=$TMPDIR/${prod_id}.${the_date}.visit
        echo `date +'%F %T'`" [ Generate visit for day $the_date ]"
        time(gen_day)

        echo `date +'%F %T'`" [ Fill aid for day $the_date ]"
        time(fill_aid)

        clear_tmp
    done
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
    }' $visit_file

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
            printf("\n")
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
    }' $visit_file $hours_file | sort
}

# 校验ip
function check_ip()
{
    echo "1347423808 1347424015" | awk 'BEGIN{
        srand()
    }{
        diff = $2 - $1
        for(i=0;i<diff;i++){
            ip = $1 + int(rand() * (diff + 1))
            print ip,$1 - ip,$2 - ip
        }
    }' | sort -k 2 -n
}

# 校验数据
function check_data()
{
    range_date $start_date $end_date | while read the_date; do
        visit_file=$TMPDIR/${prod_id}.${the_date}.visit
        hours_file=$TMPDIR/${prod_id}.hours

        # 校验访问次数
        echo `date +'%F %T'`" [ Check times for day $the_date ]"
        check_times

        # 校验时段分布
        echo `date +'%F %T'`" [ Check hours for day $the_date ]"
        check_hours
    done

    # 校验ip
    echo `date +'%F %T'`" [ Check ip ]"
    check_ip
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
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <产品> [开始日期] [结束日期]"
        echo "${PRODS[@]}" | awk 'BEGIN{print "产品列表:"}{size=13-length($1)+length($2);printf("  %s% *s\n",$1,size,$2)}'
        echo "日期格式: yyyyMMdd"
        exit 1
    fi

    prod_id="${1:-clock}"
    start_date="${2:-20161207}"
    end_date="${3:-20170430}"
    check_data="$4"

    tbl_name=${TBL_PREFIX}${prod_id}
    prod_name=`echo "$PRODS" | grep "$prod_id" | awk '{print $2}'`

    export LC_ALL=C
    set -e
    sep=`echo -e "\t"`

    if [[ -z "$check_data" ]]; then
        # 生成访问日志
        echo `date +'%F %T'`" [ Generate visit start ]"
        gen_visit
        echo `date +'%F %T'`" [ Generate visit done ]"
    else
        # 校验数据
        check_data
    fi

    # 统计时间
    #cat nohup.out | stat
}
main "$@"