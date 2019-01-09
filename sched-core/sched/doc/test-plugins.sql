-- 测试调度系统插件

SET @CREATE_BY = 'superz';

SET @DB_TYPE = 1;
SET @DB_HOST = '10.10.10.64';
SET @DB_PORT = 3306;
SET @DB_USER = 'root';
SET @DB_PASSWD = 'mysql';
SET @DB_CHARSET = 'utf8';

SET @SERVER_1 = 3;
SET @SERVER_2 = 4;

SET @TASK_GROUP = '测试 - 调度系统插件';
SET @TASK_STATUS = 1;

SET @TASK_TYPE_DUMMY = 1;
SET @TASK_TYPE_SHELL = 2;
SET @TASK_TYPE_SPARK = 16;
SET @TASK_TYPE_FLUME = 17;
SET @TASK_TYPE_DATA_GEN = 18;
SET @TASK_TYPE_SEND_KAFKA = 19;

SET @TASK_CYCLE_INSTANT = 'instant';
SET @TASK_CYCLE_INCESSANT = 'incessant';

SET @CLUSTER_SCHED = 1;
SET @CLUSTER_HADOOP = 2;

SET @TASK_STATE_INITIAL = 0;
SET @TASK_STATE_READY = 1;

-- 数据库连接
INSERT INTO `t_db_conn` (`create_by`, `create_date`, `db_name`, `type_id`, `username`, `password`, `hostname`, `port`, `charset`) VALUES 
(@CREATE_BY, NOW(), 'ad_dw', @DB_TYPE, @DB_USER, @DB_PASSWD, @DB_HOST, @DB_PORT, @DB_CHARSET);

INSERT INTO `t_db_conn` (`create_by`, `create_date`, `db_name`, `type_id`, `username`, `password`, `hostname`, `port`, `charset`) VALUES 
(@CREATE_BY, NOW(), 'ad_dw1', @DB_TYPE, @DB_USER, @DB_PASSWD, @DB_HOST, @DB_PORT, @DB_CHARSET);
SET @ad_db_id1=(SELECT @@IDENTITY);

INSERT INTO `t_db_conn` (`create_by`, `create_date`, `db_name`, `type_id`, `username`, `password`, `hostname`, `port`, `charset`) VALUES 
(@CREATE_BY, NOW(), 'ad_dw2', @DB_TYPE, @DB_USER, @DB_PASSWD, @DB_HOST, @DB_PORT, @DB_CHARSET);
SET @ad_db_id2=(SELECT @@IDENTITY);

