-- 初始化任务配置信息

TRUNCATE TABLE t_task;
TRUNCATE TABLE t_task_link;

CREATE TABLE IF NOT EXISTS t_task_history LIKE t_task_pool;
TRUNCATE TABLE t_task_history;
INSERT IGNORE INTO t_task_history SELECT * FROM t_task_pool;
TRUNCATE TABLE t_task_pool;

SET @task_type_id=1;
SET @not_serial=0;
SET @date_serial=1;
SET @cluster_id=1;
SET @create_user='zhangchao';
SET @create_time=NOW();
SET @the_time='23:59:59';
SET @week_num=IF(DAYOFWEEK(NOW()) > 1, DAYOFWEEK(NOW()) - 1, 7);

-- 集群
INSERT INTO `t_cluster` (`id`, `name`, `description`) VALUES (1, '测试集群', '系统功能测试用集群');

-- 服务器
INSERT INTO `t_server` (`id`, `name`, `cluster_id`, `ip`, `hostname`, `description`) VALUES (1, '测试服务器', 1, '127.0.0.1', 'localhost', '系统功能测试用服务器');

-- 数据库连接
INSERT INTO `t_db_conn` (`id`, `name`, `db_name`, `type_id`, `username`, `password`, `host`, `port`, `charset`, `description`, `create_user`, `create_time`) VALUES 
(1, '测试数据库', 'test', 1, 'root', '123456', 'localhost', 3306, 'utf8', '系统功能测试用数据库', 'zhangchao', NOW());

-- 任务配置信息
INSERT INTO t_task ( name, type_id, description, task_cycle, cycle_value, date_serial, cluster_id, start_time, end_time, create_user, create_time ) VALUES 
( '日任务1', @task_type_id, '不串行，无依赖', 'day', NULL, @not_serial, @cluster_id, NOW()-INTERVAL 3 MONTH, NULL, @create_user, @create_time ),
( '日任务2', @task_type_id, '串行，无依赖', 'day', NULL, @date_serial, @cluster_id, NOW()-INTERVAL 5 DAY, NOW()-INTERVAL 1 DAY, @create_user, @create_time ),
( '日任务3', @task_type_id, '不串行，全周期依赖日任务', 'day', NULL, @not_serial, @cluster_id, NOW()-INTERVAL 3 DAY, NULL, @create_user, @create_time ),
( '日任务4', @task_type_id, '不串行，最后一个周期依赖日任务', 'day', NULL, @not_serial, @cluster_id, NOW()-INTERVAL 3 DAY, NULL, @create_user, @create_time ),
( '周任务1', @task_type_id, '不串行，无依赖', 'week', '3', @not_serial, @cluster_id, NOW()-INTERVAL 5 WEEK, NULL, @create_user, @create_time ),
( '周任务2', @task_type_id, '串行，无依赖', 'week', '2', @date_serial, @cluster_id, NOW()-INTERVAL 5 WEEK, NOW()-INTERVAL 1 WEEK, @create_user, @create_time ),
( '周任务3', @task_type_id, '不串行，全周期依赖日任务', 'week', '3', @not_serial, @cluster_id, NOW()-INTERVAL 3 WEEK, NULL, @create_user, @create_time ),
( '周任务4', @task_type_id, '不串行，最后一个周期依赖日任务', 'week', '3', @not_serial, @cluster_id, NOW()-INTERVAL 3 WEEK, NULL, @create_user, @create_time ),
( '周任务5', @task_type_id, '不串行，全周期依赖周任务', 'week', '2', @not_serial, @cluster_id, NOW()-INTERVAL 3 WEEK, NULL, @create_user, @create_time ),
( '周任务6', @task_type_id, '不串行，最后一个周期依赖周任务', 'week', '2', @not_serial, @cluster_id, NOW()-INTERVAL 3 WEEK, NULL,@create_user, @create_time ),
( '月任务1', @task_type_id, '不串行，无依赖', 'month', '05', @not_serial, @cluster_id, NOW()-INTERVAL 3 MONTH, NULL, @create_user, @create_time ),
( '月任务2', @task_type_id, '串行，无依赖', 'month', '08', @date_serial, @cluster_id, NOW()-INTERVAL 5 MONTH, NOW()-INTERVAL 1 MONTH, @create_user, @create_time ),
( '月任务3', @task_type_id, '不串行，全周期依赖日任务', 'month', '07', @not_serial, @cluster_id, NOW()-INTERVAL 3 MONTH, NULL, @create_user, @create_time ),
( '月任务4', @task_type_id, '不串行，最后一个周期依赖日任务', 'month', '07', @not_serial, @cluster_id, NOW()-INTERVAL 3 MONTH, NULL, @create_user, @create_time ),
( '月任务5', @task_type_id, '不串行，全周期依赖月任务', 'month', '10', @not_serial, @cluster_id, NOW()-INTERVAL 3 MONTH, NULL, @create_user, @create_time ),
( '月任务6', @task_type_id, '不串行，最后一个周期依赖月任务', 'month', '10', @not_serial, @cluster_id, NOW()-INTERVAL 3 MONTH, NULL, @create_user, @create_time ),
( '小时任务1', @task_type_id, '不串行，无依赖', 'hour', NULL, @not_serial, @cluster_id, NOW()-INTERVAL 1 DAY, NULL, @create_user, @create_time ),
( '小时任务2', @task_type_id, '串行，无依赖', 'hour', NULL, @date_serial, @cluster_id, NOW()-INTERVAL 5 HOUR, NOW()-INTERVAL 1 HOUR, @create_user, @create_time ),
( '小时任务3', @task_type_id, '不串行，全周期依赖小时任务', 'hour', NULL, @not_serial, @cluster_id, NOW()-INTERVAL 3 HOUR, NULL, @create_user, @create_time ),
( '小时任务4', @task_type_id, '不串行，最后一个周期依赖小时任务', 'hour', NULL, @not_serial, @cluster_id, NOW()-INTERVAL 3 HOUR, NULL, @create_user, @create_time ),
( '5分钟任务', @task_type_id, '5分钟任务', 'interval', '10', @not_serial, @cluster_id, NOW()-INTERVAL 1 HOUR, NULL, @create_user, @create_time ),
( '30分钟任务', @task_type_id, '30分钟任务', 'interval', '30', @not_serial, @cluster_id, NOW()-INTERVAL 1 HOUR, NULL, @create_user, @create_time ),
( '终极任务1', @task_type_id, '23:59:59执行', 'day', NULL, @not_serial, @cluster_id, CONCAT(CURDATE()-INTERVAL 1 DAY,' ',@the_time), NULL, @create_user, @create_time ),
( '终极任务2', @task_type_id, '23:59:59执行', 'week', @week_num, @not_serial, @cluster_id, CONCAT(CURDATE()-INTERVAL 1 WEEK,' ',@the_time), NULL, @create_user, @create_time ),
( '终极任务3', @task_type_id, '23:59:59执行', 'month', DATE_FORMAT(NOW(), '%d'), @not_serial, @cluster_id, CONCAT(CURDATE()-INTERVAL 1 MONTH,' ',@the_time), NULL, @create_user, @create_time ),
( '终极任务4', @task_type_id, '23:59:59执行', 'hour', NULL, @not_serial, @cluster_id, CONCAT(CURDATE()-INTERVAL 1 DAY,' ',@the_time), NULL, @create_user, @create_time ),
( '终极任务5', @task_type_id, '23:59:59执行', 'interval', '30', @not_serial, @cluster_id, CONCAT(CURDATE()-INTERVAL 1 DAY,' ',@the_time), NULL, @create_user, @create_time );

