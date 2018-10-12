# 任务管理器工具类


source $SCHED_HOME/manager/config.sh


# 清理历史任务实例
# 状态为 "初始化","成功","失败" 的任务
function clean_task_instance()
{
    echo "CREATE TABLE IF NOT EXISTS t_task_history LIKE t_task_pool;
    REPLACE INTO t_task_history
    SELECT a.* FROM t_task_pool a INNER JOIN t_task b
    ON a.task_id = b.id
    AND a.task_state IN ($TASK_STATE_INITIAL,$TASK_STATE_SUCCESS,$TASK_STATE_FAILED)
    AND (
      ( b.task_cycle = '$TASK_CYCLE_DAY' AND a.run_time < CURDATE() - INTERVAL $TASK_KEEP_DAY DAY )
      OR ( b.task_cycle = '$TASK_CYCLE_WEEK' AND a.run_time < CURDATE() - INTERVAL $TASK_KEEP_WEEK WEEK )
      OR ( b.task_cycle = '$TASK_CYCLE_MONTH' AND a.run_time < CURDATE() - INTERVAL $TASK_KEEP_MONTH MONTH )
      OR ( b.task_cycle = '$TASK_CYCLE_HOUR' AND a.run_time < CURDATE() - INTERVAL $TASK_KEEP_HOUR HOUR )
      OR ( b.task_cycle = '$TASK_CYCLE_INTERVAL' AND a.run_time < CURDATE() - INTERVAL $TASK_KEEP_INTERVAL * b.cycle_value SECOND )
    );

    DELETE a.* FROM t_task_pool a INNER JOIN t_task b
    ON a.task_id=b.id
    AND a.task_state IN ($TASK_STATE_INITIAL,$TASK_STATE_SUCCESS,$TASK_STATE_FAILED)
    AND (
      ( b.task_cycle = '$TASK_CYCLE_DAY' AND a.run_time < CURDATE() - INTERVAL $TASK_KEEP_DAY DAY )
      OR ( b.task_cycle = '$TASK_CYCLE_WEEK' AND a.run_time < CURDATE() - INTERVAL $TASK_KEEP_WEEK WEEK )
      OR ( b.task_cycle = '$TASK_CYCLE_MONTH' AND a.run_time < CURDATE() - INTERVAL $TASK_KEEP_MONTH MONTH )
      OR ( b.task_cycle = '$TASK_CYCLE_HOUR' AND a.run_time < CURDATE() - INTERVAL $TASK_KEEP_HOUR HOUR )
      OR ( b.task_cycle = '$TASK_CYCLE_INTERVAL' AND a.run_time < CURDATE() - INTERVAL $TASK_KEEP_INTERVAL * b.cycle_value SECOND )
    );
    " | execute_meta
}

# 拆分历史任务日志
function split_log()
{
    local the_month=$(date +%Y%m)
    local prev_month=$(date +%Y%m -d "1 month ago")
    echo "CREATE TABLE IF NOT EXISTS t_task_log_$prev_month LIKE t_task_log;
    INSERT INTO t_task_log_$prev_month SELECT * FROM t_task_log WHERE log_time >= ${prev_month}01 AND log_time < ${the_month}01;
    DELETE FROM t_task_log WHERE log_time < ${the_month}01;
    " | execute_meta
}

# 获取任务
function get_tasks()
{
    echo "SELECT
      a.id _task_id,
      a.create_by _create_by,
      a.task_cycle,
      IF(a.cycle_value > '', a.cycle_value, NULL) _cycle_value,
      DATE_FORMAT(
        IF(
          b.run_time IS NULL,
          a.start_time,
          MAX(
            CASE a.task_cycle
            WHEN '$TASK_CYCLE_DAY' THEN b.run_time + INTERVAL 1 DAY + INTERVAL TIME(a.start_time) HOUR_SECOND
            WHEN '$TASK_CYCLE_WEEK' THEN b.run_time + INTERVAL 1 WEEK + INTERVAL TIME(a.start_time) HOUR_SECOND
            WHEN '$TASK_CYCLE_MONTH' THEN b.run_time + INTERVAL 1 MONTH + INTERVAL TIME(a.start_time) HOUR_SECOND
            WHEN '$TASK_CYCLE_HOUR' THEN b.run_time + INTERVAL 1 HOUR + INTERVAL DATE_FORMAT(a.start_time, '%i%s') MINUTE_SECOND
            END
          )
        ), '%Y%m%d%H%i%s'
      ) _start_time,
      DATE_FORMAT(
        IF(
          a.end_time < NOW(),
          a.end_time,
          NOW()
        ), '%Y%m%d%H%i%s'
      ) _end_time,
      a.date_serial,
      a.priority,
      a.max_try_times
    FROM t_task a
    LEFT JOIN t_task_pool b
    ON a.id = b.task_id
    WHERE a.task_status = $TASK_STATUS_NORMAL
    GROUP BY _task_id
    HAVING _start_time <= _end_time;
    " | execute_meta
}

