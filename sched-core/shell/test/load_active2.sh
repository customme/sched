#!/bin/bash
#
# 新增活跃统计


MYSQL_HOST=localhost
MYSQL_PORT=3308
MYSQL_USER=root
MYSQL_PASSWD=mysql
MYSQL_DB=ad_dw2
MYSQL_CHARSET=utf8

# 数据文件目录
DATADIR=$HOME/data2
# 临时文件目录
TMPDIR=$HOME/tmp2/$(date +%s%N)

# 表名前缀
TP_NEW=fact_new_
TP_ACTIVE=fact_active_
TP_AGG=agg_

# 预跑数据表
TBL_PRERUN=fact_prerun


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

# 装载新增
function load_new()
{
    # 创建表
    echo "CREATE TABLE IF NOT EXISTS $table_new (
      aidid BIGINT,
      cuscode VARCHAR(64),
      city VARCHAR(64),
      create_date INT,
      PRIMARY KEY(aidid)
    ) ENGINE=MyISAM COMMENT='新增用户';
    " | exec_sql

    # 按天导入
    range_date $start_date $end_date | while read the_date; do
        the_file=$DATADIR/$prod_id/new.$the_date
        if [[ -s $the_file ]]; then
            log "Load file $the_file"
            echo "LOAD DATA LOCAL INFILE '$the_file' INTO TABLE $table_new (aidid, cuscode, city) SET create_date = ${the_date//-/};" | exec_sql
        fi
    done

    # 添加索引
    echo "CREATE INDEX IF NOT EXISTS idx_cuscode ON $table_new (cuscode);
    CREATE INDEX IF NOT EXISTS idx_city ON $table_new (city);
    CREATE INDEX IF NOT EXISTS idx_create_date ON $table_new (create_date);
    " | exec_sql
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
            print $1,"'${the_date//-/}'"
        }' $the_file >> $file_new
    done

    echo "CREATE TABLE IF NOT EXISTS $table_active (
      aidid BIGINT,
      cuscode VARCHAR(64),
      city VARCHAR(64),
      active_date INT,
      create_date INT,
      date_diff INT,
      PRIMARY KEY(aidid, active_date)
    ) ENGINE=MyISAM COMMENT='活跃用户';
    " | exec_sql

    # 按天装载活跃
    range_date $start_date $end_date | while read the_date; do
        the_file=$DATADIR/$prod_id/active.$the_date
        log "Load file $the_file"

        # 合并当天新增
        if [[ -s $DATADIR/$prod_id/new.$the_date ]]; then
            awk 'BEGIN{
                OFS="\t"
            }{
                print $1,"'${the_date//-/}'"
            }' $DATADIR/$prod_id/new.$the_date >> $file_new
        fi

        # 排序
        sort $file_new -o $file_new
        sort $the_file -o $the_file

        # 关联新增得到新增日期
        join -t "$sep" $the_file $file_new > $file_active

        echo "LOAD DATA LOCAL INFILE '$file_active' INTO TABLE $table_active (aidid, cuscode, city, create_date, active_date, date_diff)
        SET active_date = ${the_date//-/}, date_diff = DATEDIFF(${the_date//-/}, create_date);
        " | exec_sql
    done

    # 添加索引
    echo "CREATE INDEX IF NOT EXISTS idx_cuscode ON $table_active (cuscode);
    CREATE INDEX IF NOT EXISTS idx_city ON $table_active (city);
    CREATE INDEX IF NOT EXISTS idx_active_date ON $table_active (active_date);
    CREATE INDEX IF NOT EXISTS idx_create_date ON $table_active (create_date);
    CREATE INDEX IF NOT EXISTS idx_date_diff ON $table_active (date_diff);
    " | exec_sql

    # 删除临时文件
    rm -f $file_new $file_active
}