-- 任务依赖关系
INSERT INTO t_task_link ( task_id, task_pid, link_type, create_user, create_time ) VALUES 
( 3, 1, 0, @create_user, @create_time ),
( 4, 1, 1, @create_user, @create_time ),
( 7, 1, 0, @create_user, @create_time ),
( 8, 1, 1, @create_user, @create_time ),
( 9, 5, 0, @create_user, @create_time ),
( 10, 5, 1, @create_user, @create_time ),
( 13, 1, 0, @create_user, @create_time ),
( 14, 1, 1, @create_user, @create_time ),
( 15, 11, 0, @create_user, @create_time ),
( 16, 11, 1, @create_user, @create_time ),
( 19, 17, 0, @create_user, @create_time ),
( 20, 17, 1, @create_user, @create_time );

-- 任务扩展属性
INSERT INTO t_task_ext (task_id, prop_name, prop_value) VALUES 
(1, 'src_db_id', '3'),
(1, 'src_table_name', 'visitlog'),
(1, 'src_table_type', '0'),
(1, 'src_columns', 'id,androidid,imsi,imei,ip,countrycode,countryname,customid,ostype,apkversioncode,apkversion,model,brand,mac,src,sysversion,sysversioncode,createtime,linktype,sdkversioncode,sdkversion,status,uuid,projectno,lang,opt,firstboottime,lastloadtime,cpu,tdi,apkpkg,tdp,baseversion'),
(1, 'src_time_columns', 'createtime'),
(1, 'page_size', '500'),
(1, 'tar_db_id', '2'),
(1, 'tar_create_mode', 'auto'),
(1, 'tar_load_mode', 'replace');
INSERT INTO t_task_ext (task_id, prop_name, prop_value) VALUES 
(2, 'src_db_id', '4'),
(2, 'src_table_name', 'device'),
(2, 'src_table_type', '0'),
(2, 'src_columns', 'id,mc,me,pn,md,isrepeat,ov,bs,uid,lg,ft,createtime,updatetime,ms,rs,clt,nt,aid,bd,opt,slt,si,vi,tdi,pkg,tdp,pt,originalstatus,changedstatus'),
(2, 'src_time_columns', 'createtime,updatetime'),
(2, 'page_size', '0'),
(2, 'tar_db_id', '2'),
(2, 'tar_create_mode', 'auto'),
(2, 'tar_load_mode', 'replace');
INSERT INTO t_task_ext (task_id, prop_name, prop_value) VALUES 
(3, 'src_db_id', '2'),
(3, 'src_sql', 'SELECT uuid, DATE(createtime), COUNT(1) FROM test.visitlog GROUP BY 1,2;'),
(3, 'tar_db_id', '2'),
(3, 'tar_table_name', 'fact_pv');

-- 启用调度时暂停其他任务
UPDATE t_task SET task_status = 0 WHERE id NOT IN (1, 2, 3);
UPDATE t_task SET type_id = 4 WHERE id = 3;