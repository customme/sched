#!/bin/bash
#
# 生成数据


MYSQL_HOST=localhost
MYSQL_PORT=3308
MYSQL_USER=root
MYSQL_PASSWD=mysql
MYSQL_DB=bostar
MYSQL_CHARSET=utf8

# 产品ID 产品名
PRODS="adv_n 砾点广告平台
compass_n 智能指南针
file_n 快致文件管理
light_n 强光手电筒
recorder_n 随身录音机
search_n 立引搜索
shop_n 必购商城
weather_n 实时天气"

# android id表名
TBL_AID=android_id
# android id文件名
FILE_AID=android_id

# 数据文件目录
DATADIR=$HOME/data2
# 临时文件目录
TMPDIR=$HOME/tmp2/$(date +%s%N)

# 访问时长分布
TIME_RANGE="adv_n 1-60:420,61-180:310,181-300:180,301-600:60,601-1200:20,1201-1800:10
compass_n 1-60:530,61-180:310,181-300:118,301-600:36,601-1200:5,1201-1800:1
file_n 1-60:442,61-180:284,181-300:187,301-600:45,601-1200:25,1201-1800:17
light_n 1-60:550,61-180:320,181-300:98,301-600:20,601-1200:10,1201-1800:2
recorder_n 1-60:610,61-180:300,181-300:60,301-600:22,601-1200:6,1201-1800:2
search_n 1-60:480,61-180:315,181-300:110,301-600:50,601-1200:30,1201-1800:15
shop_n 1-60:360,61-180:270,181-300:200,301-600:150,601-1200:15,1201-1800:5
weather_n 1-60:630,61-180:308,181-300:35,301-600:20,601-1200:6,1201-1800:1"


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
    local date_begin=`date +%Y%m%d -d "$1"`
    local date_end=`date +%Y%m%d -d "$2"`

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
    prod_name=`echo "$PRODS" | grep "$prod_id " | awk '{print $2}'`
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
        max_id=`awk '{print $1}' $file_aid | sort -n | tail -n 1`
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

    # 排序android id
    log "Sort android id"
    sort $file_aid -o $file_aid

    # 删除临时文件
    rm -f $file_aid1 $file_aid2 $file_aid3 $file_aid4
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
    echo "SELECT city, GROUP_CONCAT(hour, ':', rate) FROM l_hour_rand WHERE proname = '$prod_name' GROUP BY city;" | exec_sql > $file_hours

    if [[ "$prod_id" =~ _n$ ]]; then
        echo "SELECT city FROM l_pro_city WHERE proname = '$prod_name' GROUP BY city;" | exec_sql | awk 'BEGIN{OFS="\t"}{print $1,hours}' hours=`awk '{print $2}' $file_hours` > $file_hours
    fi
}

# 获取活跃次数分布
function get_times()
{
    local file_times=$DATADIR/visit_times
    if [[ ! -s $file_times ]]; then
        echo "SELECT proname, cnt, rate FROM l_daycnt_rand ORDER BY proname, cnt;" | exec_sql > $file_times
    fi

    awk -F '\t' '$1 == "'$prod_name'" {print $2,$3}' $file_times
}

# 次数占比
function range_times()
{
    get_times | awk 'BEGIN{
        srand()
    }{
        rndpct = int($2 / 10 + 0.5)
        sign = rand()
        if(sign < 0.5) rndpct = - rndpct

        vtimes[$1] = int(total_active * ($2 + rndpct) / 1000 + 0.5)
        sum += vtimes[$1]
    }END{
        size = length(vtimes)
        rnd = int(rand() * size) + 1
        vtimes[rnd] += total_active - sum

        for(i=1;i<=size;i++){
            if(vtimes[i] > 0){
                acc += vtimes[i]
                pacc = acc - vtimes[i]
                print i,pacc + 1","acc
            }
        }
    }' total_active=$total_active
}

# 生成访问次数
function gen_times()
{
    # 当天活跃用户数
    local total_active=`wc -l $file_active | awk '{print $1}'`

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
    range_times | while read vtimes range; do
        sed -n "$range p" $file_active1 |
        awk -F '\t' 'BEGIN{
            srand()
            OFS=FS
        }{
            for(i=1;i<=num;i++){
                print $1,$2,$3
            }
        }' num=$vtimes >> $file_active2
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
                if(count[k] > 0){
                    acc += count[k]
                    pacc = acc - count[k]
                    printf("%d:%d,%d ",k, pacc + 1,acc)
                }
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
            hour=${hours_range[$i]%%:*}
            range=${hours_range[$i]#*:}
            sed -n "$range p" $file_active3 |
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
            }' idx=$hour >> $file_active4
        done
    done
}

