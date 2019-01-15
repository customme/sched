# 任务工具


source $SCHED_HOME/common/config.sh

META_DB_URL=$(make_mysql_url $META_DB_HOST $META_DB_USER $META_DB_PASSWD $META_DB_NAME $META_DB_PORT)


# 执行sql语句
function execute_meta()
{
    local sql="$1"
    if [[ -z "$sql" ]]; then
      sql=`cat`
    fi

    SQL_LOG=$META_SQL_LOG
    if [[ -z "$sql_log_file" ]]; then
        local sql_log_file=$SCHED_LOG_DIR/`basename ${0%.*}`.sql.$(date +'%Y-%m-%d')
    fi

    case $META_DB_TYPE in
        $DB_TYPE_MYSQL)
            mysql_executor "SET NAMES $META_DB_CHARSET;$sql" "$META_DB_URL"
            ;;
        $DB_TYPE_ORACLE)
            error "Unsupported database type: $META_DB_TYPE"
            exit 1
            ;;
        $DB_TYPE_POSTGRESQL)
            error "Unsupported database type: $META_DB_TYPE"
            exit 1
            ;;
        *)
            error "Unsupported database type: $META_DB_TYPE"
            exit 1
            ;;
    esac
}

# 更新任务实例
# 返回影响行数
function update_task_instance()
{
    local task_id="$1"
    local run_time="$2"
    local updates="$3"

    echo "UPDATE t_task_pool SET $updates, update_date = NOW() 
    WHERE task_id = $task_id 
    AND run_time = STR_TO_DATE('$run_time','%Y%m%d%H%i%s');
    SELECT ROW_COUNT();
    " | execute_meta
}

# 更新任务扩展属性
function update_task_ext()
{
    local task_id="$1"
    local prop_name="$2"
    local prop_value="$3"

    echo "UPDATE t_task_ext SET prop_value = '$prop_value' WHERE task_id = $task_id AND prop_name = '$prop_name';" | execute_meta
}

# 任务是否存在且正常
function exists_task()
{
    local task_id="$1"

    echo "SELECT COUNT(1) FROM t_task WHERE id = $task_id AND task_status = $TASK_STATUS_NORMAL;" | execute_meta
}

# 获取任务扩展属性
function get_task_ext()
{
    local task_id="$1"
    local excludes="$2"

    if [[ -n "$excludes" ]]; then
        local filter="AND prop_name NOT IN ($excludes)"
    fi

    echo "SELECT CONCAT(prop_name,'=\"',IFNULL(prop_value,''),'\"') 
    FROM t_task_ext 
    WHERE task_id = '${task_id}' 
    $filter;
    " | execute_meta
}

# 获取任务属性值
function get_prop_value()
{
    local task_id="$1"
    local prop_name="$2"

    echo "SELECT prop_value FROM t_task_ext WHERE task_id = $task_id AND prop_name = '$prop_name';" | execute_meta
}

# 获取数据库信息
function get_db()
{
    local db_id="$1"

    if [[ -z "$db_id" ]]; then
        error "Invalid arguments : $@, usage: get_db <database id>"
        return 1
    fi

    echo "SELECT b.code db_type,
    a.hostname,
    a.port,
    a.username,
    IF(a.password > '', a.password, NULL),
    a.db_name,
    IF(a.charset > '', a.charset, NULL),
    a.conn_type 
    FROM t_db_conn a 
    INNER JOIN t_db_type b 
    ON a.type_id = b.id 
    AND a.id = $db_id;
    " | execute_meta
}

# 记录任务日志到数据库，同时将日志写到控制台
function log_task()
{
    local level=${1:-$LOG_LEVEL_INFO}
    shift
    local content="$@"
    if [[ $# -eq 0 ]]; then
        content=`cat`
    fi

    # 写到控制台
    case $level in
        $LOG_LEVEL_DEBUG)
              debug "$content"
              ;;
        $LOG_LEVEL_INFO)
              info "$content"
              ;;
        $LOG_LEVEL_WARN)
              warn "$content"
              ;;
        $LOG_LEVEL_ERROR)
              error "$content"
              ;;
        *)
              log "$content"
              ;;
    esac

    content=`echo "$content" | mysql_escape`

    # 写到数据库
    echo "INSERT INTO t_task_log (task_id, run_time, seq_no, level, content, log_time) 
    VALUES ($task_id, STR_TO_DATE('$run_time','%Y%m%d%H%i%s'), $seq_no, $level, '$content', NOW());
    " | execute_meta
}

# 获取相对于某个日期所在的周期
function get_current_cycle()
{
    local the_time="$1"
    local task_cycle="$2"
    local cycle_value="$3"

    local the_date=${the_time:0:8}
    local current_cycle

    case $task_cycle in
        $TASK_CYCLE_DAY)
            current_cycle=$the_date
            ;;
        $TASK_CYCLE_WEEK)
            local week_num=`date +%w -d "$the_date"`
            week_num=$((week_num > 0 ? week_num : 7))
            week_num=$((cycle_value - week_num))
            current_cycle=`date +%Y%m%d -d "$the_date $week_num day"`
            ;;
        $TASK_CYCLE_MONTH)
            local the_month=`date +%Y%m -d "$the_date"`
            current_cycle=${the_month}$cycle_value
            ;;
        $TASK_CYCLE_HOUR)
            current_cycle=${the_time:0:10}
            ;;
        *)
            error "Unsupported task cycle: $task_cycle"
            exit 1
        ;;
    esac

    echo $current_cycle
}

