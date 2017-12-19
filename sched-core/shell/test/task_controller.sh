#!/bin/bash
#
# 自动检测任务并生成数据


MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWD=mysql
MYSQL_DB=third
MYSQL_CHARSET=utf8

# 检测时间间隔(60秒)
CHECK_INTERVAL=60

# 数据文件目录
DATADIR=$HOME/data2
# 日志文件目录
LOGDIR=$HOME/logs2


# 创建目录
mkdir -p $LOGDIR

# 记录日志
function log()
{
    echo "$(date +'%F %T') [ $@ ]"
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
      run_date,
      IF(new_time > 0, 0, 1),
      IF(active_time > 0, 0, 1),
      IF(visit_time > 0, 0, 1),
      IF(report_time > 0, 0, 1)
    FROM t_prod_run
    WHERE run_status = 1;
    " | exec_sql
}

# 获取新增量
function get_new_cnt()
{
    echo "SELECT SUM(adduser) FROM l_all_add WHERE stattime = '$run_date' AND proname = '$prod_name';" | exec_sql
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

# 生成访问日志
function gen_visit()
{
    sh gen_data2-1.sh -b $prod_id,$run_date,$run_date > $LOGDIR/${prod_id}.3 2>&1
    if [[ $? -eq 0 ]]; then
        # 更新访问生成时间
        update_task "visit_time = NOW()"

        # 更新任务状态
        update_task "run_status = 3" "AND visit_time > 0 AND report_time > 0"
    else
        local error_msg=`grep -i error $LOGDIR/${prod_id}.log.3`
        update_task "run_status = 4, error_msg = CONCAT(error_msg, '\nGenerate visit failed\n', '$error_msg')"
    fi
}

# 运行
function run()
{
    # 新增
    if [[ $new_status -eq 1 ]]; then
        # 检查生成android id的锁是否存在
        while test -f $DATADIR/aid.lock; do
            sleep 1
        done
        # 创建锁
        touch $DATADIR/aid.lock

        # 检查android id是否够用
        total_cnt=`wc -l $DATADIR/android_id | awk '{print $1}'`
        # 当前分配的最大id
        max_id=`cat $DATADIR/max_id`
        # 新增量
        new_cnt=`get_new_cnt`
        diff=$((max_id + new_cnt - total_cnt))
        # 如果不够，重新生成
        if [[ $diff -gt 0 ]]; then
            sh gen_data2-1.sh -a $diff > $LOGDIR/aid.log 2>&1
            if [[ $? -gt 0 ]]; then
                error_msg=`grep -i error $LOGDIR/aid.log`
                update_task "run_status = 4, error_msg = CONCAT(error_msg, '\nGenerate android id failed\n', '$error_msg')"

                # 出错退出
                exit 1
            fi
        fi

        sh gen_data2.sh -a $prod_id,$run_date,$run_date > $LOGDIR/${prod_id}.log.1 2>&1
        if [[ $? -eq 0 ]]; then
            # 更新新增生成时间
            update_task "new_time = NOW()"
        else
            error_msg=`grep -i error $LOGDIR/${prod_id}.log.1`
            update_task "run_status = 4, error_msg = CONCAT(error_msg, '\nGenerate new failed\n', '$error_msg')"

            # 出错退出
            exit 1
        fi

        # 释放锁
        rm -f $DATADIR/aid.lock
    fi

    # 活跃
    if [[ $active_status -eq 1 ]]; then
        sh gen_data2.sh -b $prod_id,$run_date,$run_date > $LOGDIR/${prod_id}.log.2 2>&1
        if [[ $? -eq 0 ]]; then
            # 更新活跃生成时间
        update_task "active_time = NOW()"
        else
            error_msg=`grep -i error $LOGDIR/${prod_id}.log.2`
            update_task "run_status = 4, error_msg = CONCAT(error_msg, '\nGenerate active failed\n', '$error_msg')"

            # 出错退出
            exit 1
        fi
    fi

    # 访问日志
    if [[ $visit_status -eq 1 && `ps aux | grep "gen_data2-1\.sh -b $prod_id,$run_date,$run_date"` ]]; then
        gen_visit &
    fi

    # 统计报表
    if [[ $report_status -eq 1 && `ps aux | grep "sh load_active2\.sh $prod_id,$run_date,$run_date"` ]]; then
        sh load_active2.sh $prod_id,$run_date,$run_date > $LOGDIR/${prod_id}.4 2>&1
        if [[ $? -eq 0 ]]; then
            # 更新报表生成时间
            update_task "report_time = NOW()"
            # 更新任务状态
            update_task "run_status = 3" "AND visit_time > 0 AND report_time > 0"
        else
            local error_msg=`grep -i error $LOGDIR/${prod_id}.log.4`
            update_task "run_status = 4, error_msg = CONCAT(error_msg, '\nGenerate report failed\n', '$error_msg')"
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

while :; do
    # 检查可执行任务
    log "Check tasks"
    check

    # 休眠一段时间
    log "Sleep $CHECK_INTERVAL seconds"
    sleep $CHECK_INTERVAL
done