# 获取初始状态任务
function get_initial_tasks()
{
    echo "SELECT 
    a.task_id,
    DATE_FORMAT(a.run_time, '%Y%m%d%H%i%s') run_time,
    b.task_cycle,
    DATE_FORMAT( b.first_time, '%Y%m%d%H%i%s' ) first_time,
    b.date_serial 
    FROM t_task_pool a 
    INNER JOIN t_task b 
    ON a.task_id = b.id 
    AND a.task_state = $TASK_STATE_INITIAL;
    " | execute_meta
}

# 生成任务实例
function make_task_instance()
{
    local task_id="$1"
    local task_cycle="$2"
    local cycle_value="$3"
    local start_time="$4"
    local end_time="$5"

    # 获取任务周期边界
    local cycle_range=($(get_cycle_range $start_time $end_time $task_cycle $cycle_value))
    start_time=${cycle_range[0]}
    end_time=${cycle_range[1]}

    local start_date=${start_time:0:8}
    local end_date=${end_time:0:8}

    case $task_cycle in
        $TASK_CYCLE_DAY)
            range_date $start_date $end_date | while read the_day; do
                echo $task_id $the_day
            done
            ;;
        $TASK_CYCLE_WEEK)
            range_week $start_date $end_date extend | while read the_week week_begin week_end; do
                week_num=$((cycle_value - 1))
                the_day=`date +%Y%m%d -d "$week_begin $week_num day"`
                echo $task_id $the_day
            done
            ;;
        $TASK_CYCLE_MONTH)
            range_date ${start_date:0:6} ${end_date:0:6} | while read the_month; do
                the_day=`date +%Y%m%d -d "${the_month}${cycle_value}"`
                echo $task_id $the_day
            done
            ;;
        $TASK_CYCLE_HOUR)
            range_date ${start_time:0:10} ${end_time:0:10} | while read the_time; do
                echo $task_id $the_time
            done
            ;;
        *)
            error "Unsupported task cycle: $task_cycle"
            exit 1
            ;;
    esac
}

# 生成任务周期
function range_cycle()
{
    local start_time="$1"
    local end_time="$2"
    local task_cycle="$3"
    local cycle_value="$4"

    case $task_cycle in
        $TASK_CYCLE_DAY)
            range_date $start_time $end_time
            ;;
        $TASK_CYCLE_WEEK)
            range_week $start_time $end_time extend | while read week_num week_start week_end; do
                week_num=$((cycle_value - 1))
                the_day=`date +%Y%m%d -d "$week_start $week_num day"`
                if [[ $the_day -ge $start_time && $the_day -le $end_time ]]; then
                    echo $the_day
                fi
            done
            ;;
        $TASK_CYCLE_MONTH)
            local month_start=`date +%Y%m -d "$start_time"`
            local month_end=`date +%Y%m -d "$end_time"`
            range_date $month_start $month_end | while read the_month; do
                the_day=${the_month}$cycle_value
                if [[ $the_day -ge $start_time && $the_day -le $end_time ]]; then
                    echo $the_day
                fi
            done
            ;;
        $TASK_CYCLE_HOUR)
            range_date $start_time $end_time
            ;;
    esac
}

# 获取任务状态
function get_task_state()
{
    local task_id="$1"
    local run_time="$2"

    echo "SELECT task_state 
    FROM t_task_pool 
    WHERE task_id = $task_id 
    AND run_time = STR_TO_DATE('$run_time','%Y%m%d%H%i%s');
    " | execute_meta
}

# 检查全周期
function check_full_cycle()
{
    local task_id="$1"
    local task_cycle="$2"
    local cycle_value="$3"
    local start_time="$4"
    local end_time="$5"

    range_cycle $start_time $end_time $task_cycle $cycle_value | tac | while read the_time; do
        task_state=$(get_task_state $task_id $the_time)
        if [[ $task_state -ne $TASK_STATE_SUCCESS ]]; then
            echo $task_state
            break
        fi
    done
}

# 获取依赖任务
function get_task_link()
{
    local task_id="$1"

    echo "SELECT a.task_pid,
    a.link_type,
    b.task_cycle,
    b.cycle_value,
    IF(
      b.task_cycle = '$TASK_CYCLE_HOUR',
      DATE_FORMAT(b.start_time,'%Y%m%d%H'),
      DATE_FORMAT(b.start_time,'%Y%m%d')
    ) start_time,
    IF(
      b.task_cycle = '$TASK_CYCLE_HOUR',
      DATE_FORMAT(IFNULL(b.end_time,NOW()),'%Y%m%d%H'),
      DATE_FORMAT(IFNULL(b.end_time,NOW()),'%Y%m%d')
    ) end_time 
    FROM t_task_link a 
    INNER JOIN t_task b 
    ON a.task_pid = b.id 
    AND a.task_id = $task_id;
    " | execute_meta
}

