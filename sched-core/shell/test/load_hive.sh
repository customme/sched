#!/bin/bash
#
# 新增活跃导入hive


# 数据文件目录
DATADIR=$HOME/data
# 临时文件目录
TMPDIR=$HOME/tmp

# 目标数据库
TAR_DB=sdk_dw

# 表名前缀
TP_NEW=fact_new_
TP_ACTIVE=fact_active_

# hive用户
HIVE_USER=hive


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
    local params="${2:--S}"

    if [[ `whoami` = $HIVE_USER ]]; then
        hive --database $TAR_DB $params -e "$sql"
    elif [[ $UID -eq 0 ]]; then
        su -l $HIVE_USER -c "hive --database $TAR_DB $params -e \"$sql\""
    else
        sudo su -l $HIVE_USER -c "hive --database $TAR_DB $params -e \"$sql\""
    fi
}

# 装载新增
function load_new()
{
    echo "CREATE TABLE IF NOT EXISTS $table_new (
      aidid BIGINT,
      cuscode VARCHAR(64),
      city VARCHAR(64)
    ) PARTITIONED BY (create_date INT) ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE;
    " | exec_sql

    ls $DATADIR/$prod_id/new.201* | while read the_file; do
        the_date=${the_file##*.}
        log "Load file $the_file"

        echo "LOAD DATA LOCAL INPATH '$the_file' INTO TABLE $table_new PARTITION (create_date = ${the_date//-/});" | exec_sql
    done
}

# 装载活跃
function load_active()
{
    mkdir -p $TMPDIR/$prod_id
    local file_new=$TMPDIR/$prod_id/new
    local file_active=$TMPDIR/$prod_id/active

    # 合并截止开始日期前一天的新增
    local start_date1=`date +%F -d "$start_date"`
    rm -f $file_new
    ls $DATADIR/$prod_id/new.201* | sed "/$start_date1/Q" | while read the_file; do
        the_date=${the_file##*.}
        awk 'BEGIN{
            OFS="\t"
        }{
            print $1,"'${the_date}'"
        }' $the_file >> $file_new
    done

    echo "CREATE TABLE IF NOT EXISTS $table_active (
      aidid BIGINT,
      cuscode VARCHAR(64),
      city VARCHAR(64),
      create_date INT,
      date_diff INT
    ) PARTITIONED BY (active_date INT) ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE;
    " | exec_sql

    # 按天装载活跃
    range_date $start_date $end_date | while read the_date; do
        the_file=$DATADIR/$prod_id/active.$the_date
        log "Load file $the_file"

        # 合并当天新增
        awk 'BEGIN{
            OFS="\t"
        }{
            print $1,"'${the_date}'"
        }' $DATADIR/$prod_id/new.$the_date >> $file_new

        # 排序
        sort $file_new -o $file_new
        sort $the_file -o $the_file

        # 关联新增得到新增日期
        join -t "$sep" $the_file $file_new | awk -F '\t' 'BEGIN{
            OFS=FS
        }{
            gsub("-"," ",$4)
            adate="'$the_date'"
            gsub("-"," ",adate)

            ctime=mktime($4" 00 00 00")
            atime=mktime(adate" 00 00 00")
            time_diff=int((atime - ctime) / 86400)
            gsub(" ","",$4)
            print $1,$2,$3,$4,time_diff
        }' > $file_active

        echo "LOAD DATA LOCAL INPATH '$file_active' INTO TABLE $table_active PARTITION (active_date = ${the_date//-/});" | exec_sql
    done

    # 删除临时文件
    rm -f $file_new $file_active
}

# 手动执行
function manual()
{
    DATADIR=$HOME/data
    prod_id=shop

    zip ${prod_id}-new.zip $DATADIR/$prod_id/new.201*
    zip ${prod_id}-active.zip $DATADIR/$prod_id/active.201*

    unzip -j ${prod_id}-new.zip -d $DATADIR/$prod_id
    unzip -j ${prod_id}-active.zip -d $DATADIR/$prod_id
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 产品ID 开始日期 结束日期"
}

function main()
{
    if [[ $# -lt 1 ]]; then
        print_usage
        exit 1
    fi

    prod_id="$1"
    start_date="$2"
    end_date="$3"

    table_new=${TP_NEW}$prod_id
    table_active=${TP_ACTIVE}$prod_id

    export LC_ALL=C
    sep=`echo -e "\t"`
    set -e

    if [[ $# -lt 3 ]]; then
        local dates=(`ls $DATADIR/$prod_id/active.201* | xargs -r -I {} basename {} | awk -F '.' '{print $2}' | sort | awk '{date[++i]=$1}END{printf("%s %s",date[1],date[length(date)])}'`)
        if [[ -z "$start_date" ]]; then
            start_date=${dates[0]//-/}
        fi
        end_date=${dates[1]//-/}
    fi

    log_fn load_new

    log_fn load_active
}
main "$@"