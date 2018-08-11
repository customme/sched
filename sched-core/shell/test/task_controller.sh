#!/bin/bash
#
# 自动检测任务并生成数据
# 用法: nohup sh task_controller.sh > task_controller.log 2>&1 &


# 自身pid
PID=$$

MYSQL_HOST=localhost
MYSQL_PORT=3308
MYSQL_USER=root
MYSQL_PASSWD=mysql
MYSQL_DB=third
MYSQL_CHARSET=utf8

# 检测时间间隔(60秒)
CHECK_INTERVAL=60

# 数据文件目录
DATADIR=/work/data/logs
# 日志文件目录
LOGDIR=./logs


# 创建目录
mkdir -p $DATADIR $LOGDIR

# 记录日志
function log()
{
    echo "$(date +'%F %T.%N') $PID [ $@ ]"
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
    echo "SELECT
      a.prod_id,
      prod_name,
      start_date,
      end_date,
      keep0,
      rand0,
      run_status,
      IFNULL(pre_run, 0),
      IF(new_time > 0, 0, 1),
      IF(active_time > 0, 0, 1),
      IF(visit_time > 0, 0, 1),
      IF(report_time > 0, 0, 1)
    FROM t_prod_run a
    INNER JOIN (
      SELECT prod_id, MIN(start_date) min_date FROM t_prod_run WHERE run_status <> 3 GROUP BY prod_id 
    ) b
    ON a.prod_id = b.prod_id
    AND start_date = min_date
    AND run_status <> 3;
    " | exec_sql
}

# 获取新增量
function get_new_cnt()
{
    echo "SELECT IFNULL(SUM(adduser), 0) FROM l_all_add WHERE stattime >= '$start_date' AND stattime <= '$end_date' AND proname = '$prod_name';" | exec_sql
}

# 更新任务状态
function update_task()
{
    local updates="$1"
    local filters="$2"
    local sql="UPDATE t_prod_run SET $updates WHERE prod_id = '$prod_id' AND start_date = '$start_date' AND end_date = '$end_date' $filters;"

    log "$sql"
    echo "$sql" | exec_sql
}

# 生成访问
function gen_visit()
{
    # 生成访问
    log "Generate visit"
    sh gen_data3-1.sh -b $prod_id,$start_date,$end_date > $LOGDIR/${prod_id}.${start_date}.log.4 2> $LOGDIR/${prod_id}.${start_date}.err.4
    if [[ $? -eq 0 ]]; then
        # 更新访问生成时间
        update_task "visit_time = NOW()"

        # 更新任务状态
        update_task "run_status = 3" "AND visit_time > 0 AND report_time > 0"
    else
        error_msg=`sed "s/\('\|\"\)/\\\\\1/g" $LOGDIR/${prod_id}.${start_date}.err.4 | awk '{printf("%s\\\n",$0)}'`
        update_task "run_status = 4, error_msg = CONCAT(IFNULL(error_msg,''), '\nGenerate visit failed\n', '$error_msg')"
    fi
}