# 生成访问时长
function gen_time()
{
    local total_visit=`wc -l $file_active4 | awk '{print $1}'`

    echo "$TIME_RANGE" | grep "^$prod_id " | awk 'BEGIN{
        srand()
    }{
        # 按占比分配
        for(i=2;i<=NF;i++){
            split($i,arr,":")
            atime[arr[1]] = int(total * arr[2] / 1000 + 0.5)
            sum += atime[arr[1]]
        }

        # 多减少加
        size = length(atime)
        rnd = int(rand() * size) + 1
        for(k in atime){
            j++
            if(rnd == j) atime[k] += total - sum
#            print k,atime[k]

            # 生成指定时长范围内的值
            split(k,karr,"-")
            for(x=1;x<=atime[k];x++){
                rtime = int(rand() * (karr[2] - karr[1] + 1))
                ftime = karr[1] + rtime
                print ftime
            }
        }
    }' total=$total_visit > $file_active5

    # 合并文件
    paste $file_active4 $file_active5 > $file_active6
}

# 替换aid
function replace_aid()
{
    # 排序
    sort $file_active6 -o $file_active6

    # 关联得到aid
    join -t "$sep" -o 2.2 1.2 1.3 1.4 1.5 1.6 $file_active6 $file_aid | sort -t $'\t' -k 5 > $file_visit
}

# 生成一天访问日志
function gen_visit1()
{
    local file_active=$data_dir/active.$the_date
    local file_visit=$data_dir/visit.$the_date

    if [[ ! -s $file_active ]]; then
        log "There is no visit log at $the_date"
        return
    fi

    # 生成访问次数
    log "Generate visit times"
    time(gen_times)

    # 生成访问时段
    log "Generate hours distribution"
    time(gen_hours)

    # 生成访问时长
    log "Generate visit time"
    time(gen_time)

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
    local file_active5=$tmp_dir/active5
    local file_active6=$tmp_dir/active6

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

    # 按天生成访问日志
    log "Generate visit day by day"
    range_date $start_date $end_date | while read the_date; do
        log "Generate visit for day $the_date"
        time(gen_visit1)
    done

    # 删除临时文件
    rm -f $file_active1 $file_active2 $file_active3 $file_active4 $file_active5 $file_active6
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
            ttimes=id[i]
            if(ttimes < 10) ttimes="0"ttimes
            atimes[ttimes]++
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
            pct=int(atimes[itimes[i]] / total * 1000 + 0.5)
            total_pct+=pct
            printf("%d\t",pct)
        }
        printf("%d\n",total_pct)
    }' $file_visit

    get_times | awk 'BEGIN{printf("设定\t")}{printf("%s\t",$2)}END{printf("1000\n")}'
}

# 校验时段分布
function check_hours()
{
    awk -F '\t' '{
        if(NR == FNR){
            thour=substr($5,12,2)
            city[$3]++
            cityh[$3,thour]++
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
    echo "Usage: $0 [ -a 生成Android ID <个数,是否入库> ] [ -b 生成访问日志 <产品ID,开始日期,结束日期,校验访问日志> ] [ -c 校验访问日志 <产品ID,开始日期,结束日期> ]"
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

    while getopts "a:b:c:v" opt; do
        args=(${OPTARG//,/ })
        case "$opt" in
            a)
                aid_count=${args[0]}
                aid_load=${args[1]};;
            b)
                if [[ ${#args[@]} -lt 3 ]]; then
                    print_usage
                    exit 1
                fi
                prod_id=${args[0]}
                start_date=${args[1]}
                end_date=${args[2]}
                visit_check=${args[3]}
                visit_gen=1;;
            c)
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
    if [[ $aid_count ]]; then
        log_fn gen_aid
    fi

    # 生成访问日志
    if [[ $visit_gen ]]; then
        log_fn gen_visit
    fi

    # 校验访问日志
    if [[ $visit_check ]]; then
        log_fn check_visit
    fi
}
main "$@"