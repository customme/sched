# mysql到mysql数据同步工具类
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


source $SHELL_HOME/common/db/db_util.sh
source $SHELL_HOME/common/db/mysql/mysql_util.sh


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

# 将源表定义转换成目标表定义
# 1、去掉“AUTO_INCREMENT” “CURRENT_TIMESTAMP” “COLLATE”
# 2、去掉索引
# 3、统一表引擎为“MyISAM”
function conv_table_def()
{
    sed "s/CREATE TABLE \`${src_table}\`/CREATE TABLE IF NOT EXISTS \`${tar_table}\`/i" |
    sed 's/\(AUTO_INCREMENT[=0-9]*\|on update CURRENT_TIMESTAMP\|COLLATE[ =][^ ]*\)//ig' |
    sed '/^[ ]* KEY .*/d' |
    sed 's/\(MRG_MyISAM\|InnoDB\|BRIGHTHOUSE\)/MyISAM/i' |
    sed "s/CHARSET=[^ ]*/CHARSET=${tar_db[6]}/i" |
    tac | sed '2s/,$//' | tac
}

# 创建表
function create_table()
{
    local excludes="FOREIGN KEY"
    debug "Exclude keywords: $excludes"

    echo "SHOW CREATE TABLE ${src_table}\G;" | execute_src > $log_path/${src_table}.src_table.def || return $?

    cat $log_path/${src_table}.src_table.def | get_table_def "$src_columns" "$excludes" |
    conv_table_def | tee $log_path/${tar_table}.tar_table.def | execute_tar
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
        $LOAD_MODE_IGNORE)
            load_mode=IGNORE
            ;;
        $LOAD_MODE_REPLACE)
            load_mode=REPLACE
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

# 获取数据
function get_data()
{
    # 构建查询sql语句
    local sql="SELECT $src_columns FROM $src_table WHERE 1 = 1 $src_filter $page_filter"

    # 执行sql语句
    execute_src "$sql" > $data_path/${src_table}_${page_no}.tmp || return $?

    # 特殊字符处理
    cat $data_path/${src_table}_${page_no}.tmp | mysql_data_conv > $data_path/${src_table}_${page_no}.txt
}

# 装载数据
function load_data()
{
    # 生成装载sql语句
    local sql="SET SQL_MODE = '';LOAD DATA LOCAL INFILE '$data_path/${src_table}_${page_no}.txt' $load_mode INTO TABLE $tar_table"

    if [[ -n "$tar_columns" ]]; then
        sql="$sql ( $tar_columns )"
    fi

    # 执行sql语句
    execute_tar "$sql" "-vvv" > $log_path/${tar_table}_${page_no}.log
}

# 同步一页
function sync_page()
{
    # 抽取数据
    info "Extract data begin, current page: $page_no"
    get_data || return $?

    # 装载数据
    info "Load data begin, current page: $page_no"
    load_data
}

# 同步表
function sync_table()
{
    if [[ -z "$page_size" || $page_size -le 0 ]]; then
        # 不分页
        warn "Synchronize all data at one time, this may take a long time, you can set task extended attribute: page_size to do it by page"
        page_no=${page_no:-0}
        sync_page
    else
        # 分页同步
        info "Synchronize data by page"

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