-- 任务/任务扩展属性/任务实例
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '空任务', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_SCHED, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO t_task_pool (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_READY);

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成Android ID', @TASK_GROUP, @TASK_TYPE_DATA_GEN, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_HADOOP, @SERVER_1, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'data_type', 'aid');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL, 'number=1000000');

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成新增用户 - adv_n', @TASK_GROUP, @TASK_TYPE_DATA_GEN, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_HADOOP, @SERVER_1, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'data_type', 'new'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL, 'start_date=2016-03-02\r\nend_date=2016-03-31');

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成新增用户 - recorder_n', @TASK_GROUP, @TASK_TYPE_DATA_GEN, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_HADOOP, @SERVER_1, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'data_type', 'new'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'recorder_n');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL, 'start_date=2016-03-04\r\nend_date=2016-03-31');

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成活跃用户 - adv_n', @TASK_GROUP, @TASK_TYPE_DATA_GEN, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_HADOOP, @SERVER_1, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'data_type', 'active'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL, 'start_date=2016-03-02\r\nend_date=2016-03-31\r\nrand0=328\r\nrate0=80+30');

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成活跃用户 - recorder_n', @TASK_GROUP, @TASK_TYPE_DATA_GEN, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_HADOOP, @SERVER_1, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'data_type', 'active'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'recorder_n');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL, 'start_date=2016-03-04\r\nend_date=2016-03-31\r\nrand0=318\r\nrate0=80+30');

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成访问日志 - adv_n', @TASK_GROUP, @TASK_TYPE_DATA_GEN, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_HADOOP, @SERVER_1, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'data_type', 'visit'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL, 'start_date=2016-03-02\r\nend_date=2016-03-31');

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成访问日志 - recorder_n', @TASK_GROUP, @TASK_TYPE_DATA_GEN, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_HADOOP, @SERVER_1, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'data_type', 'visit'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'recorder_n');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL, 'start_date=2016-03-04\r\nend_date=2016-03-31');

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成广告展示、点击、激活日志', @TASK_GROUP, @TASK_TYPE_DATA_GEN, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_HADOOP, @SERVER_1, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'data_type', 'ad');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL, 'start_date=2016-03-02\r\nend_date=2016-03-31');

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '访问日志转换成json格式并发送到kafka - adv_n', @TASK_GROUP, @TASK_TYPE_SEND_KAFKA, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_HADOOP, @SERVER_1, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'fields', 'aid,channel_code,area,ip,create_time'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL, 'start_date=2016-03-02\r\nend_date=2016-03-31');

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '访问日志转换成json格式并发送到kafka - recorder_n', @TASK_GROUP, @TASK_TYPE_SEND_KAFKA, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_HADOOP, @SERVER_1, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'fields', 'aid,channel_code,area,ip,create_time'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'recorder_n');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL, 'start_date=2016-03-04\r\nend_date=2016-03-31');

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), 'flume消费kafka里的访问日志', @TASK_GROUP, @TASK_TYPE_FLUME, @TASK_STATUS, @TASK_CYCLE_INCESSANT, @CLUSTER_HADOOP, @SERVER_1, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'agent_conf', '$ETL_HOME/ad/kafka2flume.conf'),
(@CREATE_BY, NOW(), @task_id, 'agent_name', 'ad');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL);

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), 'flume接收访问日志并写入hdfs', @TASK_GROUP, @TASK_TYPE_FLUME, @TASK_STATUS, @TASK_CYCLE_INCESSANT, @CLUSTER_HADOOP, @SERVER_2, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'agent_conf', '$ETL_HOME/ad/flume2hdfs.conf'),
(@CREATE_BY, NOW(), @task_id, 'agent_name', 'ad');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL);

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '解析访问日志得到新增用户 - adv_n', @TASK_GROUP, @TASK_TYPE_SPARK, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_HADOOP, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'app_class', 'com.jiuzhi.etl.ad.FactNew'),
(@CREATE_BY, NOW(), @task_id, 'app_jar', '/usr/local/etl/ad/etl-ad-0.0.1.jar'),
(@CREATE_BY, NOW(), @task_id, 'executor_classpath', '/usr/hive/current/lib/mysql-connector-java-commercial-5.1.25-bin.jar'),
(@CREATE_BY, NOW(), @task_id, 'master_url', 'spark://yygz-61.gzserv.com:7077,yygz-64.gzserv.com:7077'),
(@CREATE_BY, NOW(), @task_id, 'hdfs_dir', 'hdfs://dfs-study/flume/ad'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id1);
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL, CONCAT('start_date=', CURDATE()));

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '解析访问日志得到新增用户 - recorder_n', @TASK_GROUP, @TASK_TYPE_SPARK, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_HADOOP, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'app_class', 'com.jiuzhi.etl.ad.FactNew'),
(@CREATE_BY, NOW(), @task_id, 'app_jar', '/usr/local/etl/ad/etl-ad-0.0.1.jar'),
(@CREATE_BY, NOW(), @task_id, 'executor_classpath', '/usr/hive/current/lib/mysql-connector-java-commercial-5.1.25-bin.jar'),
(@CREATE_BY, NOW(), @task_id, 'master_url', 'spark://yygz-61.gzserv.com:7077,yygz-64.gzserv.com:7077'),
(@CREATE_BY, NOW(), @task_id, 'hdfs_dir', 'hdfs://dfs-study/flume/ad'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'recorder_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id1);
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL, CONCAT('start_date=', CURDATE()));

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '解析访问日志得到活跃用户 - adv_n', @TASK_GROUP, @TASK_TYPE_SPARK, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_HADOOP, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'app_class', 'com.jiuzhi.etl.ad.FactActive'),
(@CREATE_BY, NOW(), @task_id, 'app_jar', '/usr/local/etl/ad/etl-ad-0.0.1.jar'),
(@CREATE_BY, NOW(), @task_id, 'executor_classpath', '/usr/hive/current/lib/mysql-connector-java-commercial-5.1.25-bin.jar'),
(@CREATE_BY, NOW(), @task_id, 'master_url', 'spark://yygz-61.gzserv.com:7077,yygz-64.gzserv.com:7077'),
(@CREATE_BY, NOW(), @task_id, 'hdfs_dir', 'hdfs://dfs-study/flume/ad'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id1);
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL, CONCAT('start_date=', CURDATE()));

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '解析访问日志得到活跃用户 - recorder_n', @TASK_GROUP, @TASK_TYPE_SPARK, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_HADOOP, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'app_class', 'com.jiuzhi.etl.ad.FactActive'),
(@CREATE_BY, NOW(), @task_id, 'app_jar', '/usr/local/etl/ad/etl-ad-0.0.1.jar'),
(@CREATE_BY, NOW(), @task_id, 'executor_classpath', '/usr/hive/current/lib/mysql-connector-java-commercial-5.1.25-bin.jar'),
(@CREATE_BY, NOW(), @task_id, 'master_url', 'spark://yygz-61.gzserv.com:7077,yygz-64.gzserv.com:7077'),
(@CREATE_BY, NOW(), @task_id, 'hdfs_dir', 'hdfs://dfs-study/flume/ad'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'recorder_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id1);
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL, CONCAT('start_date=', CURDATE()));

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成新增用户聚合表 - adv_n', @TASK_GROUP, @TASK_TYPE_SPARK, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_HADOOP, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'app_class', 'com.jiuzhi.etl.ad.AggNew'),
(@CREATE_BY, NOW(), @task_id, 'app_jar', '/usr/local/etl/ad/etl-ad-0.0.1.jar'),
(@CREATE_BY, NOW(), @task_id, 'executor_classpath', '/usr/hive/current/lib/mysql-connector-java-commercial-5.1.25-bin.jar'),
(@CREATE_BY, NOW(), @task_id, 'master_url', 'spark://yygz-61.gzserv.com:7077,yygz-64.gzserv.com:7077'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id1),
(@CREATE_BY, NOW(), @task_id, 'agg_columns', 'create_date,channel_code,area'),
(@CREATE_BY, NOW(), @task_id, 'key_column', 'aid');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL);
UPDATE t_task a INNER JOIN t_task_pool b ON a.id = b.task_id AND a.id = @task_id SET a.first_time = b.run_time;

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成新增用户聚合表 - recorder_n', @TASK_GROUP, @TASK_TYPE_SPARK, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_HADOOP, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'app_class', 'com.jiuzhi.etl.ad.AggNew'),
(@CREATE_BY, NOW(), @task_id, 'app_jar', '/usr/local/etl/ad/etl-ad-0.0.1.jar'),
(@CREATE_BY, NOW(), @task_id, 'executor_classpath', '/usr/hive/current/lib/mysql-connector-java-commercial-5.1.25-bin.jar'),
(@CREATE_BY, NOW(), @task_id, 'master_url', 'spark://yygz-61.gzserv.com:7077,yygz-64.gzserv.com:7077'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'recorder_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id1),
(@CREATE_BY, NOW(), @task_id, 'agg_columns', 'create_date,channel_code,area'),
(@CREATE_BY, NOW(), @task_id, 'key_column', 'aid');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL);
UPDATE t_task a INNER JOIN t_task_pool b ON a.id = b.task_id AND a.id = @task_id SET a.first_time = b.run_time;

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成活跃用户聚合表 - adv_n', @TASK_GROUP, @TASK_TYPE_SPARK, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_HADOOP, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'app_class', 'com.jiuzhi.etl.ad.AggActive'),
(@CREATE_BY, NOW(), @task_id, 'app_jar', '/usr/local/etl/ad/etl-ad-0.0.1.jar'),
(@CREATE_BY, NOW(), @task_id, 'executor_classpath', '/usr/hive/current/lib/mysql-connector-java-commercial-5.1.25-bin.jar'),
(@CREATE_BY, NOW(), @task_id, 'master_url', 'spark://yygz-61.gzserv.com:7077,yygz-64.gzserv.com:7077'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id1),
(@CREATE_BY, NOW(), @task_id, 'agg_columns', 'channel_code,area'),
(@CREATE_BY, NOW(), @task_id, 'must_columns', 'active_date,create_date,date_diff'),
(@CREATE_BY, NOW(), @task_id, 'key_column', 'aid');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL);
UPDATE t_task a INNER JOIN t_task_pool b ON a.id = b.task_id AND a.id = @task_id SET a.first_time = b.run_time;

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成活跃用户聚合表 - recorder_n', @TASK_GROUP, @TASK_TYPE_SPARK, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_HADOOP, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'app_class', 'com.jiuzhi.etl.ad.AggActive'),
(@CREATE_BY, NOW(), @task_id, 'app_jar', '/usr/local/etl/ad/etl-ad-0.0.1.jar'),
(@CREATE_BY, NOW(), @task_id, 'executor_classpath', '/usr/hive/current/lib/mysql-connector-java-commercial-5.1.25-bin.jar'),
(@CREATE_BY, NOW(), @task_id, 'master_url', 'spark://yygz-61.gzserv.com:7077,yygz-64.gzserv.com:7077'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'recorder_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id1),
(@CREATE_BY, NOW(), @task_id, 'agg_columns', 'channel_code,area'),
(@CREATE_BY, NOW(), @task_id, 'must_columns', 'active_date,create_date,date_diff'),
(@CREATE_BY, NOW(), @task_id, 'key_column', 'aid');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL);
UPDATE t_task a INNER JOIN t_task_pool b ON a.id = b.task_id AND a.id = @task_id SET a.first_time = b.run_time;

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '解析访问日志得到新增用户 - adv_n', @TASK_GROUP, @TASK_TYPE_SHELL, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_SCHED, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'tar_cmd', 'source $ETL_HOME/ad/fact_new.sh'),
(@CREATE_BY, NOW(), @task_id, 'hdfs_dir', '/flume/ad'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id2);
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL, CONCAT('start_date=', CURDATE()));

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '解析访问日志得到新增用户 - recorder_n', @TASK_GROUP, @TASK_TYPE_SHELL, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_SCHED, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'tar_cmd', 'source $ETL_HOME/ad/fact_new.sh'),
(@CREATE_BY, NOW(), @task_id, 'hdfs_dir', '/flume/ad'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'recorder_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id2);
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL, CONCAT('start_date=', CURDATE()));

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '解析访问日志得到活跃用户 - adv_n', @TASK_GROUP, @TASK_TYPE_SHELL, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_SCHED, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'tar_cmd', 'source $ETL_HOME/ad/fact_active.sh'),
(@CREATE_BY, NOW(), @task_id, 'hdfs_dir', '/flume/ad'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id2);
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL, CONCAT('start_date=', CURDATE()));

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '解析访问日志得到活跃用户 - recorder_n', @TASK_GROUP, @TASK_TYPE_SHELL, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_SCHED, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'tar_cmd', 'source $ETL_HOME/ad/fact_active.sh'),
(@CREATE_BY, NOW(), @task_id, 'hdfs_dir', '/flume/ad'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'recorder_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id2);
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL, CONCAT('start_date=', CURDATE()));

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成新增用户聚合表 - adv_n', @TASK_GROUP, @TASK_TYPE_SHELL, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_SCHED, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'tar_cmd', 'source $ETL_HOME/ad/agg_new.sh'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id2);
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL);
UPDATE t_task a INNER JOIN t_task_pool b ON a.id = b.task_id AND a.id = @task_id SET a.first_time = b.run_time;

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成新增用户聚合表 - recorder_n', @TASK_GROUP, @TASK_TYPE_SHELL, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_SCHED, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'tar_cmd', 'source $ETL_HOME/ad/agg_new.sh'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'recorder_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id2);
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL);
UPDATE t_task a INNER JOIN t_task_pool b ON a.id = b.task_id AND a.id = @task_id SET a.first_time = b.run_time;

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成活跃用户聚合表 - adv_n', @TASK_GROUP, @TASK_TYPE_SHELL, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_SCHED, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'tar_cmd', 'source $ETL_HOME/ad/agg_active.sh'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id2);
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL);
UPDATE t_task a INNER JOIN t_task_pool b ON a.id = b.task_id AND a.id = @task_id SET a.first_time = b.run_time;

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成活跃用户聚合表 - recorder_n', @TASK_GROUP, @TASK_TYPE_SHELL, @TASK_STATUS, @TASK_CYCLE_INSTANT, @CLUSTER_SCHED, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'tar_cmd', 'source $ETL_HOME/ad/agg_active.sh'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'recorder_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id2);
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE_INITIAL);
UPDATE t_task a INNER JOIN t_task_pool b ON a.id = b.task_id AND a.id = @task_id SET a.first_time = b.run_time;
