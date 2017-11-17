#!/bin/bash
#
# 任务执行报告


# 任务运行状态
function task_state()
{
    echo "SELECT 
      DATE(run_time),
      CASE task_state 
      WHEN 0 THEN '等待' 
      WHEN 1 THEN '就绪' 
      WHEN 2 THEN '已经分配' 
      WHEN 3 THEN '正在运行'
      WHEN 6 THEN '运行成功' 
      WHEN 8 THEN '被杀死' 
      WHEN 9 THEN '运行失败' 
      ELSE '未知' 
      END,
      COUNT(DISTINCT task_id),
      COUNT(1) 
    FROM t_task_pool 
    WHERE run_time >= CURDATE() - INTERVAL 2 DAY 
    GROUP BY DATE(run_time), task_state;
    " | execute_meta | awk -F '\t' 'BEGIN{
        print "<table border=\"1\" style=\"text-align:center\"><tr><th>运行日期</th><th>任务状态</th><th>任务数</th><th>任务实例数</th></tr>"
    }{
        count[$1]++
        if(p_run_date == $1){
            last=last"<tr><td>"$2"</td><td>"$3"</td><td>"$4"</td></tr>"
        }else{
            if(p_run_date != ""){
                gsub("row_count",count[p_run_date],first)
                print first""last
            }
            first="<tr><td rowspan=\"row_count\">"$1"</td><td>"$2"</td><td>"$3"</td><td>"$4"</td></tr>"
            last=""
        }
        p_run_date=$1
    } END {
        gsub("row_count",count[p_run_date],first)
        print first""last
        print "</table>"
    }'
}

# 失败任务
function failed_task()
{
    echo "SELECT 
      a.task_id,
      a.run_time,
      c.task_group,
      c.name,
      c.create_user,
      c.task_cycle,
      a.tried_times,
      b.content
    FROM t_task_pool a 
    INNER JOIN t_task_log b 
    INNER JOIN t_task c 
    ON a.task_id = b.task_id 
    AND a.task_id = c.id 
    AND a.run_time = b.run_time 
    AND a.task_state = 9 
    AND b.level = 3 
    AND a.start_time >= NOW() - INTERVAL 25 HOUR
    GROUP BY a.task_id, a.run_time;
    " | execute_meta | awk -F '\t' 'BEGIN{
        print "<table border=\"1\" style=\"text-align:center\"><tr><th>任务ID</th><th>运行时间</th><th>任务组</th><th>任务名称</th><th>创建者</th><th>任务周期</th><th>尝试次数</th><th>日志</th></tr>"
    }{
        printf("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td align=\"left\">%s</td></tr>",$1,$2,$3,$4,$5,$6,$7,$8)
    }END{
        print "</table>"
    }'
}

# 今日任务耗时Top10
function time_consume()
{
    echo "SELECT 
      a.task_id,
      a.run_time,
      b.task_group,
      b.name,
      b.create_user,
      b.task_cycle,
      ROUND(TIMESTAMPDIFF(SECOND, a.start_time, a.end_time) / 60, 2)
    FROM t_task_pool a 
    INNER JOIN t_task b 
    ON a.task_id = b.id 
    AND b.task_cycle IN ('day', 'week', 'month', 'hour') 
    AND a.start_time >= NOW() - INTERVAL 25 HOUR 
    GROUP BY a.task_id, a.run_time 
    ORDER BY 7 DESC 
    LIMIT 10;
    " | execute_meta | awk -F '\t' 'BEGIN{
        print "<table border=\"1\" style=\"text-align:center\"><tr><th>任务ID</th><th>运行时间</th><th>任务组</th><th>任务名称</th><th>创建者</th><th>任务周期</th><th>任务耗时(分)</th></tr>"
    }{
        printf("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>",$1,$2,$3,$4,$5,$6,$7)
    }END{
        print "</table>"
    }'
}

# 生成邮件
function create_mail()
{
    # 邮件标题
    echo "任务执行报告" > $log_path/mail.tmp

    # 任务运行状态
    echo "<h2>任务运行状态</h2>" >> $log_path/mail.tmp
    task_state >> $log_path/mail.tmp

    # 失败任务
    echo "<h2>失败任务</h2>" >> $log_path/mail.tmp
    failed_task | sed 's/\\n/<br\/>/g' >> $log_path/mail.tmp

    # 今日任务耗时Top 10
    echo "<h2>今日任务耗时Top 10</h2>" >> $log_path/mail.tmp
    time_consume >> $log_path/mail.tmp
}

function execute()
{
    # 生成邮件
    create_mail
}
execute "$@"