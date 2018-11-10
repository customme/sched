#!/bin/bash
#
# 分配广告激活量、点击量、展现量
# 生成广告展现、点击、激活
# 用法:
: '
nohup sh gen_ad3.sh 2016-04-15 2017-07-31 > ad_n.log 2> ad_n.err &
nohup sh gen_ad3.sh 2016-04-28 2017-07-31 > ad.log 2> ad.err &
'


MYSQL_HOST=localhost
MYSQL_PORT=3308
MYSQL_USER=root
MYSQL_PASSWD=mysql
MYSQL_DB=bostar
MYSQL_CHARSET=utf8

# 数据仓库名
DW_NAME=ad_dw2

# 广告类型（1国内 2国外）
PROD_TYPE=1

# 国内产品
PRODS="adv_n,compass_n,file_n,light_n,recorder_n,search_n,weather_n,qtext_n,sport_n,space_n,broswer_n"

# 数据文件目录
DATADIR=/home/ad/logs
# 临时文件目录
TMPDIR=/home/ad/tmp/$(date +%s%N)

# ip文件
FILE_IP=$DATADIR/nip


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
    if [[ ! -s $file_income ]]; then
        log "Export data to file: $file_income"
        echo "SELECT stattime, adver, advname, adduser, shows, clicks, IF(city > '', city, NULL) FROM $table_income WHERE stattime >= '$start_date' AND stattime <= '$end_date';" | exec_sql > $file_income
    fi

    if [[ ! -s $file_ad_pct ]]; then
        log "Export ad pct to file: $file_ad_pct"
        echo "SELECT month, pct FROM $table_ad_pct WHERE month >= '${start_date%-*}' AND month <= '${end_date%-*}';" | exec_sql > $file_ad_pct
    fi
}

# 统计活跃占比
function stat_active()
{
    local arr_prod=(${prods//,/ })
    for prod_id in ${arr_prod[@]}; do
        file_active=$DATADIR/$prod_id/active.$the_date
        if [[ -s $file_active ]]; then
            wc -l $file_active | awk '{print $1}'
        else
            echo 0
        fi
    done | awk '{
        active_cnt[++i]=$1
        sum += $1
    }END{
        if(sum > 0){
            size = length(active_cnt)
            for(i=1;i<size;i++){
                printf("%s,",active_cnt[i] / sum)
            }
            printf("%s",active_cnt[size] / sum)
        }
    }'
}

# 统计活跃占比
function stat_active()
{
    echo "SELECT prod_id, uv FROM ${DW_NAME}.agg_active_all WHERE active_date = ${the_date//-/};" | exec_sql | awk -F '\t' 'BEGIN{
        split("'$prods'",prod_arr,",")
    }{
        prod[$1]=$2
    }END{
        for(i=1;i<=length(prod_arr);i++){
            active_cnt = prod[prod_arr[i]]
            if(active_cnt > 0){
                print active_cnt
            }else{
                print 0
            }
        }
    }' | awk '{
        active_cnt[++i]=$1
        sum += $1
    }END{
        if(sum > 0){
            size = length(active_cnt)
            for(i=1;i<size;i++){
                printf("%s,",active_cnt[i] / sum)
            }
            printf("%s",active_cnt[size] / sum)
        }
    }'
}

