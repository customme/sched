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
PRODS="adv_n	砾点广告平台
compass_n	智能指南针
file_n	快致文件管理
light_n	强光手电筒
recorder_n	随身录音机
search_n	立引搜索
shop_n	必购商城
weather_n	实时天气"

# 表名
# 新增量
TBL_NEW_CNT=l_all_add
# 地区占比
TBL_CITY_PCT=l_city_pct
# 留存率
TBL_KEEP_PCT=l_prod_keep

# 90日以后取留存天数
# 90~120 120~180 180~360 360~
RAND_DAYS=(30 45 60 75)

# 数据文件目录
DATADIR=$HOME/data2
# 临时文件目录
TMPDIR=$HOME/tmp2/$(date +%s%N)


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
    mkdir -p $DATADIR/$prod_id
    mkdir -p $TMPDIR/$prod_id
}

# 获取新增量
function get_new_cnt()
{
    local file_new_cnt=$DATADIR/$prod_id/new_cnt.$start_date
    if [[ ! -s $file_new_cnt ]]; then
        echo "SELECT stattime, cuscode, adduser FROM $TBL_NEW_CNT WHERE proname = '$prod_name' AND adduser > 0 AND stattime >= '$start_date' AND stattime <= '$end_date' ORDER BY stattime;" | exec_sql > $file_new_cnt
    fi

    awk -F '\t' 'BEGIN{OFS=FS} $1 == "'$the_date'" {print $2,$3}' $file_new_cnt
}

# 获取地区占比
function get_city_pct()
{
    local file_city_pct=$DATADIR/$prod_id/city_pct
    if [[ ! -s $file_city_pct ]]; then
        echo "SELECT city, pct FROM $TBL_CITY_PCT WHERE prod_name = '$prod_name';" | exec_sql > $file_city_pct
    fi

    cat $file_city_pct
}

# 获取产品留存率
function get_keep_pct()
{
    local file_keep_pct=$DATADIR/keep_pct
    if [[ ! -s $file_keep_pct ]]; then
        echo "SELECT * FROM $TBL_KEEP_PCT;" | exec_sql > $file_keep_pct
    fi

    awk -F '\t' '$1 == "'$prod_name'" {
        for(i=2;i<NF;i++){
            printf("%s ",$i)
        }
        printf("%s",$NF)
    }' $file_keep_pct
}

# 地区用户量区间
function range_city()
{
    get_city_pct | awk 'BEGIN{
        srand()
    }{
        rndpct = int($2 / 10 + 0.5)
        sign = rand()
        if(sign < 0.5) rndpct = -rndpct

        count = int(total * ($2 + rndpct) / 10000 + 0.5)
        city[++i] = $1" "count
        sum += count
#        print $1,count,sum
    }END{
        size = length(city)
        rnd = int(rand() * size) + 1
        diff = total - sum

        for(i=1;i<=size;i++){
            split(city[i],arr," ")
            if(i == rnd){
                cnt = arr[2] + diff
            }else{
                cnt = arr[2]
            }
            if(cnt > 0){
                acc += cnt
                pacc = acc - cnt
                printf("%s\t%d,%d\n",arr[1],pacc+1,acc)
            }
        }
    }' total=$total_new
}

# 生成一天新增
function gen_new1()
{
    local max_id=0
    if [[ -s $file_maxid ]]; then
        max_id=`cat $file_maxid`
    fi

    # 按渠道新增量分配ID
    get_new_cnt | awk -F '\t' 'BEGIN{
        OFS=FS
    }{
        for(i=0;i<$2;i++){
            print ++id,$1
        }
    }' id=$max_id > $file_new1

    local total_new=`cat $file_new1 | wc -l`

    # 按地区占比分配地区
    range_city | tee $file_city_rng | while read city range; do
        sed -n "$range p" $file_new1 | awk -F '\t' 'BEGIN{OFS=FS}{print $0,"'$city'"}'
    done > $file_new

    # 更新最大id
    if [[ -s $file_new ]]; then
        tail -n 1 $file_new | cut -f 1 > $file_maxid
    fi
}

# 生成新增
function gen_new()
{
    local file_maxid=$DATADIR/max_id
    local file_new1=$TMPDIR/$prod_id/new1
    local file_city_rng=$TMPDIR/$prod_id/city_range

    range_date $start_date $end_date | while read the_date; do
        file_new=$DATADIR/$prod_id/new.$the_date

        # 生成一天新增
        log "Generate new for day $the_date"
        gen_new1
    done

    # 删除临时文件
    rm -f $file_new1 $file_city_rng
}

