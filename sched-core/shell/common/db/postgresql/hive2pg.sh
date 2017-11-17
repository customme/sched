# hive到postgresql数据同步工具类
#
# 变量依赖:
#   源数据库连接: src_db_url
#   源数据库编码: src_db_charset
#   源表名: src_table
#   源表字段: src_columns
#   源表增量时间字段: src_time_columns
#   目标数据库连接: tar_db_url
#   目标数据库编码: tar_db_charset
#   目标表名: tar_table
#   目标表字段: tar_columns
#   目标表创建模式: tar_create_mode
#   目标数据装载模式: tar_load_mode
#   分页大小: page_size
#   数据文件目录: data_path
#   日志文件目录: log_path


source $SHELL_HOME/common/db/config.sh
source $SHELL_HOME/common/db/postgresql/pg_util.sh
source $SHELL_HOME/common/db/hive/hive_util.sh


# 执行数据源SQL
function execute_src()
{
    local sql="$1"
    local extras="$2"

    if [ -z "$sql" ]; then
        sql=`cat`
    fi

    hive_executor "$sql;" "$src_db_url $extras"
}

# 执行数据目标SQL
function execute_tar()
{
    local sql="$1"
    local extras="$2"

    if [[ -z "$sql" ]]; then
      sql=`cat`
    fi

    pg_executor "$sql;" "$tar_db_url $extras"
}

# pg导入数据
function pg_loader()
{
    local sql="$1"
    local file="$2"

    psql $tar_db_url -c "$sql" < "$file"
}

# 整型类型转换
function conv_int()
{
    sed 's/\ttinyint\t/\tsmallint\t/ig'
}

# 字符类型转换
function conv_string()
{
    sed 's/\tstring\t/\ttext\t/ig'
}

# 日期类型转换
function conv_date()
{
    sed 's/\ttimestamp\t/\ttimestamp\t/ig'
}

# 数据类型转换
function conv_data_type()
{
    conv_int | conv_string | conv_date
}

# 格式化字段
function format_columns()
{
    sed 's/^\([^ ]*\)[[:space:]]*\([^ ]*\)[[:space:]]*\(.*\)/\1\t\2\t\3/g;s/[[:space:]]*$//g'
}

# 获取表字段
function get_columns()
{
    execute_src "DESC $src_table" | format_columns | pg_keyword_conv
}

# 获取分区字段
function get_part_keys()
{
    sed '/^[[:space:]]*$/d' $log_path/$src_table.def |
    awk -F '\t' '{
        if($0 ~ /^#[[:space:]]*Partition/) part=1
        if($0 ~ /^#[[:space:]]*col_name/) col=1
        if($0 !~ /^#/ && part == 1 && col == 1) print $0
    }' | tr '\n' '|' | sed 's/.$//'
}

# 生成建表语句
function build_create_sql()
{
    # 建表语句
    echo "CREATE TABLE IF NOT EXISTS $tar_table ("
    sed '/^#/,/$!/d;/^[[:space:]]*$/d' $log_path/$src_table.def |
    grep -Ev "${part_keys:-undefined}" |
    conv_data_type | awk -F '\t' '{
        printf("  %s %s,\n",$1,$2)
    }' | sed '$s/,$//'
    echo ");"
}

# 添加字段注释
function add_columns_comment()
{
    # 字段注释
    sed '/^#/,/$!/d;/^[[:space:]]*$/d' $log_path/$src_table.def |
    grep -Ev "${part_keys:-undefined}" |
    awk -F '\t' '{
        printf("COMMENT ON COLUMN '$tar_table'.%s IS '\'%s''\'';\n",$1,$3)
    }'
}

# 创建表
function create_table()
{
    # 获取字段
    debug "get columns"
    get_columns > $log_path/$src_table.def

    # 获取分区字段
    debug "get partition keys"
    part_keys=`get_part_keys`
    debug "get partition keys [$part_keys] end"

    # 生成postgresql建表语句
    debug "build create sql begin"
    build_create_sql > $log_path/$tar_table.ctl
    debug "build create sql end"

    # 添加字段注释
    debug "add columns comment begin"
    add_columns_comment >> $log_path/$tar_table.ctl
    debug "add columns comment end"

    cat $log_path/$tar_table.ctl | execute_tar
}

# 构建目标表
function build_table()
{
    # 创建表
    case $tar_create_mode in
        $CREATE_MODE_AUTO)
            debug "Create table: $tar_table"
            create_table
            ;;
        $CREATE_MODE_DROP)
            debug "Drop table: $tar_table"
            execute_tar "DROP TABLE IF EXISTS $tar_table" &&

            debug "Create table: $tar_table"
            create_table
            ;;
        $CREATE_MODE_SKIP)
            debug "Skip create table: $tar_table"
            ;;
        *)
            warn "Unknow table create mode: $tar_create_mode"
            ;;
    esac
}

# 预装载数据
function pre_load()
{
    # 装载模式
    case $tar_load_mode in
        $LOAD_MODE_IGNORE)
            load_mode=ignore
            ;;
        $LOAD_MODE_REPLACE)
            load_mode=replace
            ;;
        $LOAD_MODE_TRUNCATE)
            debug "Truncate table: $tar_table"
            execute_tar "TRUNCATE TABLE $tar_table"
            ;;
        $LOAD_MODE_APPEND)
            warn "An error will occur when a duplicate key value is found for current load mode: $tar_load_mode"
            ;;
        *)
            warn "Unknow data load mode: $tar_load_mode"
            ;;
    esac
}

# 导出数据
function export_data()
{
    local sql="SELECT $src_columns FROM $src_table WHERE 1 = 1 $src_filter"

    execute_src "$sql" > $data_path/${src_table}_${page_no}.tmp
}

# 装载数据
function load_data()
{
    local sql="COPY $tar_table FROM STDIN"
    if [[ -n "$tar_columns" ]]; then
        sql="COPY $tar_table ( $tar_columns ) FROM STDIN"
    fi
    sql="$sql NULL 'NULL'"

    pg_loader "$sql" $data_path/${src_table}_${page_no}.tmp > $log_path/${tar_table}_${page_no}.log
}

# 同步一页
function sync_page()
{
    # 抽取数据
    debug "Export data begin"
    export_data &&

    # 装载数据
    debug "Load data begin"
    load_data
}

# 同步表
function sync_table()
{
    if [[ $page_size -gt 0 ]]; then
        warn "Current version does not support paging"
    fi

    debug "Synchronize data begin"
    sync_page
}
