# mysql工具


# 特殊字符转义
# 1、单引号
# 2、双引号
function mysql_escape()
{
    sed "s/\('\|\"\)/\\\\\1/g"
}

# 去掉mysql安全告警
function mysql_silent()
{
    grep -v ".*password.*command.*insecure"
}

# 转义特殊数据
# 1、把“NULL”转换成“\N”
function mysql_data_conv()
{
    sed 's/^NULL\t/\\N\t/ig;s/\tNULL$/\t\\N/ig;s/\tNULL\t/\t\\N\t/ig;s/\tNULL\t/\t\\N\t/ig'
}

# 初始化数据库配置
function init_mysql_db()
{
    DEFAULT_MYSQL_HOST=localhost
    DEFAULT_MYSQL_PORT=3306
    DEFAULT_MYSQL_USER=root
    DEFAULT_MYSQL_PASSWD=123456
    DEFAULT_MYSQL_NAME=test
    DEFAULT_MYSQL_CHARSET=utf8
    DEFAULT_MYSQL_EXTRAS="-s -N --local-infile"
    DEFAULT_MYSQL_URL=$(make_mysql_url)
}

# 执行sql语句
function mysql_executor()
{
    local sql="$1"
    local db_url="$2"

    if [[ -z "$sql" ]]; then
        sql=`cat`
    fi

    # 设置默认数据库连接
    if [[ -z "$db_url" ]]; then
        db_url=$DEFAULT_MYSQL_URL
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

    echo "$sql" | mysql $db_url
}

# 生成连接字符串
function make_mysql_url()
{
    local host="${1:-$DEFAULT_MYSQL_HOST}"
    local user="${2:-$DEFAULT_MYSQL_USER}"
    local passwd="${3:-$DEFAULT_MYSQL_PASSWD}"
    local db="${4:-$DEFAULT_MYSQL_NAME}"
    local port="${5:-$DEFAULT_MYSQL_PORT}"
    local charset="${6:-$DEFAULT_MYSQL_CHARSET}"
    local extras="${7:-$DEFAULT_MYSQL_EXTRAS}"

    echo "-h $host -P $port -u $user -p$passwd -D $db --default-character-set=$charset $extras"
}

# 获取表定义
# 参数:
#   包含字段
#   排除列表
function get_table_def()
{
    local columns="$1"
    local excludes="${2:-$UNDEFINED_VALUE}"

    # 首尾各一个空格，其他空格都去掉
    # 字段用“`”包起来，以免引起歧义
    local includes=`echo "$columns" | sed 's/^[[:blank:]]*/ /g;s/[[:blank:]]*$/ /g;s/[[:blank:]]*,[[:blank:]]*/,/g' |
    sed "s/ /\\\`/g;s/,/\\\`|\\\`/g"`"|CREATE TABLE|ENGINE="

    sed -n '/CREATE TABLE/,$p' | sed 's/Create Table: //i' | grep -iE "$includes" | grep -ivE "$excludes" 
}

init_mysql_db