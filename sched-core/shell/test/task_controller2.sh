#!/bin/bash
#
# 自动检测任务并生成数据（广告）
# 用法: nohup sh task_controller2.sh > task_controller2.log 2>&1 &


# 自身pid
PID=$$

MYSQL_HOST=localhost
MYSQL_PORT=3308
MYSQL_USER=root
MYSQL_PASSWD=mysql
MYSQL_DB=bostar
MYSQL_CHARSET=utf8

# 检测时间间隔(60秒)
CHECK_INTERVAL=60

# 数据文件目录
DATADIR=$HOME/data5
# 日志文件目录
LOGDIR=./logs


# 创建目录
mkdir -p $DATADIR $LOGDIR

# 记录日志
function log()
{
    echo "$(date +'%F %T.%N') [ $@ ]"
}

# 捕捉kill信号
trap 'log "$0 is killed, pid: $PID, script will exit soon";bye=yes' TERM

# 执行sql
function exec_sql()
{
    local sql="${1:-`cat`}"
    local params="${2:--s -N --local-infile}"

    echo "SET NAMES $MYSQL_CHARSET;$sql" | mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASSWD $MYSQL_DB $params
}

# 获取可执行任务
function get_tasks()
{
    echo "SELECT start_date, end_date FROM t_prod_adv_run WHERE run_status = 1;" | exec_sql
}

# 更新任务状态
function update_task()
{
    local updates="$1"
    local filters="$2"
    local sql="UPDATE t_prod_adv_run SET $updates WHERE start_date = '$start_date' AND end_date = '$end_date' $filters;"

    log "$sql"
    echo "$sql" | exec_sql
}

# 运行
function run()
{
    sh gen_ad3.sh $start_date $end_date > $LOGDIR/ad-${start_date}-${end_date}.log 2> ad-${start_date}-${end_date}.err
    if [[ $? -eq 0 ]]; then
        # 更新任务状态
        update_task "run_status = 3"
    else
        error_msg=`sed "s/\('\|\"\)/\\\\\1/g" ad-${start_date}-${end_date}.err | awk '{printf("%s\\\n",$0)}'`
        update_task "run_status = 4, error_msg = CONCAT(IFNULL(error_msg,''), '\nGenerate ad failed\n', '$error_msg')"
    fi
}

# 检查可执行任务
function check()
{
    get_tasks | while read start_date end_date; do
        log "Run task($prod_id, $start_date, $end_date)"
        update_task "run_status = 2"
        run &
    done
}

# 优雅退出
function graceful_exit()
{
    if [[ $bye ]]; then
        log "Wait subprocess to complete"
        pst=`pstree $PID`
        while [[ "$pst" != "" && "$pst" != "sh---pstree" ]]; do
            sleep 1
            pst=`pstree $PID`
        done

        log "$0 exit"
        break
    fi
}

# 循环检测
log "$0 start running, pid: $PID"
while :; do
    # 优雅退出
    graceful_exit

    # 删除历史日志文件
    log "Delete history logs"
    for i in `seq 5`; do
        ls -c $LOGDIR/*.$i 2> /dev/null | sed '1,30 d' | xargs -r rm -f
    done

    # 检查可执行任务
    log "Check tasks"
    check

    # 优雅退出
    graceful_exit

    # 休眠一段时间
    log "Sleep $CHECK_INTERVAL seconds"
    sleep $CHECK_INTERVAL
done