# 分配广告激活量、点击量、展示量
function allot_ad()
{
    > $file_ad_cnt

    range_date $start_date $end_date | while read the_date; do
        # 广告产品占比
        the_month=${the_date:0:7}
        the_pct=`awk -F '\t' '$1 == "'$the_month'" {print $2}' $file_ad_pct`
        # 如果没有指定占比，就用活跃占比
        if [[ -z "$the_pct" ]]; then
            log "Use active proportion"
            prods="$PRODS"
            ad_pct=`stat_active`
        else
            log "Use preset proportion"
            prods=`echo "$the_pct" | awk 'BEGIN{RS="[:,]"} NR % 2 == 1' | tr '\n' ',' | sed 's/,$//'`
            ad_pct=`echo "$the_pct" | awk 'BEGIN{RS="[:,]"} NR % 2 == 0 {printf("%s,",$1 / 100)}' | sed 's/,$//'`
        fi
        if [[ -z "$ad_pct" ]]; then
            log "Warn: Invalid products proportion"
            continue
        fi
        log "Products proportion: $prods $ad_pct"

        # 分配激活
        awk -F '\t' 'BEGIN{
            OFS=FS
            srand()

            split("'$prods'",arr_prod,",")
            split("'$ad_pct'",arr_pct,",")
        } $1 == "'$the_date'" && $3 !~ /^DS/ {
            sum = 0
            sum1 = 0
            sum2 = 0
            for(i in arr_pct){
                arr_cnt[i] = int(arr_pct[i] * $4 + 0.5)
                sum += arr_cnt[i]
                arr_cnt1[i] = int(arr_pct[i] * $5 + 0.5)
                sum1 += arr_cnt1[i]
                arr_cnt2[i] = int(arr_pct[i] * $6 + 0.5)
                sum2 += arr_cnt2[i]
            }
            # 多减少加
            diff = $4 - sum
            for(i in arr_cnt){
                if(arr_cnt[i] > 0 && arr_cnt[i] + diff > 0){
                    arr_cnt[i] += diff
                    break
                }
            }
            diff1 = $5 -sum1
            for(i in arr_cnt1){
                if(arr_cnt1[i] > 0 && arr_cnt1[i] + diff1 > 0){
                    arr_cnt1[i] += diff1
                    break
                }
            }
            diff2 = $6 -sum2
            for(i in arr_cnt2){
                if(arr_cnt2[i] > 0 && arr_cnt2[i] + diff2 > 0){
                    arr_cnt2[i] += diff2
                    break
                }
            }
            # 最终激活量
            for(i in arr_cnt){
                if(arr_cnt1[i] > 0){
                    print $1,arr_prod[i],$2,$3,arr_cnt1[i],arr_cnt2[i],arr_cnt[i],$7
                }
            }
        }' $file_income >> $file_ad_cnt

        # 海外广告特殊处理（以DS开头）
        # 展示数为0，这里用点击数代替，补充访问日志时用到
        awk -F '\t' 'BEGIN{
            OFS=FS
        } $1 == "'$the_date'" && $3 ~ /^DS/ {
            print $1,"shop",$2,$3,$4,$6,$6,$7
        }' $file_income >> $file_ad_cnt
    done
}

