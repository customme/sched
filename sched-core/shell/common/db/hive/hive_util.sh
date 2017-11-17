# hive工具


# 特殊字符转义
# (' ;)
function hive_escape()
{
    sed "s/\('\|;\)/\\\\\1/g"
}

# 转义特殊数据
# 1、把“NULL”转换成“\N”
# 2、删除“\r”
function hive_data_conv()
{
    sed 's/^NULL\t/\\N\t/g;s/\tNULL$/\t\\N/g;s/\tNULL\t/\t\\N\t/g;s/\tNULL\t/\t\\N\t/g;s/\r//g'
}

# 初始化数据库配置
function init_hive_db()
{
    DEFAULT_HIVE_HOST=localhost
    DEFAULT_HIVE_PORT=10000
    DEFAULT_HIVE_USER=hive
    DEFAULT_HIVE_PASSWD=123456
    DEFAULT_HIVE_NAME=test
    DEFAULT_HIVE_CHARSET=utf8
    DEFAULT_HIVE_EXTRAS="--showHeader=false --silent=true --outputformat=tsv2"
    DEFAULT_HIVE_URL=$(make_hive_url)
}

# 执行sql语句
function hive_executor()
{
    local sql="$1"
    local db_url="$2"

    if [[ -z "$sql" ]]; then
        sql=`cat`
    fi

    # 设置默认数据库连接
    if [[ -z "$db_url" ]]; then
        db_url=$DEFAULT_HIVE_URL
    fi

    # 记录sql日志
    if [[ "$SQL_LOG" = "$SWITCH_ON" ]]; then
        if [[ -z "$sql_log_file" ]]; then
            local sql_log_file=${LOG_DIR:-.}/`basename ${0%.*}`.sql.$(date +%Y%m%d)
        fi

        # 创建目录
        mkdir -p `dirname ${sql_log_file}`

        log "$db_url [ $sql ]" >> $sql_log_file
    fi

    if [[ "$db_url" =~ ^hive_user ]]; then
        eval `echo ${db_url%% *}`
        db_url=${db_url#* }
        if [[ `whoami` = $hive_user ]]; then
            hive $db_url -e "$sql"
        elif [[ $UID -eq 0 ]]; then
            su -l $hive_user -c "hive $db_url -e \"$sql\""
        else
            sudo su -l $hive_user -c "hive $db_url -e \"$sql\""
        fi
    else
        beeline $db_url -e "$sql"
    fi
}

# 生成连接字符串
function make_hive_url()
{
    local conn_type="$1"
    if [[ $conn_type -eq $DB_CONN_TYPE_JDBC ]]; then
        local host="${2:-$DEFAULT_HIVE_HOST}"
        local user="${3:-$DEFAULT_HIVE_USER}"
        local passwd="${4:-$DEFAULT_HIVE_PASSWD}"
        local db="${5:-$DEFAULT_HIVE_NAME}"
        local port="${6:-$DEFAULT_HIVE_PORT}"
        local extras="${7:-$DEFAULT_HIVE_EXTRAS}"

        echo "-u jdbc:hive2://${host}:${port}/$db -n $user -p $passwd $extras"
    elif [[ $conn_type -eq $DB_CONN_TYPE_CLI ]]; then
        local db="${2:-$DEFAULT_HIVE_NAME}"
        local user="${3:-$DEFAULT_HIVE_USER}"
        local extras="${4:--S}"

        echo "hive_user=$user --database $db $extras"
    fi
}

init_hive_db