# 检查任务依赖
: '
一、自身依赖
1、不是第一个运行周期
2、上一个运行周期任务成功

二、父子依赖
B任务依赖A任务
1、最后一个周期依赖
-------------------------------------------------
     B周期|   天    |   周   |   月   |   小时   |
A周期     |         |        |        |          |
-------------------------------------------------
   天     | 当天    | 当天   | 当天   | 不支持   |
-------------------------------------------------
   周     | 不支持  | 本周   | 不支持 | 不支持   |
-------------------------------------------------
   月     | 不支持  | 不支持 | 本月   | 不支持   |
-------------------------------------------------
   小时   | 当天0点 | 不支持 | 不支持 | 当前小时 |
-------------------------------------------------
2、全周期依赖
------------------------------------------------------------------------------------
     B周期|          天          |       周       |        月        |     小时     |
A周期     |                      |                |                  |              |
------------------------------------------------------------------------------------
   天     | 不支持               | 上周二 -> 当天 | 上月二号 -> 当天 | 不支持       |
------------------------------------------------------------------------------------
   周     | 不支持               | 不支持         | 不支持           | 不支持       |
------------------------------------------------------------------------------------
   月     | 不支持               | 不支持         | 不支持           | 不支持       |
------------------------------------------------------------------------------------
   小时   | 前一天1点 -> 当天0点 | 不支持         | 不支持           | 不支持       |