# 生成一天广告展示、点击、激活
function gen_ad1(){
    log "Gen ad for product: $prod_id"

    rm -f $file_show $file_click $file_install

    sed '/ 23:55/,$d' $file_visit | sort -t $'\t' -k 1,1 -u > $file_visit1

    # 补充访问日志
    local visit_count=`wc -l $file_visit1 | awk '{print $1}'`
    local max_count=`awk '$1 == "'$the_date'" && $2 == "'$prod_id'" {print $5}' $file_ad_cnt | sort -nr | head -n 1`
    local diff_count=`expr $max_count - $visit_count`
    if [[ $diff_count -gt 0 ]]; then
        log "Add visit log $diff_count"
        cp -f $file_visit1 $file_visit2
        local mom_count=`expr $diff_count / $visit_count`
        local mod_count=`expr $diff_count % $visit_count`
        for i in `seq $mom_count`; do
            cat $file_visit1 >> $file_visit2
        done
        if [[ $mod_count -gt 0 ]]; then
            sort -R $file_visit1 | head -n $mod_count >> $file_visit2
        fi
    else
        mv -f $file_visit1 $file_visit2
    fi

    oIFS=$IFS
    IFS=`echo -e "\t"`
    awk -F '\t' '$1 == "'$the_date'" && $2 == "'$prod_id'"' $file_ad_cnt | while read the_date prod_id adver adname show_cnt click_cnt install_cnt city; do
        if [[ "$city" != "NULL" ]]; then
            # 随机取一个城市
            city=`echo "$city" | awk -F ',' 'BEGIN{
                srand()
            }{
                rnd = int(rand() * NF + 1)
                print $rnd
            }'`
            # 随机获取城市100个ip段
            city_ips=`awk 'BEGIN{
                srand()
            } $1 == "'$city'" {
                split($2,arr,",")
                for(i in arr){
                    print arr[2],rand()
                }
            }' $FILE_IP |
            sort -k 2 | head -n 100 | awk '{printf("%s,",$1)}' | sed 's/,$//'`
            if [[ -z "$city_ips" ]]; then
                log "WARN: can not find ip for city: {$city} {$the_date, $prod_id, $adver, $adname}" >&2
            fi
        fi

        # 海外广告特殊处理（以DS开头）
        if [[ "$adname" =~ ^DS ]]; then
            # 直接生成点击（点击时间 = 访问时间 + 60 ~ 180s）
            sort -R $file_visit2 | head -n $click_cnt | awk -F '\t' 'BEGIN{
                OFS=FS
                srand()
            }{
                if(NR == 1 && city != "NULL"){
                    split(city_ips,ips_arr,",")
                    size = length(ips_arr)
                }

                gsub(/-|:/," ",$5)
                time1 = mktime($5)
                time2 = time1 + int(rand() * (180 - 60 + 1) + 60)
                click_time = strftime("%Y-%m-%d %H:%M:%S",time2)

                # 替换地区 ip
                the_city = $3
                the_ip = $4
                if(city != "NULL" && $3 != city){
                    # 取随机ip段
                    i_ips = int(rand() * size + 1)
                    ips = ips_arr[i_ips]

                    # 从ip段随机取ip
                    split(ips,ip_arr,":")
                    diff = ip_arr[2] - ip_arr[1]
                    ip = ip_arr[1] + int(rand() * (diff + 1))
                    ipa = rshift(and(ip, 0xFF000000), 24)"."rshift(and(ip, 0xFF0000), 16)"."rshift(and(ip, 0xFF00), 8)"."and(ip, 0xFF)

                    the_city = city
                    the_ip = ipa
                }

                print $1,$2,the_city,the_ip,click_time,"'$adver'","'$adname'"
            }' city="$city" city_ips="$city_ips" > $file_click1
        else
            # 生成展示（展示时间 = 访问时间 + 60 ~ 180s）
            sort -R $file_visit2 | head -n $show_cnt | awk -F '\t' 'BEGIN{
                OFS=FS
                srand()
            }{
                if(NR == 1 && city != "NULL"){
                    split(city_ips,ips_arr,",")
                    size = length(ips_arr)
                }

                gsub(/-|:/," ",$5)
                time1 = mktime($5)
                time2 = time1 + int(rand() * (180 - 60 + 1) + 60)
                show_time = strftime("%Y-%m-%d %H:%M:%S",time2)

                # 替换地区 ip
                the_city = $3
                the_ip = $4
                if(city != "NULL" && $3 != city){
                    # 取随机ip段
                    i_ips = int(rand() * size + 1)
                    ips = ips_arr[i_ips]

                    # 从ip段随机取ip
                    split(ips,ip_arr,":")
                    diff = ip_arr[2] - ip_arr[1]
                    ip = ip_arr[1] + int(rand() * (diff + 1))
                    ipa = rshift(and(ip, 0xFF000000), 24)"."rshift(and(ip, 0xFF0000), 16)"."rshift(and(ip, 0xFF00), 8)"."and(ip, 0xFF)

                    the_city = city
                    the_ip = ipa
                }

                print $1,$2,the_city,the_ip,show_time,"'$adver'","'$adname'"
            }' city="$city" city_ips="$city_ips" > $file_show1

            # 生成点击（点击时间 = 展示时间 + 1 ~ 60s）
            sort -R $file_show1 | head -n $click_cnt | awk -F '\t' 'BEGIN{
                OFS=FS
                srand()
            }{
                gsub(/-|:/," ",$5)
                time1 = mktime($5)
                time2 = time1 + int(rand() * 60 + 1)
                click_time = strftime("%Y-%m-%d %H:%M:%S",time2)

                print $1,$2,$3,$4,click_time,"'$adver'","'$adname'"
            }' > $file_click1

            # 生成激活（激活时间 = 点击时间 + 1 ~ 60s）
            sort -R $file_click1 | head -n $install_cnt | awk -F '\t' 'BEGIN{
                OFS=FS
                srand()
            }{
                gsub(/-|:/," ",$5)
                time1 = mktime($5)
                time2 = time1 + int(rand() * 60 + 1)
                install_time = strftime("%Y-%m-%d %H:%M:%S",time2)

                print $1,$2,$3,$4,install_time,"'$adver'","'$adname'"
            }' >> $file_install

            cat $file_show1 >> $file_show
        fi
        cat $file_click1 >> $file_click
    done
    IFS=$oIFS

    # 按展示/点击/激活时间排序
    log "Sort by show time"
    sort -t $'\t' -k 5 $file_show -o $file_show
    log "Sort by click time"
    sort -t $'\t' -k 5 $file_click -o $file_click
    log "Sort by install time"
    sort -t $'\t' -k 5 $file_install -o $file_install
}