# 随机日期
function rand_days()
{
    if [[ $date_diff -le 90 ]]; then
        range_date $min_date $date60 | sed '$d'
    elif [[ $date_diff -le 120 ]]; then
        range_date $min_date $date60 | sed '$d' | sort -R | head -n ${RAND_DAYS[0]}
    elif [[ $date_diff -le 180 ]]; then
        range_date $min_date $date60 | sed '$d' | sort -R | head -n ${RAND_DAYS[1]}
    elif [[ $date_diff -le 360 ]]; then
        range_date $min_date $date60 | sed '$d' | sort -R | head -n ${RAND_DAYS[2]}
    else
        range_date $min_date $date60 | sed '$d' | sort -R | head -n ${RAND_DAYS[3]}
    fi
}

# 生成一天活跃
function gen_active1()
{
    local date1=`date +%F -d "$the_date 1 day ago"`
    local date2=`date +%F -d "$the_date 2 day ago"`
    local date3=`date +%F -d "$the_date 3 day ago"`
    local date4=`date +%F -d "$the_date 4 day ago"`
    local date5=`date +%F -d "$the_date 5 day ago"`
    local date6=`date +%F -d "$the_date 6 day ago"`
    local date7=`date +%F -d "$the_date 7 day ago"`
    local date14=`date +%F -d "$the_date 14 day ago"`
    local date30=`date +%F -d "$the_date 30 day ago"`
    local date60=`date +%F -d "$the_date 60 day ago"`
    log "date1=$date1, date7=$date7, date14=$date14, date30=$date30, date60=$date60"

    local date_diff=`echo "$min_date $the_date" | awk '{
        gsub("-"," ",$1)
        gsub("-"," ",$2)
        date1 = mktime($1" 00 00 00")
        date2 = mktime($2" 00 00 00")
        date_diff = (date2 - date1) / 86400
        print date_diff
    }'`
    log "min_date=$min_date, date_diff=$date_diff"

    # 当天新增
    local file_active=$DATADIR/$prod_id/active.$the_date
    if [[ -s $DATADIR/$prod_id/new.$the_date ]]; then
        cp -f $DATADIR/$prod_id/new.$the_date $file_active
    else
        > $file_active
    fi

    # 产品留存率
    local keep_pct=(`get_keep_pct`)

    # 次日留存
    if [[ $date_diff -ge 1 && -s $DATADIR/$prod_id/new.$date1 ]]; then
        local total=`cat $DATADIR/$prod_id/new.$date1 | wc -l`
        local count=`echo ${keep_pct[0]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        log "keep1=${keep_pct[0]}, total=$total, count=$count"
        sort -R $DATADIR/$prod_id/new.$date1 | head -n $count >> $file_active
    fi

    # 2日留存
    if [[ $date_diff -ge 2 && -s $DATADIR/$prod_id/new.$date2 ]]; then
        local total=`cat $DATADIR/$prod_id/new.$date2 | wc -l`
        local count=`echo ${keep_pct[1]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        log "keep2=${keep_pct[1]}, total=$total, count=$count"
        sort -R $DATADIR/$prod_id/new.$date2 | head -n $count >> $file_active
    fi

    # 3日留存
    if [[ $date_diff -ge 3 && -s $DATADIR/$prod_id/new.$date3 ]]; then
        local total=`cat $DATADIR/$prod_id/new.$date3 | wc -l`
        local count=`echo ${keep_pct[2]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        log "keep3=${keep_pct[2]}, total=$total, count=$count"
        sort -R $DATADIR/$prod_id/new.$date3 | head -n $count >> $file_active
    fi

    # 4日留存
    if [[ $date_diff -ge 4 && -s $DATADIR/$prod_id/new.$date4 ]]; then
        local total=`cat $DATADIR/$prod_id/new.$date4 | wc -l`
        local count=`echo ${keep_pct[3]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        log "keep4=${keep_pct[3]}, total=$total, count=$count"
        sort -R $DATADIR/$prod_id/new.$date4 | head -n $count >> $file_active
    fi

    # 5日留存
    if [[ $date_diff -ge 5 && -s $DATADIR/$prod_id/new.$date5 ]]; then
        local total=`cat $DATADIR/$prod_id/new.$date5 | wc -l`
        local count=`echo ${keep_pct[4]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        log "keep5=${keep_pct[4]}, total=$total, count=$count"
        sort -R $DATADIR/$prod_id/new.$date5 | head -n $count >> $file_active
    fi

    # 6日留存
    if [[ $date_diff -ge 6 && -s $DATADIR/$prod_id/new.$date6 ]]; then
        local total=`cat $DATADIR/$prod_id/new.$date6 | wc -l`
        local count=`echo ${keep_pct[5]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        log "keep6=${keep_pct[5]}, total=$total, count=$count"
        sort -R $DATADIR/$prod_id/new.$date6 | head -n $count >> $file_active
    fi

    # 7日留存
    if [[ $date_diff -ge 7 && -s $DATADIR/$prod_id/new.$date7 ]]; then
        local total=`cat $DATADIR/$prod_id/new.$date7 | wc -l`
        local count=`echo ${keep_pct[6]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        log "keep7=${keep_pct[6]}, total=$total, count=$count"
        sort -R $DATADIR/$prod_id/new.$date7 | head -n $count >> $file_active
    fi

    # 8-14日留存
    if [[ $date_diff -ge 8 ]]; then
        local date8=$date14
        if [[ $min_date > $date14 ]]; then
            date8=$min_date
        fi
        range_date $date8 $date7 | sed '$d' | while read the_date1; do
            if [[ -s $DATADIR/$prod_id/new.$the_date1 ]]; then
                cat $DATADIR/$prod_id/new.$the_date1
            fi
        done > $file_active1

        local total=`cat $file_active1 | wc -l`
        local count=`echo ${keep_pct[7]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        log "keep14=${keep_pct[7]}, total=$total, count=$count"
        sort -R $file_active1 | head -n $count >> $file_active
    fi

    # 15-30日留存
    if [[ $date_diff -ge 15 ]]; then
        local date15=$date30
        if [[ $min_date > $date30 ]]; then
            date15=$min_date
        fi
        range_date $date15 $date14 | sed '$d' | while read the_date1; do
            if [[ -s $DATADIR/$prod_id/new.$the_date1 ]]; then
                cat $DATADIR/$prod_id/new.$the_date1
            fi
        done > $file_active1

        local total=`cat $file_active1 | wc -l`
        local count=`echo ${keep_pct[8]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        log "keep30=${keep_pct[8]}, total=$total, count=$count"
        sort -R $file_active1 | head -n $count >> $file_active
    fi

    # 31-60日留存
    if [[ $date_diff -ge 31 ]]; then
        local date31=$date60
        if [[ $min_date > $date60 ]]; then
            date31=$min_date
        fi
        range_date $date31 $date30 | sed '$d' | while read the_date1; do
            if [[ -s $DATADIR/$prod_id/new.$the_date1 ]]; then
                cat $DATADIR/$prod_id/new.$the_date1
            fi
        done > $file_active1

        local total=`cat $file_active1 | wc -l`
        local count=`echo ${keep_pct[9]} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        log "keep60=${keep_pct[9]}, total=$total, count=$count"
        sort -R $file_active1 | head -n $count >> $file_active
    fi

    # 60~日留存
    if [[ $date_diff -ge 61 ]]; then
        rand_days | while read the_date1; do
            if [[ -s $DATADIR/$prod_id/new.$the_date1 ]]; then
                cat $DATADIR/$prod_id/new.$the_date1
            fi
        done > $file_active1

        local total=`cat $file_active1 | wc -l`
        local count=`echo ${keep_pct0:-${keep_pct[10]}} $total | awk 'BEGIN{
            srand()
        }{
            split($1,arr,"+")
            rnd = int(rand() * (arr[2] + 1))
            cnt = int($2 * (arr[1] + rnd) / 1000 + 0.5)
            print cnt
        }'`
        log "keep0=${keep_pct0:-${keep_pct[10]}}, total=$total, count=$count"
        sort -R $file_active1 | head -n $count >> $file_active
    fi
}

# 生成活跃
function gen_active()
{
    local file_active1=$TMPDIR/$prod_id/active1

    range_date $start_date $end_date | while read the_date; do
        # 生成一天活跃
        log "Generate active for day $the_date"
        gen_active1
    done

    # 删除临时文件
    rm -f $file_active1
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 [ -a 生成新增 <产品ID,开始日期,结束日期,生成活跃> ] [ -b 生成活跃 <产品ID,开始日期,结束日期> ]"
    echo "${PRODS[@]}" | awk 'BEGIN{
        print "产品列表:"
    }{
        size=13-length($1)+length($2)
        printf("  %s% *s\n",$1,size,$2)
    }'
}

function main()
{
    if [[ $# -lt 1 ]]; then
        print_usage
        exit 1
    fi

    while getopts "a:b:v" opt; do
        args=(${OPTARG//,/ })
        case "$opt" in
            a)
                prod_id=${args[0]}
                start_date=${args[1]}
                end_date=${args[2]}
                active_gen=${args[3]}
                new_gen=1;;
            b)
                prod_id=${args[0]}
                start_date=${args[1]}
                end_date=${args[2]}
                keep_pct0=${args[3]}
                active_gen=1;;
            v)
                debug_flag=1;;
            ?)
                print_usage
                exit 1;;
        esac
    done

    set -e

    start_date=`date +%F -d "$start_date"`
    end_date=`date +%F -d "$end_date"`
    prod_name=`echo "$PRODS" | awk '$1 == "'$prod_id'" {print $2}'`
    min_date=`echo "SELECT MIN(stattime) FROM $TBL_NEW_CNT WHERE proname = '$prod_name';" | exec_sql`

    log_fn init

    if [[ $new_gen ]]; then
        log_fn gen_new
    fi

    if [[ $active_gen ]]; then
        log_fn gen_active
    fi
}
main "$@"