------------------------------------------------------------------------------------
'
function check_dependence()
{
    local task_id="$1"
    local run_time="$2"
    local task_cycle="$3"
    local first_time="$4"
    local date_serial="$5"

    # 任务周期为非“天/周/月/小时”，不支持依赖
    case $task_cycle in
        $TASK_CYCLE_DAY|$TASK_CYCLE_WEEK|$TASK_CYCLE_MONTH|$TASK_CYCLE_HOUR);;
        *) return;;
    esac

    # 自身依赖
    if [[ $date_serial -eq $DATE_SERIAL ]]; then
        if [[ $run_time -gt $first_time ]]; then
            # 检查上一个周期的状态
            local last_cycle=$(get_next_cycle $run_time $task_cycle ago)
            local task_state=$(get_task_state $task_id $last_cycle)
            if [[ $task_state -ne $TASK_STATE_SUCCESS ]]; then
                echo $task_state
                return
            fi
        fi
    fi

    # 父子依赖
    get_task_link $task_id | while read p_task_id link_type p_task_cycle p_cycle_value p_start_time p_end_time; do
        case $link_type in
            # 最后一个周期依赖
            $LINK_TYPE_LAST)
                current_cycle=$(get_current_cycle $run_time $p_task_cycle $p_cycle_value)
                case $task_cycle in
                    # 任务周期为 天
                    $TASK_CYCLE_DAY)
                        case $p_task_cycle in
                            # 父任务周期为 天
                            $TASK_CYCLE_DAY)
                                task_state=$(get_task_state $p_task_id $current_cycle)
                                ;;
                            # 父任务周期为 小时
                            $TASK_CYCLE_HOUR)
                                # 父任务开始时间晚于子任务当前周期
                                if [ $p_start_time -gt $current_cycle ]; then
                                    current_cycle=$p_start_time
                                fi
                                task_state=$(get_task_state $p_task_id $current_cycle)
                                ;;
                            # 父任务周期为 周/月
                            *)
                                # 不支持
                                ;;
                        esac
                        ;;
                    # 任务周期为 周
                    $TASK_CYCLE_WEEK)
                        case $p_task_cycle in
                            # 父任务周期为 天
                            $TASK_CYCLE_DAY)
                                # 父任务开始时间晚于子任务当前周期
                                if [ $p_start_time -gt $current_cycle ]; then
                                    current_cycle=$p_start_time
                                fi
                                task_state=$(get_task_state $p_task_id $current_cycle)
                                ;;
                            # 父任务周期为 周
                            $TASK_CYCLE_WEEK)
                                task_state=$(get_task_state $p_task_id $current_cycle)
                                ;;
                            # 父任务周期为 月/小时
                            *)
                                # 不支持
                                ;;
                        esac
                        ;;
                    # 任务周期为 月
                    $TASK_CYCLE_MONTH)
                        case $p_task_cycle in
                            # 父任务周期为 天
                            $TASK_CYCLE_DAY)
                                # 父任务开始时间晚于子任务当前周期
                                if [ $p_start_time -gt $current_cycle ]; then
                                    current_cycle=$p_start_time
                                fi
                                task_state=$(get_task_state $p_task_id $current_cycle)
                                ;;
                            # 父任务周期为 月
                            $TASK_CYCLE_MONTH)
                                task_state=$(get_task_state $p_task_id $current_cycle)
                                ;;
                            # 父任务周期为 周/小时
                            *)
                                # 不支持
                                ;;
                        esac
                        ;;
                    # 任务周期为 小时
                    $TASK_CYCLE_HOUR)
                        case $p_task_cycle in
                            # 父任务周期为 小时
                            $TASK_CYCLE_HOUR)
                                task_state=$(get_task_state $p_task_id $current_cycle)
                                ;;
                            # 父任务周期为 天/周/月
                            *)
                                # 不支持
                                ;;
                        esac
                        ;;
                esac
                ;;
            # 全周期依赖
            $LINK_TYPE_FULL)
                case $task_cycle in
                    # 任务周期为 天
                    $TASK_CYCLE_DAY)
                        case $p_task_cycle in
                            # 父任务周期为 小时
                            $TASK_CYCLE_HOUR)
                                # 前一天1点
                                pre_day_1=$(date +%Y%m%d -d "${run_time:0:8} 1 day ago")"01"
                                # 父任务开始时间晚于子任务当前周期
                                if [[ $p_start_time -gt $pre_day_1 ]]; then
                                    pre_day_1=$p_start_time
                                fi
                                task_state=$(check_full_cycle $p_task_id $p_task_cycle $p_cycle_value $pre_day_1 ${run_time:0:10})
                                ;;
                            # 父任务周期为 天/周/月
                            *)
                                # 不支持
                                ;;
                        esac
                        ;;
                    # 任务周期为 周
                    $TASK_CYCLE_WEEK)
                        case $p_task_cycle in
                            # 父任务周期为 天
                            $TASK_CYCLE_DAY)
                                # 本周二
                                local cur_tuesday=$(get_current_cycle $run_time $TASK_CYCLE_WEEK 2)
                                # 上周二
                                local last_tuesday=$(date +%Y%m%d -d "$cur_tuesday 1 week ago")
                                # 父任务开始时间晚于子任务当前周期
                                if [[ $p_start_time -gt $last_tuesday ]]; then
                                    last_tuesday=$p_start_time
                                fi
                                task_state=$(check_full_cycle $p_task_id $p_task_cycle $p_cycle_value $last_tuesday ${run_time:0:8})
                                ;;
                            # 父任务周期为 周/月/小时
                            *)
                                # 不支持
                                ;;
                        esac
                        ;;
                    # 任务周期为 月
                    $TASK_CYCLE_MONTH)
                        case $p_task_cycle in
                            # 父任务周期为 天
                            $TASK_CYCLE_DAY)
                                # 本月2号
                                local cur_2nd=$(get_current_cycle $run_time $TASK_CYCLE_MONTH 02)
                                # 上个月2号
                                local last_2nd=$(date +%Y%m%d -d "$cur_2nd 1 month ago")
                                # 父任务开始时间晚于子任务当前周期
                                if [ $p_start_time -gt $last_2nd ]; then
                                    last_2nd=$p_start_time
                                fi
                                task_state=$(check_full_cycle $p_task_id $p_task_cycle $p_cycle_value $last_2nd ${run_time:0:8})
                                ;;
                            # 父任务周期为 周/月/小时
                            *)
                                # 不支持
                                ;;
                        esac
                        ;;
                    # 任务周期为 小时
                    $TASK_CYCLE_HOUR)
                        case $p_task_cycle in
                            # 父任务周期为 天/周/月/小时
                            *)
                                # 不支持
                                ;;
                        esac
                        ;;
                esac
                ;;
            # 任意一个周期依赖
            $LINK_TYPE_ANY)
                # 不支持
                ;;
        esac
        # 判断任务状态，非成功则退出
        if [[ -n "$task_state" && $task_state -ne $TASK_STATE_SUCCESS ]]; then
            echo ${task_state:-$TASK_STATE_INITIAL}
            break
        fi
    done
}

# 实例化任务
function insert_task()
{
    if [ $# -ne 6 ]; then
        error "Invalid arguments : insert_task $@"
        exit 1
    fi

    local task_id="$1"
    local run_time="$2"
    local task_state="$3"
    local priority="$4"
    local max_try_times="$5"
    local create_by="$6"

    echo "INSERT IGNORE INTO t_task_pool (task_id, run_time, task_state, priority, max_try_times, create_by, create_date) 
    VALUES ($task_id, STR_TO_DATE('$run_time', '%Y%m%d%H%i%s'), $task_state, $priority, $max_try_times, '$create_by', NOW());
    " | execute_meta
}