# 获取 上/下 一个周期
function get_next_cycle()
{
    local the_time="$1"
    local task_cycle="$2"
    local flag="$3"

    local the_cycle

    case $task_cycle in
        $TASK_CYCLE_DAY|$TASK_CYCLE_WEEK|$TASK_CYCLE_MONTH)
            the_cycle=`date +%Y%m%d -d "${the_time:0:8} 1 $task_cycle $flag"`
            ;;
        $TASK_CYCLE_HOUR)
            the_cycle=`date +%Y%m%d%H -d "${the_time:0:8} ${the_time:8:2} 1 hour $flag"`
            ;;
        *)
            error "Unsupported task cycle: $task_cycle"
            exit 1
            ;;
    esac

    echo $the_cycle
}

# 获取周期边界
function get_cycle_range()
{
    local start_time="$1"
    local end_time="$2"
    local task_cycle="$3"
    local cycle_value="$4"

    local first_cycle=$(get_current_cycle $start_time $task_cycle $cycle_value)
    local last_cycle=$(get_current_cycle $end_time $task_cycle $cycle_value)

    case $task_cycle in
        $TASK_CYCLE_DAY|$TASK_CYCLE_WEEK|$TASK_CYCLE_MONTH)
            first_cycle=${first_cycle}${start_time:8:6}
            last_cycle=${last_cycle}${start_time:8:6}
            ;;
        $TASK_CYCLE_HOUR)
            first_cycle=${first_cycle}${start_time:10:4}
            last_cycle=${last_cycle}${start_time:10:4}
            ;;
        *)
            error "Unsupported task cycle: $task_cycle"
            exit 1
            ;;
    esac

    if [[ $first_cycle -lt $start_time ]]; then
        first_cycle=$(get_next_cycle $first_cycle $task_cycle)
    fi

    if [[ $last_cycle -gt $end_time ]]; then
        last_cycle=$(get_next_cycle $last_cycle $task_cycle ago)
    fi

    case $task_cycle in
        $TASK_CYCLE_DAY|$TASK_CYCLE_WEEK|$TASK_CYCLE_MONTH)
            first_cycle=${first_cycle:0:8}
            last_cycle=${last_cycle:0:8}
            ;;
        $TASK_CYCLE_HOUR)
            first_cycle=${first_cycle:0:10}
            last_cycle=${last_cycle:0:10}
            ;;
    esac

    echo $first_cycle $last_cycle
}

# 获取 第一个/最后一个 周期
function get_first_cycle()
{
    local start_time="$1"
    local task_cycle="$2"
    local cycle_value="$3"

    local first_cycle=$(get_current_cycle $start_time $task_cycle $cycle_value)

    case $task_cycle in
        $TASK_CYCLE_DAY|$TASK_CYCLE_WEEK|$TASK_CYCLE_MONTH)
            first_cycle=${first_cycle}${start_time:8:6}
            ;;
        $TASK_CYCLE_HOUR)
            first_cycle=${first_cycle}${start_time:10:4}
            ;;
        *)
            error "Unsupported task cycle: $task_cycle"
            return 1
            ;;
    esac

    if [[ $first_cycle -lt $start_time ]]; then
        first_cycle=$(get_next_cycle $first_cycle $task_cycle)
    fi

    case $task_cycle in
        $TASK_CYCLE_DAY|$TASK_CYCLE_WEEK|$TASK_CYCLE_MONTH)
            first_cycle=${first_cycle:0:8}"000000"
            ;;
        $TASK_CYCLE_HOUR)
            first_cycle=${first_cycle:0:10}"0000"
            ;;
    esac

    echo $first_cycle
}

# 解析表名（简单/分表/动态）
# 1、t_city
# 2、t_user_{0 100}
# 3、t_pv_${the_date}
function table_parser()
{
    local table_name="$1"
    local table_type="$2"

    case $table_type in
        $TABLE_TYPE_SIMPLE)
            echo $table_name
            ;;
        $TABLE_TYPE_SHARDING)
            local temp=${table_name#*{}
            range_num ${temp%\}*} | while read num; do
                echo ${table_name%{*}${num}
            done
            ;;
        $TABLE_TYPE_DYNAMIC)
            echo $table_name
            ;;
        *)
            echo $table_name
            ;;
    esac
}

# 获取任务实例
function get_task_instance()
{
    local task_id="$1"
    local run_time="$2"

    echo "SELECT
      a.task_cycle,
      a.first_time = b.run_time is_first,
      b.redo_flag
    FROM t_task a
    INNER JOIN t_task_pool b
    ON a.id = b.task_id
    AND a.id = $task_id
    AND b.run_time = STR_TO_DATE('$run_time', '%Y%m%d%H%i%s');
    " | execute_meta
}

# 获取业务时间
function get_biz_date()
{
    local the_time="$1"
    local task_cycle="$2"

    case $task_cycle in
        $TASK_CYCLE_DAY|$TASK_CYCLE_WEEK|$TASK_CYCLE_MONTH)
            echo ${the_time:0:8}
            ;;
        $TASK_CYCLE_HOUR)
            echo ${the_time:0:10}
            ;;
        *)
            echo $the_time
            ;;
    esac
}

# 活跃任务运行时参数
function get_run_params()
{
    local task_id="$1"
    local run_time="$2"

    echo "SELECT IFNULL(run_params, '') FROM t_task_pool WHERE task_id = $task_id AND run_time = STR_TO_DATE('$run_time', '%Y%m%d%H%i%s');" | execute_meta
}