# 运行
function run()
{
    # 新增
    new_cnt=`get_new_cnt`
    if [[ $new_status -eq 1 && $new_cnt -gt 0 ]]; then
        # 检查android id是否够用，如果不够，就先生成android id

        # 随机休眠，避免同时创建锁
        echo $RANDOM | head -c 1 | xargs sleep

        # 检查生成android id的锁是否存在
        while test -f $DATADIR/aid.lock; do
            log "Wait for lock ($prod_id, $start_date, $end_date)"
            echo $RANDOM | head -c 1 | xargs sleep
        done
        # 创建锁
        log "Create lock ($prod_id, $start_date, $end_date)" | tee $DATADIR/aid.lock

        # 获取android id个数
        if [[ -f $DATADIR/android_id ]]; then
            aid_cnt=`wc -l $DATADIR/android_id | awk '{print $1}'`
        else
            aid_cnt=0
        fi

        # 当前分配的最大id
        if [[ -f $DATADIR/max_id ]]; then
            max_id=`cat $DATADIR/max_id`
        else
            max_id=0
        fi

        # 判断是否够用
        diff=$((max_id + new_cnt - aid_cnt))
        if [[ $pre_run -eq 1 && $diff -gt 0 ]]; then
            # 生成android id
            log "Generate android id"
            sh gen_data3-1.sh -a $diff > $LOGDIR/${prod_id}.${start_date}.log.1 2> $LOGDIR/${prod_id}.${start_date}.err.1
            if [[ $? -gt 0 ]]; then
                error_msg=`sed "s/\('\|\"\)/\\\\\1/g" $LOGDIR/${prod_id}.${start_date}.err.1 | awk '{printf("%s\\\n",$0)}'`
                update_task "run_status = 4, error_msg = CONCAT(IFNULL(error_msg,''), '\nGenerate android id failed\n', '$error_msg')"

                # 出错退出
                exit 1
            fi
        fi

        # 生成新增
        log "Generate new"
        sh gen_data3.sh -a $prod_id,$start_date,$end_date > $LOGDIR/${prod_id}.${start_date}.log.2 2> $LOGDIR/${prod_id}.${start_date}.err.2
        if [[ $? -eq 0 ]]; then
            # 更新新增生成时间
            update_task "new_time = NOW()"
        else
            error_msg=`sed "s/\('\|\"\)/\\\\\1/g" $LOGDIR/${prod_id}.${start_date}.err.2 | awk '{printf("%s\\\n",$0)}'`
            update_task "run_status = 4, error_msg = CONCAT(IFNULL(error_msg,''), '\nGenerate new failed\n', '$error_msg')"

            # 出错退出
            exit 1
        fi

        # 释放锁
        log "Release lock ($prod_id, $start_date, $end_date)"
        rm -f $DATADIR/aid.lock
    fi

    # 活跃
    if [[ $active_status -eq 1 ]]; then
        # 生成活跃
        log "Generate active"
        sh gen_data3.sh -b $prod_id,$start_date,$end_date,$keep_pct0,$rand0,$pre_run > $LOGDIR/${prod_id}.${start_date}.log.3 2> $LOGDIR/${prod_id}.${start_date}.err.3
        if [[ $? -eq 0 ]]; then
            # 更新活跃生成时间
            update_task "active_time = NOW()"
        else
            error_msg=`sed "s/\('\|\"\)/\\\\\1/g" $LOGDIR/${prod_id}.${start_date}.err.3 | awk '{printf("%s\\\n",$0)}'`
            update_task "run_status = 4, error_msg = CONCAT(IFNULL(error_msg,''), '\nGenerate active failed\n', '$error_msg')"

            # 出错退出
            exit 1
        fi
    fi

    # 访问
    if [[ $pre_run -eq 1 && $visit_status -eq 1 ]]; then
        if [[ ! `ps aux | grep "gen_data3-1\.sh -b $prod_id,$start_date,$end_date"` ]]; then
            gen_visit &
        else
            log "Another progress is running: gen_data3-1.sh -b $prod_id,$start_date,$end_date"
        fi
    fi

    # 报表
    if [[ $report_status -eq 1 ]]; then
        if [[ ! `ps aux | grep "sh load_active3\.sh $prod_id $start_date $end_date"` ]]; then
            # 统计报表
            log "Generate report"
            sh load_active3.sh $prod_id $start_date $end_date $pre_run > $LOGDIR/${prod_id}.${start_date}.log.5 2> $LOGDIR/${prod_id}.${start_date}.err.5
            if [[ $? -eq 0 ]]; then
                # 更新报表生成时间
                update_task "report_time = NOW()"
                # 更新任务状态
                update_task "run_status = 3" "AND (visit_time > 0 OR pre_run = 0) AND report_time > 0"
            else
                error_msg=`sed "s/\('\|\"\)/\\\\\1/g" $LOGDIR/${prod_id}.${start_date}.err.5 | awk '{printf("%s\\\n",$0)}'`
                update_task "run_status = 4, error_msg = CONCAT(IFNULL(error_msg,''), '\nGenerate report failed\n', '$error_msg')"
            fi
        else
            log "Another progress is running: sh load_active3.sh $prod_id $start_date $end_date"
        fi
    fi
}

# 检查可执行任务
function check()
{
    get_tasks | while read prod_id prod_name start_date end_date keep_pct0 rand0 run_status pre_run new_status active_status visit_status report_status; do
        if [[ $run_status -eq 1 ]]; then
            any_status=$((new_status + active_status + visit_status + report_status))
            if [[ $any_status -eq 0 ]]; then
                log "The task($prod_id, $start_date, $end_date) is already done, now to update the task status"
                update_task "run_status = 3"
            else
                log "Run task($prod_id, $start_date, $end_date)"
                update_task "run_status = 2"
                run &
            fi
        elif [[ $run_status -eq 2 ]]; then
            log "The task($prod_id, $start_date, $end_date, $run_status) is running"
        else
            log "The task($prod_id, $start_date, $end_date, $run_status) is not ready yet"
        fi
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
