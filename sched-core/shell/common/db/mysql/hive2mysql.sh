# mysql到hive数据同步工具类
#
# 变量依赖:
#   源表名: src_table
#   源表字段: src_columns
#   目标表名: tar_table
#   目标表字段: tar_columns
#   目标表创建模式: tar_create_mode
#   目标表数据装载模式: tar_load_mode
#   数据文件目录: data_path
#   日志文件目录: log_path


source $SHELL_HOME/common/db/db_util.sh
source $SHELL_HOME/common/db/mysql/mysql_util.sh
source $SHELL_HOME/common/db/hive/hive_util.sh


# 构建增量条件
function build_filter()
{
    # 拼接增量条件
    debug "All conditions: $src_filter"
}

# 字符类型转换
function conv_string()
{
    sed 's/\tstring/\ttext/ig'
}

# 日期类型转换
function conv_date()
{
    sed 's/\ttimestamp/\tdatetime/ig'
}

# 数据类型转换
function conv_data_type()
{
    conv_string | conv_date
}

# 格式化字段
function format_columns()
{
    sed 's/^\([^ ]*\)[[:space:]]*\([^ ]*\)[[:space:]]*\(.*\)/\1\t\2\t\3/g;s/[[:space:]]*$//g'
}

# 生成建表语句
function build_create_sql()
{
    echo "CREATE TABLE IF NOT EXISTS $tar_table ("
    execute_src "DESC $src_table;" | sed '/^[[:space:]]*$/Q' | format_columns | conv_data_type | mysql_escape | awk -F '\t' '{
        printf("    %s %s COMMENT '\''%s'\'',\n",$1,$2,$3)
    }' | sed '$s/,$//'
    echo ") ENGINE=MyISAM;"
}

# 创建表
function create_table()
{
    build_create_sql | tee $log_path/${tar_table}.ctl | execute_tar
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
            execute_tar "DROP TABLE IF EXISTS $tar_table" || return $?

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

# 获取字段分隔符
function get_field_separator()
{
    execute_src "SHOW CREATE TABLE $src_table;" | grep -i "FIELDS TERMINATED BY" | sed "s/.*'\(.*\)'.*/\1/"
}

# 获取数据
function get_data()
{
    local sql="SELECT $src_columns FROM $src_table WHERE 1 = 1 $src_filter"

    execute_src "$sql" > $data_path/${src_table}_${page_no}.tmp

    hive_data_conv < $data_path/${src_table}_${page_no}.tmp > $data_path/${src_table}_${page_no}.txt
}

# 装载数据
function load_data()
{
    local sql="LOAD DATA LOCAL INFILE '$data_path/${src_table}_${page_no}.txt' $load_mode INTO TABLE $tar_table"

    if [[ -n "$tar_columns" ]]; then
        sql="$sql ( $tar_columns )"
    fi

    execute_tar "$sql" "-vvv" > $log_path/${tar_table}_${page_no}.log
}

# 同步一页
function sync_page()
{
    # 抽取数据
    debug "Export data begin, current page: $page_no"
    get_data || return $?

    # 装载数据
    debug "Load data begin, current page: $page_no"
    load_data
}

# 同步表
function sync_table()
{
    page_size=${page_size:-0}
    page_no=${page_no:-0}

    if [[ $page_size -gt 0 ]]; then
        warn "Current version does not support paging, parameter: page_size will be ignored"
    fi

    debug "Synchronize data begin"
    sync_page
}
