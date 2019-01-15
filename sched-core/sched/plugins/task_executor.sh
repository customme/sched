# 任务执行器
#
# 功能
# 1 初始化环境
# 2 获取任务配置信息
# 3 执行任务


source $SHELL_HOME/common/include.sh
source $SHELL_HOME/common/date_util.sh
source $SHELL_HOME/common/db/mysql/mysql_util.sh
source $SCHED_HOME/common/task_util.sh


# 初始化文件目录
function init_dir()
{
    # 任务日志文件目录
    log_path=$TASK_LOG_DIR/$(date +%F)/${task_id}-${run_time}
    if [[ ! -d $log_path ]]; then
        log_path=$TASK_LOG_DIR/$(date +%F -d "1 day ago")/${task_id}-${run_time}
    fi

    # 创建任务数据文件目录
    data_path=`echo $log_path | sed "s@${TASK_LOG_DIR}@${TASK_DATA_DIR}@"`
    debug "Create task data file directory: $data_path"
    mkdir -p $data_path

    # sql日志
    sql_log_file=$log_path/task_executor.sql
}

# 获取任务配置信息
function get_task_config()
{
    # 获取任务实例
    debug "Get task instance by: (task_id, run_time) ($task_id, $run_time)"
    task_instance=($(get_task_instance $task_id $run_time))
    debug "Got task instance: (task_cycle, is_first, redo_flag) (${task_instance[@]})"

    # 任务周期
    task_cycle=${task_instance[0]}

    # 任务是否第一次运行
    is_first=${task_instance[1]}

    # 任务重做标记
    redo_flag=${task_instance[2]}

    # 获取任务上次运行周期
    case $task_cycle in
        $TASK_CYCLE_DAY|$TASK_CYCLE_WEEK|$TASK_CYCLE_MONTH|$TASK_CYCLE_HOUR)
        the_time=$(format_time $run_time)
        local last_cycle=$(get_next_cycle $run_time $task_cycle ago)
        prev_time=$(format_time $last_cycle);;
    esac

    # 获取任务扩展属性
    debug "Get task extended attributes by task id: $task_id, exclude: src_sql, src_mdx, src_urls"
    get_task_ext $task_id "'src_sql', 'src_mdx', 'src_urls'" > $log_path/task.ext

    # 设置任务扩展属性
    debug "Set task extended attributes by source file: $log_path/task.ext"
    source $log_path/task.ext

    # 获取任务运行时参数
    debug "Get task run params by task id and run time ($task_id, $run_time)"
    get_run_params $task_id $run_time > $log_path/run_params

    # windows换行符替换成unix
    sed -i 's/\r\\n/\n/g' $log_path/run_params

    # 加载文件
    if [[ -n "$source_file" ]]; then
        debug "Source file: $source_file"
        source $source_file
    fi
}

function main()
{
    # 参数判断
    if [[ $# -lt 2 ]]; then
        error "Invalid arguments: $@, usage: $0 <task id> <run time> [task serial number]"
        exit 1
    fi

    task_id="$1"
    run_time="$2"
    seq_no="${3:-$(date +%s)}"

    # 出错立即退出
    set -e
    set -o pipefail

    info "Current working directory: $BASE_DIR, invoke script: $0 $@"

    # 初始化时间变量
    init_date ${run_time:0:8}

    # 初始化目录
    init_dir

    # 获取任务配置信息
    log_task $LOG_LEVEL_INFO "Get task configuration information"
    get_task_config

    # 执行任务
    log_task $LOG_LEVEL_INFO "Execute task"
    execute
}
main "$@"