# 聚合新增
function agg_new()
{
    echo "CREATE TABLE IF NOT EXISTS ${TP_AGG}l_01_new_$prod_id (
      create_date INT,
      fact_count INT,
      PRIMARY KEY(create_date)
    ) ENGINE=MyISAM;
    REPLACE INTO ${TP_AGG}l_01_new_$prod_id
    SELECT create_date, COUNT(1)
    FROM ${TP_NEW}$prod_id
    WHERE create_date >= ${start_date//-/} AND create_date <= ${end_date//-/}
    GROUP BY create_date;

    CREATE TABLE IF NOT EXISTS ${TP_AGG}l_02_new_$prod_id (
      create_date INT,
      cuscode VARCHAR(64),
      fact_count INT,
      PRIMARY KEY(create_date, cuscode)
    ) ENGINE=MyISAM;
    REPLACE INTO ${TP_AGG}l_02_new_$prod_id
    SELECT create_date, cuscode, COUNT(1)
    FROM ${TP_NEW}$prod_id
    WHERE create_date >= ${start_date//-/} AND create_date <= ${end_date//-/}
    GROUP BY create_date, cuscode;

    CREATE TABLE IF NOT EXISTS ${TP_AGG}l_03_new_$prod_id (
      create_date INT,
      city VARCHAR(64),
      fact_count INT,
      PRIMARY KEY(create_date, city)
    ) ENGINE=MyISAM;
    REPLACE INTO ${TP_AGG}l_03_new_$prod_id
    SELECT create_date, city, COUNT(1)
    FROM ${TP_NEW}$prod_id
    WHERE create_date >= ${start_date//-/} AND create_date <= ${end_date//-/}
    GROUP BY create_date, city;

    CREATE TABLE IF NOT EXISTS ${TP_AGG}l_04_new_$prod_id (
      create_date INT,
      cuscode VARCHAR(64),
      city VARCHAR(64),
      fact_count INT,
      PRIMARY KEY(create_date, cuscode, city)
    ) ENGINE=MyISAM;
    REPLACE INTO ${TP_AGG}l_04_new_$prod_id
    SELECT create_date, cuscode, city, COUNT(1)
    FROM ${TP_NEW}$prod_id
    WHERE create_date >= ${start_date//-/} AND create_date <= ${end_date//-/}
    GROUP BY create_date, cuscode, city;
    " | exec_sql
}

# 聚合活跃
function agg_active()
{
    echo "CREATE TABLE IF NOT EXISTS ${TP_AGG}l_01_active_$prod_id (
      active_date INT,
      create_date INT,
      date_diff INT,
      fact_count INT,
      PRIMARY KEY(active_date, create_date)
    ) ENGINE=MyISAM;
    REPLACE INTO ${TP_AGG}l_01_active_$prod_id
    SELECT active_date, create_date, date_diff, COUNT(1)
    FROM ${TP_ACTIVE}$prod_id
    WHERE active_date >= ${start_date//-/} AND active_date <= ${end_date//-/}
    GROUP BY active_date, create_date;

    CREATE TABLE IF NOT EXISTS ${TP_AGG}l_02_active_$prod_id (
      active_date INT,
      create_date INT,
      date_diff INT,
      cuscode VARCHAR(64),
      fact_count INT,
      PRIMARY KEY(active_date, create_date, cuscode)
    ) ENGINE=MyISAM;
    REPLACE INTO ${TP_AGG}l_02_active_$prod_id
    SELECT active_date, create_date, date_diff, cuscode, COUNT(1)
    FROM ${TP_ACTIVE}$prod_id
    WHERE active_date >= ${start_date//-/} AND active_date <= ${end_date//-/}
    GROUP BY active_date, create_date, cuscode;

    CREATE TABLE IF NOT EXISTS ${TP_AGG}l_03_active_$prod_id (
      active_date INT,
      create_date INT,
      date_diff INT,
      city VARCHAR(64),
      fact_count INT,
      PRIMARY KEY(active_date, create_date, city)
    ) ENGINE=MyISAM;
    REPLACE INTO ${TP_AGG}l_03_active_$prod_id
    SELECT active_date, create_date, date_diff, city, COUNT(1)
    FROM ${TP_ACTIVE}$prod_id
    WHERE active_date >= ${start_date//-/} AND active_date <= ${end_date//-/}
    GROUP BY active_date, create_date, city;

    CREATE TABLE IF NOT EXISTS ${TP_AGG}l_04_active_$prod_id (
      active_date INT,
      create_date INT,
      date_diff INT,
      cuscode VARCHAR(64),
      city VARCHAR(64),
      fact_count INT,
      PRIMARY KEY(active_date, create_date, cuscode, city)
    ) ENGINE=MyISAM;
    REPLACE INTO ${TP_AGG}l_04_active_$prod_id
    SELECT active_date, create_date, date_diff, cuscode, city, COUNT(1)
    FROM ${TP_ACTIVE}$prod_id
    WHERE active_date >= ${start_date//-/} AND active_date <= ${end_date//-/}
    GROUP BY active_date, create_date, cuscode, city;
    " | exec_sql
}

# 聚合表
function agg_table()
{
    agg_new

    agg_active
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
    pre_run="${4:-1}"

    if [[ $pre_run -eq 0 ]]; then
        echo "CREATE TABLE IF NOT EXISTS $TBL_PRERUN (
          prod_id VARCHAR(32),
          the_date INT,
          new_cnt INT,
          keep1_cnt INT,
          keep2_cnt INT,
          keep3_cnt INT,
          keep4_cnt INT,
          keep5_cnt INT,
          keep6_cnt INT,
          keep7_cnt INT,
          keep14_cnt INT,
          keep30_cnt INT,
          keep60_cnt INT,
          keep0_cnt INT,
          PRIMARY KEY (prod_id, the_date)
          KEY idx_prod_id (prod_id),
          KEY idx_the_date (the_date)
        ) ENGINE=MyISAM COMMENT='预跑数据';

        LOAD DATA LOCAL INFILE '$DATADIR/$prod_id/pre_data.${start_date}-$end_date' REPLACE INTO TABLE $TBL_PRERUN" | exec_sql

        return
    fi

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

    log_fn agg_table
}
main "$@"