# oracle工具


# 初始化数据库配置
function init_oracle_db()
{
    DEFAULT_DB_HOST=192.168.1.100
    DEFAULT_DB_USER=etl
    DEFAULT_DB_PASSWD=etl2014org
    DEFAULT_DB_NAME=orcl
    DEFAULT_DB_PORT=1521
    DEFAULT_DB_CHARSET=AL32UTF8
    DEFAULT_DB_URL=$(make_oracle_url)
}

# 执行sql语句
function oracle_executor()
{
    local sql="$1"
    local db_url="$2"

    if [[ -z "$sql" ]]; then
        sql=`cat`
    fi

    # 设置默认数据库连接
    if [[ -z "$db_url" ]]; then
        db_url=$DEFAULT_DB_URL
    fi

    # 记录sql日志
    if [[ "$SQL_LOG" = "$SWITCH_ON" ]]; then
        if [[ -z "$sql_log_file" ]]; then
            local sql_log_file=$sql_log_path/sql_$(date +%Y%m%d).log
        fi
        log "sql:[$sql]" >> $sql_log_file
    fi

    sqlplus -S -L /nolog << EOF
    connect $db_url
    set echo off
    set feedback off
    set heading off
    set wrap off
    set pagesize 0
    set linesize 1000
    set termout off
    set timing off
    set define off
    set trimspool on
    set colsep'|||'
    $sql
    commit
    quit
EOF
}

# 生成连接字符串
function make_oracle_url()
{
    local user="${1:-$DEFAULT_DB_USER}"
    local passwd="${2:-$DEFAULT_DB_PASSWD}"
    local db="${3:-$DEFAULT_DB_NAME}"
    local host="${4:-$DEFAULT_DB_HOST}"
    local port="${5:-$DEFAULT_DB_PORT}"

    if [ $# -eq 3 ]; then
        echo "$user/$passwd@$db"
    else
        echo "$user/$passwd@$host:$port/$db"
    fi
}

# 
# Globals:
# Arguments:
# Returns:
function get_keywords()
{
    echo ""
}

# 查找oracle关键字
# Globals:
# Arguments:
# Returns:
function find_keyword()
{
    # 表前缀
    local table_prefix=TMP_KEYWORD_

    if [[ ! -s keywords.txt ]]; then
        oracle_executor "select keyword from v\$reserved_words;" | awk '$1 ~/^[A-Z]*.*[A-Z]$/' > keywords.txt
    fi

    # 创建表
    cat keywords.txt | while read keyword; do
        echo "create table ${table_prefix}${keyword}($keyword number);"
    done | oracle_executor

    # 查询表是否存在
    cat keywords.txt | while read keyword; do
        echo "select '${table_prefix}${keyword}',count(*) from user_tables where table_name=upper('${table_prefix}${keyword}');"
    done | oracle_executor > keyword.txt

    # 清除表
    cat keywords.txt | while read keyword; do
        echo "create table ${table_prefix}${keyword}($keyword number);"
    done | oracle_executor

    # 提取关键字
    awk -F '\\|\\|\\|' '$2 == 0 {
        keyword=substr($1,length(table_prefix)+1)
        if(substr(keyword,1,1) == prev_key){
            value=value"\\|"keyword
        }else{
            if(value != "") print "    sed '\''s/^\\("value"\\) /the_\\1 /ig'\'' |"
            value=keyword
        }
        prev_key=substr(keyword,1,1)
    }' table_prefix=$table_prefix keyword.txt
}

# oracle关键字转换
# 加前缀the_
function oracle_keyword_conv()
{
    sed 's/^\(ACCESS\|ADD\|ALL\|ALTER\|AND\|ANY\|AS\|ASC\|AUDIT\) /the_\1 /ig' |
    sed 's/^\(BETWEEN\|BY\) /the_\1 /ig' |
    sed 's/^\(CHAR\|CHECK\|CLUSTER\|COLUMN\|COMMENT\|COMPRESS\|CONNECT\|CREATE\|CURRENT\) /the_\1 /ig' |
    sed 's/^\(DATE\|DECIMAL\|DEFAULT\|DELETE\|DESC\|DISTINCT\|DROP\) /the_\1 /ig' |
    sed 's/^\(ELSE\|EXCLUSIVE\|EXISTS\) /the_\1 /ig' |
    sed 's/^\(FILE\|FLOAT\|FOR\|FROM\) /the_\1 /ig' |
    sed 's/^\(GRANT\|GROUP\) /the_\1 /ig' |
    sed 's/^\(HAVING\) /the_\1 /ig' |
    sed 's/^\(IDENTIFIED\|IMMEDIATE\|IN\|INCREMENT\|INDEX\|INITIAL\|INSERT\|INTEGER\|INTERSECT\|INTO\|IS\) /the_\1 /ig' |
    sed 's/^\(LEVEL\|LIKE\|LOCK\|LONG\) /the_\1 /ig' |
    sed 's/^\(MAXEXTENTS\|MINUS\|MLSLABEL\|MODE\|MODIFY\) /the_\1 /ig' |
    sed 's/^\(NOAUDIT\|NOCOMPRESS\|NOT\|NOWAIT\|NULL\|NUMBER\) /the_\1 /ig' |
    sed 's/^\(OF\|OFFLINE\|ON\|ONLINE\|OPTION\|OR\|ORDER\) /the_\1 /ig' |
    sed 's/^\(PCTFREE\|PRIOR\|PRIVILEGES\|PUBLIC\) /the_\1 /ig' |
    sed 's/^\(RAW\|RENAME\|RESOURCE\|REVOKE\|ROW\|ROWID\|ROWNUM\|ROWS\) /the_\1 /ig' |
    sed 's/^\(SELECT\|SESSION\|SET\|SHARE\|SIZE\|SMALLINT\|START\|SUCCESSFUL\|SYNONYM\|SYSDATE\) /the_\1 /ig' |
    sed 's/^\(TABLE\|THEN\|TO\|TRIGGER\) /the_\1 /ig' |
    sed 's/^\(UID\|UNION\|UNIQUE\|UPDATE\|USER\) /the_\1 /ig' |
    sed 's/^\(VALIDATE\|VALUES\|VARCHAR\|VARCHAR2\|VIEW\) /the_\1 /ig'
}

init_db
