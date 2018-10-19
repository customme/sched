CREATE DATABASE IF NOT EXISTS `sched` DEFAULT CHARACTER SET utf8;

USE `sched`;

SET @CREATE_BY = 'superz';

DROP TABLE IF EXISTS `t_cluster`;
CREATE TABLE `t_cluster` (
  `id` tinyint(4) NOT NULL AUTO_INCREMENT,
  `create_by` varchar(50) COMMENT '创建人',
  `create_date` datetime COMMENT '创建日期',
  `update_by` varchar(50) COMMENT '更新人',
  `update_date` datetime COMMENT '更新日期',
  `name` varchar(64),
  `description` varchar(255),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='集群';
INSERT INTO `t_cluster` (`id`, `create_by`, `create_date`, `name`) VALUES (1, @CREATE_BY, NOW(), '监控集群');

DROP TABLE IF EXISTS `t_server`;
CREATE TABLE `t_server` (
  `id` smallint(6) NOT NULL AUTO_INCREMENT,
  `create_by` varchar(50) COMMENT '创建人',
  `create_date` datetime COMMENT '创建日期',
  `update_by` varchar(50) COMMENT '更新人',
  `update_date` datetime COMMENT '更新日期',
  `name` varchar(64),
  `cluster_id` tinyint(4) NOT NULL COMMENT '集群ID',
  `ip` varchar(64) NOT NULL COMMENT 'IP地址',
  `hostname` varchar(64) COMMENT '主机名',
  `os` varchar(64) COMMENT '操作系统',
  `task_maximum` tinyint(4) NOT NULL DEFAULT '3' COMMENT '最大任务并行数',
  `beat_time` datetime COMMENT '心跳时间',
  `description` varchar(255),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='服务器';

DROP TABLE IF EXISTS `t_db_conn`;
CREATE TABLE `t_db_conn` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `create_by` varchar(50) COMMENT '创建人',
  `create_date` datetime COMMENT '创建日期',
  `update_by` varchar(50) COMMENT '更新人',
  `update_date` datetime COMMENT '更新日期',
  `name` varchar(255),
  `db_name` varchar(64) NOT NULL COMMENT '数据库名',
  `type_id` tinyint(4) NOT NULL COMMENT '数据库类型ID',
  `conn_type` tinyint(4) NOT NULL DEFAULT '0' COMMENT '数据库连接类型(0:CLI, 1:JDBC, 2:ODBC, 3:HTTP, 4:ZOOKEEPER)',
  `username` varchar(64) COMMENT '数据库连接用户名',
  `password` varchar(255) COMMENT '数据库连接密码',
  `hostname` varchar(64) COMMENT '数据库主机',
  `port` int(11) COMMENT '数据库端口号',
  `charset` varchar(32) COMMENT '数据库编码',
  `description` varchar(255),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='数据库连接';

DROP TABLE IF EXISTS `t_db_type`;
CREATE TABLE `t_db_type` (
  `id` tinyint(4) NOT NULL AUTO_INCREMENT,
  `create_by` varchar(50) COMMENT '创建人',
  `create_date` datetime COMMENT '创建日期',
  `update_by` varchar(50) COMMENT '更新人',
  `update_date` datetime COMMENT '更新日期',
  `code` varchar(64) NOT NULL,
  `default_port` int(11) COMMENT '默认端口',
  `default_charset` varchar(32) COMMENT '默认字符集',
  `description` varchar(255),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='数据库类型';
INSERT INTO `t_db_type` (`id`, `create_by`, `create_date`, `code`, `default_port`, `default_charset`, `description`) VALUES 
(1, @CREATE_BY, NOW(), 'MYSQL', 3306, 'utf8', 'MySQL'),
(2, @CREATE_BY, NOW(), 'ORACLE', 1521, 'UTF-8', 'Oracle'),
(3, @CREATE_BY, NOW(), 'MSSQL', 1433, NULL, 'Microsoft SQL Server'),
(4, @CREATE_BY, NOW(), 'SYBASE', 5000, NULL, 'Sybase'),
(5, @CREATE_BY, NOW(), 'POSTGRESQL', 5432, 'utf-8', 'PostgreSQL'),
(6, @CREATE_BY, NOW(), 'DB2', 5000, NULL, 'IBM DB2'),
(7, @CREATE_BY, NOW(), 'HIVE', 10000, NULL, 'Apache Hive'),
(8, @CREATE_BY, NOW(), 'DERBY', 1527, NULL, 'Apache Derby'),
(9, @CREATE_BY, NOW(), 'FS', NULL, NULL, 'Local File System'),
(10, @CREATE_BY, NOW(), 'HDFS', 8082, NULL, 'Apache Hadoop Distributed File System'),
(11, @CREATE_BY, NOW(), 'SAIKU', 8080, NULL, 'Saiku');

DROP TABLE IF EXISTS `t_task_type`;
CREATE TABLE `t_task_type` (
  `id` tinyint(4) NOT NULL AUTO_INCREMENT,
  `create_by` varchar(50) COMMENT '创建人',
  `create_date` datetime COMMENT '创建日期',
  `update_by` varchar(50) COMMENT '更新人',
  `update_date` datetime COMMENT '更新日期',
  `code` varchar(64) NOT NULL,
  `task_executor` varchar(255) NOT NULL COMMENT '任务执行器',
  `max_try_times` tinyint(4) NOT NULL DEFAULT '3' COMMENT '最多尝试次数',
  `description` varchar(255),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='任务类型';
INSERT INTO `t_task_type` (`id`, `create_by`, `create_date`, `code`, `task_executor`, `description`) VALUES 
(1, @CREATE_BY, NOW(), 'dummy', 'dummy.sh', '空任务，什么也不做，测试用'),
(2, @CREATE_BY, NOW(), 'mysql2mysql', 'mysql/mysql2mysql.sh', 'MySQL到MySQL数据同步'),
(3, @CREATE_BY, NOW(), 'mysql2hive', 'hive/mysql2hive.sh', 'MySQL到Hive数据同步'),
(4, @CREATE_BY, NOW(), 'hive2mysql', 'mysql/hive2mysql.sh', 'Hive到MySQL数据同步'),
(5, @CREATE_BY, NOW(), 'mysql_exec', 'mysql/exec_sql.sh', '执行MySQL语句'),
(6, @CREATE_BY, NOW(), 'shell_exec', 'script/exec_shell.sh', '执行Shell脚本'),
(7, @CREATE_BY, NOW(), 'mysql_loader', 'mysql/file_loader.sh', '文件入库mysql'),
(8, @CREATE_BY, NOW(), 'saiku_exec', 'saiku/exec_mdx.sh', '模拟Saiku执行MDX'),
(9, @CREATE_BY, NOW(), 'saiku_refresh', 'saiku/refresh_cube.sh', '刷新Saiku Cube'),
(10, @CREATE_BY, NOW(), 'mysql_backup', 'mysql/backup.sh', '备份MySQL表到文件'),
(11, @CREATE_BY, NOW(), 'url_monitor', 'monitor/url_monitor.sh', 'URL监控告警'),
(12, @CREATE_BY, NOW(), 'spark_submit', 'spark/spark_submit.sh', '提交spark任务'),
(13, @CREATE_BY, NOW(), 'hdfs_loader', 'hadoop/hdfs_loader.sh', '本地文件上传至hdfs');

DROP TABLE IF EXISTS `t_task`;
CREATE TABLE `t_task` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `create_by` varchar(50) COMMENT '创建人',
  `create_date` datetime COMMENT '创建日期',
  `update_by` varchar(50) COMMENT '更新人',
  `update_date` datetime COMMENT '更新日期',
  `name` varchar(64),
  `task_group` varchar(64) NOT NULL DEFAULT 'default' COMMENT '任务组',
  `type_id` tinyint(4) NOT NULL COMMENT '任务类型ID',
  `task_status` tinyint(4) NOT NULL DEFAULT '0' COMMENT '任务状态(0:暂停, 1:正常, -1:删除)',
  `task_cycle` varchar(16) NOT NULL COMMENT '任务周期(day:天, week:周, month:月, hour:小时, interval:时间间隔, instant:即时)',
  `cycle_value` varchar(64) COMMENT '周期值',
  `date_serial` tinyint(1) NOT NULL DEFAULT '0' COMMENT '时间串行(1表示串行)',
  `priority` tinyint(4) NOT NULL DEFAULT '0' COMMENT '任务优先级(值越小优先级越高)',
  `max_try_times` tinyint(4) NOT NULL DEFAULT '3' COMMENT '最多尝试次数',
  `timeout` smallint(6) NOT NULL DEFAULT '120' COMMENT '超时时间(分)',
  `cluster_id` tinyint(4) COMMENT '集群ID',
  `server_id` smallint(6) COMMENT '服务器ID',
  `start_time` datetime NOT NULL COMMENT '开始时间',
  `end_time` datetime COMMENT '结束时间',
  `first_time` datetime COMMENT '首次运行时间',
  `description` varchar(255),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='任务';
INSERT INTO `t_task` (`id`, `create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(1, @CREATE_BY, NOW(), '空任务', '调度系统', 1, 1, 'hour', 1, NOW()),
(2, @CREATE_BY, NOW(), '任务执行报告', '调度系统', 6, 1, 'day', 1, CURDATE() + INTERVAL 1 DAY + INTERVAL 8 HOUR),
(3, @CREATE_BY, NOW(), '调度系统元数据库备份', '调度系统', 6, 1, 'day', 1, CURDATE() + INTERVAL 23 HOUR);

DROP TABLE IF EXISTS `t_task_ext`;
CREATE TABLE `t_task_ext` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `create_by` varchar(50) COMMENT '创建人',
  `create_date` datetime COMMENT '创建日期',
  `update_by` varchar(50) COMMENT '更新人',
  `update_date` datetime COMMENT '更新日期',
  `task_id` int(11) NOT NULL COMMENT '任务ID',
  `prop_name` varchar(64) NOT NULL COMMENT '属性名',
  `prop_value` text COMMENT '属性值',
  PRIMARY KEY (`id`),
  UNIQUE KEY (`task_id`, `prop_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='任务扩展属性';
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), 1, 'tar_cmd', 'source $SCHED_HOME/task/task_report.sh'),
(@CREATE_BY, NOW(), 1, 'is_alarm', '1'),
(@CREATE_BY, NOW(), 1, 'alarm_way', '0'),
(@CREATE_BY, NOW(), 1, 'sub_emails', 'zhangchao@9zhitx.com'),
(@CREATE_BY, NOW(), 2, 'tar_cmd', 'source $SCHED_HOME/task/db_backup.sh');

DROP TABLE IF EXISTS `t_task_pool`;
CREATE TABLE `t_task_pool` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `create_by` varchar(50) COMMENT '创建人',
  `create_date` datetime COMMENT '创建日期',
  `update_by` varchar(50) COMMENT '更新人',
  `update_date` datetime COMMENT '更新日期',
  `task_id` int(11) NOT NULL COMMENT '任务ID',
  `run_time` datetime NOT NULL COMMENT '运行时间',
  `task_state` tinyint(4) NOT NULL DEFAULT '0' COMMENT '任务状态(0:等待, 1:就绪, 2:已经分配, 3:正在运行, 6:运行成功, 8:被杀死, 9:运行失败)',
  `priority` tinyint(4) NOT NULL DEFAULT '0' COMMENT '任务优先级(值越小优先级越高)',
  `max_try_times` tinyint(4) NOT NULL DEFAULT '3' COMMENT '最多尝试次数',
  `tried_times` tinyint(4) NOT NULL DEFAULT '0' COMMENT '已经尝试次数',
  `redo_flag` tinyint(4) NOT NULL DEFAULT '0' COMMENT '重做标记(1表示重做)',
  `run_server` int(11) COMMENT '运行服务器',
  `run_params` varchar(255) COMMENT '运行时参数',
  `start_time` datetime COMMENT '开始时间',
  `end_time` datetime COMMENT '结束时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY (`task_id`, `run_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='任务实例';

DROP TABLE IF EXISTS `t_task_link`;
CREATE TABLE `t_task_link` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `create_by` varchar(50) COMMENT '创建人',
  `create_date` datetime COMMENT '创建日期',
  `update_by` varchar(50) COMMENT '更新人',
  `update_date` datetime COMMENT '更新日期',
  `task_id` int(11) NOT NULL COMMENT '任务ID',
  `task_pid` int(11) NOT NULL COMMENT '父任务ID',
  `link_type` tinyint(4) NOT NULL DEFAULT '0' COMMENT '依赖类型(0:最后一个周期, 1:全周期, 2:任意一个周期)',
  PRIMARY KEY (`id`),
  UNIQUE KEY (`task_id`, `task_pid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='任务依赖关系';

DROP TABLE IF EXISTS `t_task_log`;
CREATE TABLE `t_task_log` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `task_id` int(11) NOT NULL COMMENT '任务ID',
  `run_time` datetime NOT NULL COMMENT '运行时间',
  `seq_no` int(11) COMMENT '流水号',
  `level` tinyint(4) NOT NULL DEFAULT '0' COMMENT '日志级别(0:调试日志, 1:标准日志, 2:警告日志, 3:错误日志)',
  `content` text COMMENT '日志内容',
  `log_time` datetime COMMENT '记录时间',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='任务运行日志';

-- 获取任务周期为'interval'的任务
-- 1.任务状态为正常 2.任务没有正在运行 3.没有父任务依赖
DELIMITER ;;
DROP PROCEDURE IF EXISTS `p_get_task_interval`;
CREATE PROCEDURE `p_get_task_interval` (in_server INT)
BEGIN
  DECLARE _task_id INT;
  DECLARE _create_by VARCHAR(50);

  SET @TASK_STATUS_NORMAL = 1;
  SET @TASK_CYCLE_INTERVAL = 'interval';
  SET @TASK_STATE_ASSIGNED = 2;
  SET @TASK_STATE_RUNNING = 3;

  -- 获取任务
  SELECT t.id, t.create_by INTO _task_id, _create_by FROM 
  ( SELECT a.id, a.create_by FROM t_task a 
    INNER JOIN t_server b 
    INNER JOIN t_cluster c 
    ON a.cluster_id = c.id 
    AND b.cluster_id = c.id 
    AND b.id = in_server 
    AND (
      a.server_id IS NULL 
      OR a.server_id = b.id 
    )
    AND a.task_status = @TASK_STATUS_NORMAL 
    AND a.start_time <= NOW() 
    AND (
      a.end_time >= NOW() 
      OR a.end_time IS NULL 
    )
    AND a.task_cycle = @TASK_CYCLE_INTERVAL 
    ORDER BY a.priority 
  ) t
  LEFT JOIN t_task_pool d 
  ON t.id = d.task_id 
  AND d.task_state = @TASK_STATE_RUNNING 
  LEFT JOIN t_task_link e 
  ON t.id = e.task_id 
  WHERE d.task_id IS NULL 
  AND e.task_id IS NULL 
  LIMIT 1;

  -- 插入任务实例，标记该任务已经被分配
  IF _task_id > 0 THEN
    SET @run_time = NOW();
    INSERT INTO t_task_pool (task_id, run_time, task_state, run_server, create_by, create_date) VALUES(_task_id, @run_time, @TASK_STATE_ASSIGNED, in_server, _create_by, @run_time);
    -- 返回任务
    SELECT id, DATE_FORMAT(@run_time, '%Y%m%d%H%i%s'), cycle_value FROM t_task WHERE id = _task_id;
  END IF;
END;;

-- 获取任务状态为'就绪','被杀死','运行失败'的任务
-- 1.服务器当前并发数没达到最大值 2.任务尝试次数没达到最大值
DROP PROCEDURE IF EXISTS `p_get_task_ready`;
CREATE PROCEDURE `p_get_task_ready` (in_server INT)
BEGIN
  DECLARE _task_id INT;
  DECLARE _run_time DATETIME;

  DECLARE done INT DEFAULT FALSE;
  DECLARE cur CURSOR FOR SELECT task_id, run_time FROM tmp_task_ready;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  SET @TASK_STATE_READY = 1;
  SET @TASK_STATE_ASSIGNED = 2;
  SET @TASK_STATE_RUNNING = 3;
  SET @TASK_STATE_KILLED = 8;
  SET @TASK_STATE_FAILED = 9;
  SET @server_id = in_server;
  SET @task_maximum=(SELECT task_maximum FROM t_server WHERE id = @server_id);
  SET @cur_task_count=(SELECT COUNT(1) FROM t_task_pool WHERE task_state = @TASK_STATE_RUNNING AND run_server = @server_id);
  SET @task_count=@task_maximum - @cur_task_count;

  -- 创建临时表
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_task_ready (task_id INT, run_time DATETIME, last_try TINYINT);

  -- 获取任务
  PREPARE ps FROM "INSERT INTO tmp_task_ready SELECT a.task_id, a.run_time, a.max_try_times = a.tried_times + 1 
FROM t_task_pool a 
INNER JOIN t_task b 
INNER JOIN t_server c 
INNER JOIN t_cluster d 
ON a.task_id = b.id 
AND a.task_state IN (?, ?, ?) 
AND a.tried_times < a.max_try_times 
AND b.cluster_id = d.id 
AND c.cluster_id = d.id 
AND c.id = ? 
AND (b.server_id IS NULL OR b.server_id = c.id) 
ORDER BY a.priority, a.task_state, a.run_time 
LIMIT ?";
  EXECUTE ps USING @TASK_STATE_READY, @TASK_STATE_KILLED, @TASK_STATE_FAILED, @server_id, @task_count;
  DEALLOCATE PREPARE ps;

  -- 更新任务
  OPEN cur;
  read_loop: LOOP
    FETCH cur INTO _task_id, _run_time;
    IF done THEN
      LEAVE read_loop;
    END IF;
    UPDATE t_task_pool 
    SET task_state = @TASK_STATE_ASSIGNED, start_time = NULL, end_time = NULL, tried_times = tried_times + 1, run_server = @server_id, update_date = NOW() 
    WHERE task_id = _task_id AND run_time = _run_time;
  END LOOP;
  CLOSE cur;

  -- 返回任务
  SELECT task_id, DATE_FORMAT(run_time, '%Y%m%d%H%i%s') run_time, last_try FROM tmp_task_ready;
END;;

-- 查找子任务依赖
DROP PROCEDURE IF EXISTS `p_find_links`;
CREATE PROCEDURE `p_find_links` (in_task_id INT, in_depth INT)
BEGIN
  DECLARE _task_id INT;
  DECLARE done INT DEFAULT FALSE;
  DECLARE cur CURSOR FOR SELECT task_id FROM t_task_link WHERE task_pid = in_task_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  INSERT IGNORE INTO tmp_links SELECT task_pid, task_id, link_type, in_depth, create_by, create_date FROM t_task_link WHERE task_pid = in_task_id;

  OPEN cur;
  FETCH cur INTO _task_id;
  WHILE NOT done DO
    CALL p_find_links(_task_id, in_depth + 1);
    FETCH cur INTO _task_id;
  END WHILE;
  CLOSE cur;
END;;

-- 获取子任务依赖
DROP PROCEDURE IF EXISTS `p_get_links`;
CREATE PROCEDURE `p_get_links` (in_task_id INT)
BEGIN
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_links (task_pid INT, task_id INT, link_type INT, depth INT, create_by VARCHAR(50), create_date DATETIME);
  DELETE FROM tmp_links;

  SET @@max_sp_recursion_depth = 255;
  CALL p_find_links(in_task_id, 1);

  SELECT task_pid, task_id, link_type, depth, create_by, create_date FROM tmp_links ORDER BY depth, task_pid, task_id;
END;;

-- 查找父任务依赖
DROP PROCEDURE IF EXISTS `p_find_plinks`;
CREATE PROCEDURE `p_find_plinks` (in_task_id INT, in_depth INT)
BEGIN
  DECLARE _task_id INT;
  DECLARE done INT DEFAULT FALSE;
  DECLARE cur CURSOR FOR SELECT task_pid FROM t_task_link WHERE task_id = in_task_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  INSERT IGNORE INTO tmp_links SELECT task_id, task_pid, link_type, in_depth, create_by, create_date FROM t_task_link WHERE task_id = in_task_id;

  OPEN cur;
  FETCH cur INTO _task_id;
  WHILE NOT done DO
    CALL p_find_plinks(_task_id, in_depth + 1);
    FETCH cur INTO _task_id;
  END WHILE;
  CLOSE cur;
END;;

-- 获取父任务依赖
DROP PROCEDURE IF EXISTS `p_get_plinks`;
CREATE PROCEDURE `p_get_plinks` (in_task_id INT)
BEGIN
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_links (task_id INT, task_pid INT, link_type INT, depth INT, create_by VARCHAR(50), create_date DATETIME);
  DELETE FROM tmp_links;

  SET @@max_sp_recursion_depth = 255;
  CALL p_find_plinks(in_task_id, 1);

  SELECT task_id, task_pid, link_type, depth, create_by, create_date FROM tmp_links ORDER BY depth, task_id, task_pid;
END;;

-- 检测回路
DROP PROCEDURE IF EXISTS `p_check_loop`;
CREATE PROCEDURE `p_check_loop` (in_task_id INT, in_task_pid INT)
BEGIN
  DECLARE _task_id INT;
  DECLARE check_status TINYINT;
  DECLARE done INT DEFAULT FALSE;
  DECLARE cur CURSOR FOR SELECT task_pid FROM t_task_link WHERE task_id = in_task_pid;
  DECLARE EXIT HANDLER FOR NOT FOUND SET done = TRUE;

  IF in_task_id = in_task_pid THEN
    SET check_status = 1;
    SET done = TRUE;
  END IF;

  INSERT INTO tmp_check_status VALUES (in_task_pid, check_status);

  OPEN cur;
  FETCH cur INTO _task_id;
  WHILE NOT done DO
    CALL p_check_loop (in_task_id, _task_id);
    FETCH cur INTO _task_id;
  END WHILE;
  CLOSE cur;
END;;

-- 判断依赖关系是否存在回路(0:否, 1:是)
DROP PROCEDURE IF EXISTS `p_exists_loop`;
CREATE PROCEDURE `p_exists_loop` (in_task_id INT, in_task_pid INT)
BEGIN
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_check_status (task_id INT, check_status TINYINT);
  DELETE FROM tmp_check_status;

  SET @@max_sp_recursion_depth = 255;
  CALL p_check_loop (in_task_id, in_task_pid);

  SET @check_status = (SELECT 1 FROM tmp_check_status WHERE check_status = 1 LIMIT 1);
  SELECT IFNULL(@check_status, 0);
END;;