# 生成广告展示、点击、激活
function gen_ad(){
    mkdir -p $TMPDIR

    file_visit1=$TMPDIR/visit1
    file_visit2=$TMPDIR/visit2
    file_show1=$TMPDIR/show1
    file_click1=$TMPDIR/click1

    range_date $start_date $end_date | while read the_date; do
        log "Gen ad for date: $the_date"

        the_month=${the_date:0:7}
        the_pct=`awk -F '\t' '$1 == "'$the_month'" {print $2}' $file_ad_pct`
        if [[ -z "$the_pct" ]]; then
            arr_prod=(${PRODS//,/ })
        else
            prods=`echo "$the_pct" | awk 'BEGIN{RS="[:,]"} NR % 2 == 1' | tr '\n' ',' | sed 's/,$//'`
            arr_prod=(${prods//,/ })
        fi
        arr_prod=(${arr_prod[@]} shop)

        for prod_id in ${arr_prod[@]}; do
            if [[ `grep "^$the_date" $file_ad_cnt | grep "$prod_id"` ]]; then
                file_visit=$DATADIR/$prod_id/visit.$the_date
                if [[ -s $file_visit ]]; then
                    file_show=$DATADIR/$prod_id/show.$the_date
                    file_click=$DATADIR/$prod_id/click.$the_date
                    file_install=$DATADIR/$prod_id/install.$the_date
                    gen_ad1
                else
                    log "ERROR: There is no visit log for date: $the_date, product: $prod_id" >&2
                    continue
                fi
            else
                log "WARN: There is no allocation for date: $the_date, product: $prod_id" >&2
                continue
            fi
        done
    done

    # 删除临时文件
    rm -rf $TMPDIR/*
}

# 统计
function stat_ad()
{
    range_date $start_date $end_date | while read the_date; do
        the_month=${the_date:0:7}
        the_pct=`awk -F '\t' '$1 == "'$the_month'" {print $2}' $file_ad_pct`
        if [[ -z "$the_pct" ]]; then
            arr_prod=(${PRODS//,/ })
        else
            prods=`echo "$the_pct" | awk 'BEGIN{RS="[:,]"} NR % 2 == 1' | tr '\n' ',' | sed 's/,$//'`
            arr_prod=(${prods//,/ })
        fi
        arr_prod=(${arr_prod[@]} shop)

        for prod_id in ${arr_prod[@]}; do
            file_show=$DATADIR/$prod_id/show.$the_date
            file_click=$DATADIR/$prod_id/click.$the_date
            file_install=$DATADIR/$prod_id/install.$the_date

            if [[ -s $file_show ]]; then
                awk -F '\t' 'BEGIN{
                    OFS=FS
                    stat_date = "'$the_date'"
                    gsub("-","",stat_date)
                } ARGIND == 1 {
                    sum1[$2"\t"$3"\t"$6"\t"$7] ++
                } ARGIND == 2 {
                    sum2[$2"\t"$3"\t"$6"\t"$7] ++
                } ARGIND == 3 {
                    sum3[$2"\t"$3"\t"$6"\t"$7] ++
                } END {
                    for(k in sum1){
                        print stat_date,"'$prod_id'",k,sum1[k],sum2[k],sum3[k]
                    }
                }' $file_show $file_click $file_install
            fi
        done
    done > $file_ad_stat

    echo "USE $DW_NAME;
    CREATE TABLE IF NOT EXISTS $table_ad_stat (
      stat_date INT,
      prod_id VARCHAR(20),
      cuscode VARCHAR(64),
      city VARCHAR(64),
      adver VARCHAR(50),
      adname VARCHAR(50),
      show_cnt INT,
      click_cnt INT,
      install_cnt INT
    ) ENGINE=MyISAM COMMENT='广告展现点击激活';

    DELETE FROM $table_ad_stat WHERE stat_date >= ${start_date//-/} AND stat_date <= ${end_date//-/};
    LOAD DATA LOCAL INFILE '$file_ad_stat' INTO TABLE $table_ad_stat;

    CREATE INDEX IF NOT EXISTS idx_stat_date ON $table_ad_stat (stat_date);
    CREATE INDEX IF NOT EXISTS idx_prod_id ON $table_ad_stat (prod_id);
    CREATE INDEX IF NOT EXISTS idx_cuscode ON $table_ad_stat (cuscode);
    CREATE INDEX IF NOT EXISTS idx_city ON $table_ad_stat (city);
    CREATE INDEX IF NOT EXISTS idx_adver ON $table_ad_stat (adver);
    CREATE INDEX IF NOT EXISTS idx_adname ON $table_ad_stat (adname);
    " | exec_sql

    # 活跃广告
    # 活跃
    local file_active1=$TMPDIR/active1
    range_date $start_date $end_date | while read the_date; do
        find $DATADIR -type d -nowarn -mindepth 1 | while read the_path; do
            prod_id=`basename $the_path`
            file_active=$DATADIR/$prod_id/active.$the_date
            if [[ -s $file_active ]]; then
                awk -F '\t' 'BEGIN{
                    OFS=FS
                }{
                    count[$2"$"$3]++
                }END{
                    for(key in count){
                        print "'${the_date//-/}'$'$prod_id'$"key,count[key]
                    }
                }' $file_active
            fi
        done
    done > $file_active1

    # 广告
    local file_ad1=$TMPDIR/ad1
    awk -F '\t' 'BEGIN{
        OFS=FS
    }{
        show_cnt[$1"$"$2"$"$3"$"$4] += $7
        click_cnt[$1"$"$2"$"$3"$"$4] += $8
        install_cnt[$1"$"$2"$"$3"$"$4] += $9
    }END{
        for(key in show_cnt){
            print key,show_cnt[key],click_cnt[key],install_cnt[key]
        }
    }' $file_ad_stat > $file_ad1

    # 排序
    export LC_ALL=C
    sep=`echo -e "\t"`
    sort $file_active1 -o $file_active1
    sort $file_ad1 -o $file_ad1
    # 关联
    join -t "$sep" $file_active1 $file_ad1 | sed 's/\$/\t/g' > $file_ad_active

    # 入库
    echo "USE $DW_NAME;
    CREATE TABLE IF NOT EXISTS $table_ad_active (
      stat_date INT,
      prod_id VARCHAR(20),
      cuscode VARCHAR(64),
      city VARCHAR(64),
      active_cnt INT,
      show_cnt INT,
      click_cnt INT,
      install_cnt INT
    ) ENGINE=MyISAM COMMENT='广告活跃展现点击激活';

    DELETE FROM $table_ad_active WHERE stat_date >= ${start_date//-/} AND stat_date <= ${end_date//-/};
    LOAD DATA LOCAL INFILE '$file_ad_active' INTO TABLE $table_ad_active;

    CREATE INDEX IF NOT EXISTS idx_stat_date ON $table_ad_active (stat_date);
    CREATE INDEX IF NOT EXISTS idx_prod_id ON $table_ad_active (prod_id);
    CREATE INDEX IF NOT EXISTS idx_cuscode ON $table_ad_active (cuscode);
    CREATE INDEX IF NOT EXISTS idx_city ON $table_ad_active (city);
    " | exec_sql
}

# 校验数据
function check_data()
{
    awk -F '\t' 'BEGIN{
        OFS=FS
    }{
        sum[$1"\t"$3"\t"$4] += $NF
    }END{
        for(k in sum){
            print k,sum[k]
        }
    }' $file_ad_cnt | sort
}

function print_usage()
{
    echo "Usage: $0 <开始日期> [结束日期]"
}

function main()
{
    if [[ $# -lt 1 ]]; then
        print_usage
        exit 1
    fi

    start_date="$1"
    end_date="${2:-$start_date}"

    export LC_ALL=C

    if [[ $PROD_TYPE -eq 1 ]]; then
        table_income=l_all_income
        file_income=$DATADIR/income_n.${start_date//-/}-${end_date//-/}
        table_ad_pct=l_all_income_pct
        file_ad_pct=$DATADIR/ad_pct_n.${start_date//-/}-${end_date//-/}
        file_ad_cnt=$DATADIR/ad_cnt_n.${start_date//-/}-${end_date//-/}
        file_ad_stat=$DATADIR/ad_stat_n.${start_date//-/}-${end_date//-/}
        table_ad_stat=fact_ad_n
        file_ad_active=$DATADIR/ad_active_n.${start_date//-/}-${end_date//-/}
        table_ad_active=fact_ad_active_n
    else
        table_income=l_all_income
        file_income=$DATADIR/income.${start_date//-/}-${end_date//-/}
        table_ad_pct=l_all_income_pct
        file_ad_pct=$DATADIR/ad_pct.${start_date//-/}-${end_date//-/}
        file_ad_cnt=$DATADIR/ad_cnt.${start_date//-/}-${end_date//-/}
        file_ad_stat=$DATADIR/ad_stat.${start_date//-/}-${end_date//-/}
        table_ad_stat=fact_ad
        file_ad_active=$DATADIR/ad_active.${start_date//-/}-${end_date//-/}
        table_ad_active=fact_ad_active
    fi

    # 导出激活量
    log_fn export_data

    # 分配广告激活量、点击量、展示量
    log_fn allot_ad

    # 生成广告展示、点击、激活
    log_fn gen_ad

    # 统计
    log_fn stat_ad
}
main "$@"