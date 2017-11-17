#!/bin/bash
#
# 生成数据


MYSQL_HOST=localhost
MYSQL_PORT=3308
MYSQL_USER=root
MYSQL_PASSWD=mysql
MYSQL_DB=third
MYSQL_CHARSET=utf8

# 数据文件目录
DATADIR=$HOME/data4
# 临时文件目录
TMPDIR=$HOME/tmp4/$(date +%s%N)


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
    echo "SELECT stattime, onadd FROM t_all_add_info WHERE proname = '$prod_id' AND onadd > 0;" | exec_sql > $file_add
    echo "SELECT cuscode, pct FROM t_all_add_online_cus WHERE proname = '$prod_id';" | exec_sql > $file_cust_pct
}

# 按比例分配客户
function allot_cust()
{
    local add_cnt=`awk -F '\t' '$1 == "'$the_date'" {print $2}' $file_add`

    awk -F '\t' 'BEGIN{
        OFS=FS
        srand()
    }{
        # 占比太小不浮动
        rnd = 0
        if($2 > 2){
            rnd = int(rand() * (2 + 1))
            sign = rand()
            if(sign < 0.5) rnd = - rnd
        }

        cust[$1] = int(total * ($2 + rnd) / 1000 + 0.5)
        if(cust[$1] < 0) cust[$1] = 0
        sum += cust[$1]
    }END{
        diff = total - sum
        size = length(cust)
        i = int(rand() * size) + 1

        for(k in cust){
            if(++j == i) cust[k] += diff
            if(cust[k] > 0) print k,cust[k]
        }
    }' total=$add_cnt $file_cust_pct
}

function main()
{
    prod_id="$1"
    start_date="$2"
    end_date="$3"

    mkdir -p $DATADIR/$prod_id

    file_add=$DATADIR/$prod_id/add
    file_cust_pct=$DATADIR/$prod_id/cust_pct

    export_data

    range_date $start_date $end_date | while read the_date; do
        allot_cust | awk '{
            printf("INSERT INTO t_all_add_online (stattime, adduser, cuscode, proname) VALUES ('\''%s'\'', %d, '\''%s'\'', '\''%s'\'');\n","'$the_date'", $2, $1, "'$prod_id'")
        }'
    done | exec_sql
}
main "$@"