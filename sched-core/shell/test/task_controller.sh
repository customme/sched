#!/bin/bash
#
# 自动检测任务并生成数据


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
LOGDIR=/work/www/shell/logs


# 创建目录
mkdir -p $DATADIR $LOGDIR

# 记录日志
function log()
{
    echo "$(date +'%F %T.%N') [ $@ ]"
}

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
      prod_id,
      prod_name,
      MIN(run_date),
      IF(new_time > 0, 0, 1),
      IF(active_time > 0, 0, 1),
      IF(visit_time > 0, 0, 1),
      IF(report_time > 0, 0, 1)
    FROM t_prod_run
    WHERE run_status = 1
    GROUP BY prod_id;
    " | exec_sql
}

# 获取新增量
function get_new_cnt()
{
    echo "SELECT IFNULL(SUM(adduser), 0) FROM l_all_add WHERE stattime = '$run_date' AND proname = '$prod_name';" | exec_sql
}

# 更新任务状态
function update_task()
{
    local updates="$1"
    local filters="$2"
    local sql="UPDATE t_prod_run SET $updates WHERE prod_id = '$prod_id' AND run_date = '$run_date' $filters;"

    log "$sql"
    echo "$sql" | exec_sql
}

# 生成访问
function gen_visit()
{
    # 生成访问
    sh gen_data3-1.sh -b $prod_id,$run_date,$run_date > $LOGDIR/${prod_id}.${run_date}.log.3 2> $LOGDIR/${prod_id}.${run_date}.err.3
    if [[ $? -eq 0 ]]; then
        # 更新访问生成时间
        update_task "visit_time = NOW()"

        # 更新任务状态
        update_task "run_status = 3" "AND visit_time > 0 AND report_time > 0"
    else
        error_msg=`sed "s/\('\|\"\)/\\\\\1/g" $LOGDIR/${prod_id}.${run_date}.err.3 | awk '{printf("%s\\\n",$0)}'`
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

        # 检查生成android id的锁是否存在
        while test -f $DATADIR/aid.lock; do
            sleep 1
        done
        # 创建锁
        log "Create lock ($prod_id, $run_date)"
        touch $DATADIR/aid.lock

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
        if [[ $diff -gt 0 ]]; then
            # 生成android id
            sh gen_data3-1.sh -a $diff > $LOGDIR/aid.log 2> $LOGDIR/aid.err
            if [[ $? -gt 0 ]]; then
                error_msg=`sed "s/\('\|\"\)/\\\\\1/g" $LOGDIR/aid.err | awk '{printf("%s\\\n",$0)}'`
                update_task "run_status = 4, error_msg = CONCAT(IFNULL(error_msg,''), '\nGenerate android id failed\n', '$error_msg')"

                # 出错退出
                exit 1
            fi
        fi

        # 生成新增
        sh gen_data3.sh -a $prod_id,$run_date,$run_date > $LOGDIR/${prod_id}.log.1 2> $LOGDIR/${prod_id}.err.1
        if [[ $? -eq 0 ]]; then
            # 更新新增生成时间
            update_task "new_time = NOW()"
        else
            error_msg=`sed "s/\('\|\"\)/\\\\\1/g" $LOGDIR/${prod_id}.err.1 | awk '{printf("%s\\\n",$0)}'`
            update_task "run_status = 4, error_msg = CONCAT(IFNULL(error_msg,''), '\nGenerate new failed\n', '$error_msg')"

            # 出错退出
            exit 1
        fi

        # 释放锁
        log "Release lock ($prod_id, $run_date)"
        rm -f $DATADIR/aid.lock
    fi

    # 活跃
    if [[ $active_status -eq 1 ]]; then
        # 生成活跃
        sh gen_data3.sh -b $prod_id,$run_date,$run_date > $LOGDIR/${prod_id}.${run_date}.log.2 2> $LOGDIR/${prod_id}.${run_date}.err.2
        if [[ $? -eq 0 ]]; then
            # 更新活跃生成时间
            update_task "active_time = NOW()"
        else
            error_msg=`sed "s/\('\|\"\)/\\\\\1/g" $LOGDIR/${prod_id}.${run_date}.err.2 | awk '{printf("%s\\\n",$0)}'`
            update_task "run_status = 4, error_msg = CONCAT(IFNULL(error_msg,''), '\nGenerate active failed\n', '$error_msg')"

            # 出错退出
            exit 1
        fi
    fi

    # 访问
    if [[ $visit_status -eq 1 && ! `ps aux | grep "gen_data3-1\.sh -b $prod_id,$run_date,$run_date"` ]]; then
        gen_visit &
    fi

    # 报表
    if [[ $report_status -eq 1 && ! `ps aux | grep "sh load_active3\.sh $prod_id,$run_date,$run_date"` ]]; then
        # 统计报表
        sh load_active3.sh $prod_id $run_date $run_date > $LOGDIR/${prod_id}.${run_date}.log.4 2> $LOGDIR/${prod_id}.${run_date}.err.4
        if [[ $? -eq 0 ]]; then
            # 更新报表生成时间
            update_task "report_time = NOW()"
            # 更新任务状态
            update_task "run_status = 3" "AND visit_time > 0 AND report_time > 0"
        else
            error_msg=`sed "s/\('\|\"\)/\\\\\1/g" $LOGDIR/${prod_id}.${run_date}.err.4 | awk '{printf("%s\\\n",$0)}'`
            update_task "run_status = 4, error_msg = CONCAT(IFNULL(error_msg,''), '\nGenerate report failed\n', '$error_msg')"
        fi
    fi
}

# 检查可执行任务
function check()
{
    get_tasks | while read prod_id prod_name run_date new_status active_status visit_status report_status; do
        any_status=$((new_status + active_status + visit_status + report_status))
        if [[ $any_status -eq 0 ]]; then
            log "There is no task to run"
            update_task "run_status = 3"
        else
            log "Run task: $prod_id $run_date"
            update_task "run_status = 2"
            run &
        fi
    done
}

# 循环检测
while :; do
    # 检查可执行任务
    log "Check tasks"
    check

    # 休眠一段时间
    log "Sleep $CHECK_INTERVAL seconds"
    sleep $CHECK_INTERVAL
done
