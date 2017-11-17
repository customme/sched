#!/bin/bash
#
# 生成广告展现、点击


MYSQL_HOST=localhost
MYSQL_PORT=3308
MYSQL_USER=root
MYSQL_PASSWD=mysql
MYSQL_DB=third
MYSQL_CHARSET=utf8

# 数据文件目录
DATADIR=$HOME/data3
# 临时文件目录
TMPDIR=$HOME/tmp3/$(date +%s%N)


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

# 导出数据
function export_data()
{
    if [[ ! -s $file_ad_cnt ]]; then
        echo "SELECT stat_date, advertiser_id, ad_id, showcnt, clickcnt FROM t_advertise_cnt;" | exec_sql > $file_ad_cnt
    fi
}

# 生成广告展示、点击
function gen_ad()
{
    rm -f $file_ad_show $file_ad_click

    sed '/ 23:57/,$d' $file_visit > $file_ad_show1

    awk '$1 == "'$the_date'"' $file_ad_cnt | while read stat_date advertiser_id ad_id showcnt clickcnt; do
        # 生成展示
        log "Gen ad show log $showcnt"
        sort -R $file_ad_show1 | head -n $showcnt | awk -F '\t' 'BEGIN{
            OFS=FS
            srand()
        }{
            visit_time = $5
            gsub(/-|:/," ",$5)
            time1 = mktime($5)
            day1 = strftime("%d",time1)
            time2 = time1 + int(rand() * (180 - 60 + 1) + 60)
            day2 = strftime("%d",time2)
            if(day1 == day2){
                show_time = strftime("%Y-%m-%d %H:%M:%S",time2)
            }else{
                show_time = visit_time
            }

            print $1,$2,$3,$4,show_time,1,"'$ad_id'","'$advertiser_id'"
        }' > $file_ad_show2

        # 生成点击
        log "Gen ad click log $clickcnt"
        grep -v " 23:59" $file_ad_show2 | sort -R | head -n $clickcnt | awk -F '\t' 'BEGIN{
            OFS=FS
            srand()
        }{
            show_time = $5

            gsub(/-|:/," ",$5)
            time1 = mktime($5)
            day1 = strftime("%d",time1)
            time2 = time1 + int(rand() * 60 + 1)
            day2 = strftime("%d",time2)
            if(day1 == day2){
                click_time = strftime("%Y-%m-%d %H:%M:%S",time2)
            }else{
                click_time = show_time
            }

            print $1,$2,$3,$4,click_time,2,$7,$8
        }' >> $file_ad_click

        cat $file_ad_show2 >> $file_ad_show
    done

    # 按展示/点击时间排序
    log "Sort by show time"
    sort -t $'\t' -k 5 $file_ad_show -o $file_ad_show
    log "Sort by click time"
    sort -t $'\t' -k 5 $file_ad_click -o $file_ad_click
}

function main()
{
    prod_id="$1"
    start_date="$2"
    end_date="$3"

    file_ad_cnt=$DATADIR/$prod_id/ad_cnt

    file_ad_show1=$TMPDIR/$prod_id/ad_show1
    file_ad_show2=$TMPDIR/$prod_id/ad_show2

    mkdir -p $TMPDIR/$prod_id

    export_data

    range_date $start_date $end_date | while read the_date; do
        log "Gen ad for day: $the_date"

        file_visit=$DATADIR/$prod_id/visit.$the_date
        file_ad_show=$DATADIR/$prod_id/show.$the_date
        file_ad_click=$DATADIR/$prod_id/click.$the_date

        gen_ad
    done

    # 删除临时文件
    rm -f $file_ad_show1 $file_ad_show2
}
main "$@"