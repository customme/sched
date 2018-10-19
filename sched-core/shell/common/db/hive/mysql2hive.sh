# mysql到hive数据同步工具类
#
# 变量依赖:
#   源表名: src_table
#   源表字段: src_columns
#   源表增量时间字段: src_time_columns
#   目标表名: tar_table
#   目标表字段: tar_columns
#   目标表创建模式: tar_create_mode
#   目标表数据装载模式: tar_load_mode
#   分页大小: page_size
#   是否第一次: is_first
#   数据文件目录: data_path
#   日志文件目录: log_path
#   分区值: biz_date


source $SHELL_HOME/common/db/db_util.sh
source $SHELL_HOME/common/db/mysql/mysql_util.sh
source $SHELL_HOME/common/db/hive/hive_util.sh


# 构建增量条件
function build_filter()
{
    # 拼接增量条件
    debug "Check time incremental columns: $src_time_columns"
    if [[ -n "$src_time_columns" ]]; then
        time_filter=`echo "$src_time_columns" | awk -F"," '{
            for(i=1;i<=NF;i++){
                if(is_first == 1){
                    printf("%s < '\''%s'\'' OR ",$i,the_time)
                }else{
                    printf("( %s >= '\''%s'\'' AND %s < '\''%s'\'' ) OR ",$i,prev_time,$i,the_time)
                }
            }
        }' the_time="$the_time" prev_time="$prev_time" is_first=$is_first | sed 's/ OR $//'`
        debug "Got time incremental conditions: $time_filter"
        src_filter="AND ( $time_filter ) $src_filter"
    fi
    debug "All conditions: $src_filter"
}

# 整型类型转换
function conv_int()
{
    sed 's/ [^ ]*int(.*)/ int/ig;s/ year/ int/ig'
}

# 浮点类型转换
function conv_float()
{
    sed 's/ float\| double/ decimal/ig'
}

# 字符类型转换
function conv_string()
{
    sed 's/ text\| enum(.*)\| set(.*)\| blob/ string/ig'
}

# 日期类型转换
function conv_date()
{
    sed 's/ datetime.*/ timestamp/ig;s/ date&\| date(.*)$/ date/ig;s/ time$/ string/ig'
}

# 数据类型转换
function conv_data_type()
{
    conv_int | conv_float | conv_string | conv_date
}

# 获取表注释
function get_table_comment()
{
    grep "ENGINE=.* COMMENT=" $log_path/${src_table}.def | sed "s/.* COMMENT=\(.*\)/\1/i;s/'//g"
}

# 生成建表语句
function build_create_sql()
{
    echo "CREATE TABLE IF NOT EXISTS $tar_table ("
    paste -d ' ' $log_path/$src_table.cols $log_path/$src_table.cmts | sed '$s/,$//'
    echo ") COMMENT '`get_table_comment`' PARTITIONED BY (biz_date STRING) ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TEXTFILE;"
}

# 获取字段
function get_columns()
{
    sed '1d;$d' $log_path/$src_table.def | grep -Eiv " KEY " | sed 's/\([ ]*[^ ]*[ ]*[^ ]*\).*/\1/ig;s/`//g' | conv_data_type
}

# 获取字段注释
function get_columns_comment()
{
    sed '1d;$d' $log_path/$src_table.def | grep -Eiv " KEY " | sed "s/.*COMMENT '\(.*\)',$/\1/ig;s/^[[:space:]]*\`.*//g" | hive_escape | sed "s/\(.*\)/COMMENT '\1',/g"
}

# 创建表
function create_table()
{
    echo "SHOW CREATE TABLE $src_table\G;" | execute_src | sed -n '3,$p' > $log_path/${src_table}.def

    get_columns > $log_path/$src_table.cols
    get_columns_comment > $log_path/$src_table.cmts

    build_create_sql | tee $log_path/$tar_table.ctl | execute_tar
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
function preload()
{
    # 装载模式
    case $tar_load_mode in
        $LOAD_MODE_IGNORE|$LOAD_MODE_APPEND)
            load_mode=ignore
            ;;
        $LOAD_MODE_REPLACE)
            load_mode=replace
            ;;
        $LOAD_MODE_TRUNCATE)
            debug "Truncate table: $tar_table"
            execute_tar "TRUNCATE TABLE $tar_table"
            ;;
        *)
            warn "Unknow data load mode: $tar_load_mode"
            ;;
    esac
}

# 导出数据
function get_data()
{
    # 构建查询sql语句
    local sql="SELECT $src_columns FROM $src_table WHERE 1 = 1 $src_filter $page_filter"

    # 执行sql语句
    execute_src "$sql" > $data_path/${src_table}_${page_no}.tmp || return $?

    # 特殊字符处理
    cat $data_path/${src_table}_${page_no}.tmp | hive_data_conv > $data_path/${src_table}_${page_no}.txt
}

# 装载数据
function load_data()
{
    # 生成装载sql语句
    local sql="LOAD DATA LOCAL INPATH '$data_path/${src_table}_${page_no}.txt' INTO TABLE $tar_table PARTITION (biz_date='$biz_date')"

    if [[ -n "$tar_columns" ]]; then
        sql="$sql ( $tar_columns )"
    fi

    # 执行sql语句
    execute_tar "$sql" "--verbose=true" > $log_path/${tar_table}_${page_no}.log
}

# 同步一页
function sync_page()
{
    # 抽取数据
    debug "Export data begin, current page: $page_no"
    export_data || return $?

    # 装载数据
    debug "Load data begin, current page: $page_no"
    load_data
}

# 同步表
function sync_table()
{
    page_size=${page_size:-$SYNC_PAGE_SIZE}

    if [[ $page_size -eq 0 ]]; then
        # 不分页
        warn "Synchronize all data at one time, this may take a long time, you can set task extended attribute: page_size to do it by page"
        page_no=${page_no:-0}
        sync_page
    else
        # 分页同步
        debug "Synchronize data by page"

        # 分页大小
        page_size=${page_size:-$SYNC_PAGE_SIZE}
        debug "Page size: $page_size"

        local total_count=$(execute_src "SELECT COUNT(*) FROM $src_table WHERE 1 = 1 $src_filter")
        debug "Total count: $total_count"

        local total_page=$((total_count % page_size == 0 ? total_count / page_size : total_count / page_size + 1))
        debug "Total page: $total_page"

        for((page_no=1;page_no<=$total_page;page_no++)); do
            offset=$(((page_no-1) * page_size))
            page_filter="LIMIT $offset, $page_size"

            debug "Current page: $page_no"
            sync_page || return $?
        done
    fi
}