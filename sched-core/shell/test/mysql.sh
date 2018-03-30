# mysql技巧


# 查看binlog文件列表
show binary logs

# 查看当前正在写入的binlog文件
show master status

# 查看指定binlog文件内容
mysqlbinlog --no-defaults --start-datetime='2017-05-17 00:00:00' --stop-datetime='2017-05-17 23:59:59' -d schedule /data/mysql/mysql-bin.000012

# 用mysql查看binlog
show binlog events [in 'log_name'] [from pos] [limit [offset,]row_count]


# 监控sql语句
mysqlpcap -z


# group_concat
SELECT task_id, GROUP_CONCAT(DISTINCT task_pid ORDER BY task_pid SEPARATOR ', ') FROM t_task_link GROUP BY task_id;


# sql_mode