# 任务调度器工具


source $SCHED_HOME/scheduler/config.sh


# 更新服务器心跳时间
function send_heartbeat()
{
    echo "UPDATE t_server SET beat_time = NOW() WHERE id = $SERVER_ID AND ip = '$LOCAL_IP';" | execute_meta
}

# 获取“时间间隔”任务
function get_task_interval()
{
    echo "LOCK TABLES t_task READ LOCAL, t_task AS a READ LOCAL,
    t_task_pool WRITE, t_task_pool as d WRITE,
    t_server AS b READ LOCAL,
    t_cluster AS c READ LOCAL,
    t_task_link AS e READ LOCAL;
    CALL p_get_task_interval($SERVER_ID);
    UNLOCK TABLES;
    " | execute_meta
}

# 获取子任务
function get_task_children()
{
    local task_id="$1"

    echo "SELECT task_id FROM t_task_link WHERE task_pid = $task_id;" | execute_meta
}

# 获取就绪任务，根据任务优先级和并发数
# 锁表:
# 1、t_task_pool 写
# 2、t_task 读
# 3、t_server 读
# 4、t_cluster 读
function get_task_ready()
{
    echo "LOCK TABLES t_task_pool WRITE, t_task_pool as a WRITE,
    t_task as b READ LOCAL,
    t_server READ LOCAL, t_server as c READ LOCAL,
    t_cluster as d READ LOCAL;
    CALL p_get_task_ready($SERVER_ID);
    UNLOCK TABLES;
    " | execute_meta
}

# 查询超时任务
function get_task_timeout()
{
    echo "SELECT
      a.task_id,
      DATE_FORMAT(a.run_time, '%Y%m%d%H%i%s')
    FROM t_task_pool a
    INNER JOIN t_task b
    ON a.task_id = b.id
    AND a.task_state = $TASK_STATE_RUNNING
    AND TIMESTAMPDIFF(MINUTE, a.start_time, NOW()) > b.timeout;
    " | execute_meta
}

# 获取任务信息
function get_task()
{
    local task_id="$1"

    echo "SELECT priority, max_try_times, create_by FROM t_task WHERE id = $task_id;" | execute_meta
}

# 获取任务运行器
function get_task_executor()
{
    local task_id="$1"

    echo "SELECT task_executor FROM t_task a INNER JOIN t_task_type b ON a.type_id = b.id AND a.id = $task_id;" | execute_meta
}
