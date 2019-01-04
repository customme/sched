-- 测试调度系统插件

SET @CREATE_BY = 'superz';
SET @TASK_GROUP = '测试 - 调度系统插件';
SET @TASK_STATUS = 1;
SET @TASK_CYCLE = 'instant';
SET @CLUSTER_ID = 2;
SET @SERVER_ID = 3;
SET @TASK_STATE = 0;

INSERT INTO `t_db_conn` (`create_by`, `create_date`, `db_name`, `type_id`, `username`, `password`, `hostname`, `port`, `charset`) VALUES 
(@CREATE_BY, NOW(), 'ad_dw', 1, 'root', 'mysql', '10.10.10.64', 3306, 'utf8');

INSERT INTO `t_db_conn` (`create_by`, `create_date`, `db_name`, `type_id`, `username`, `password`, `hostname`, `port`, `charset`) VALUES 
(@CREATE_BY, NOW(), 'ad_dw1', 1, 'root', 'mysql', '10.10.10.64', 3306, 'utf8');
SET @ad_db_id1=(SELECT @@IDENTITY);

INSERT INTO `t_db_conn` (`create_by`, `create_date`, `db_name`, `type_id`, `username`, `password`, `hostname`, `port`, `charset`) VALUES 
(@CREATE_BY, NOW(), 'ad_dw2', 1, 'root', 'mysql', '10.10.10.64', 3306, 'utf8');
SET @ad_db_id2=(SELECT @@IDENTITY);

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '空任务', @TASK_GROUP, 1, @TASK_STATUS, @TASK_CYCLE, 1, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO t_task_pool (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), 1);

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成Android ID', @TASK_GROUP, 18, @TASK_STATUS, @TASK_CYCLE, @CLUSTER_ID, @SERVER_ID, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'data_type', 'aid');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE, 'number=5000000');

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成新增用户 - adv_n', @TASK_GROUP, 18, @TASK_STATUS, @TASK_CYCLE, @CLUSTER_ID, @SERVER_ID, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'data_type', 'new'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE, 'start_date=2016-03-02\r\nend_date=2016-03-31');

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成活跃用户 - adv_n', @TASK_GROUP, 18, @TASK_STATUS, @TASK_CYCLE, @CLUSTER_ID, @SERVER_ID, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'data_type', 'active'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE, 'start_date=2016-03-02\r\nend_date=2016-03-31\r\nrand0=328\r\nrate0=80+30');

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成访问日志 - adv_n', @TASK_GROUP, 18, @TASK_STATUS, @TASK_CYCLE, @CLUSTER_ID, @SERVER_ID, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'data_type', 'visit'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE, 'start_date=2016-03-02\r\nend_date=2016-03-31');

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '访问日志转换成json格式并发送到kafka - adv_n', @TASK_GROUP, 19, @TASK_STATUS, @TASK_CYCLE, @CLUSTER_ID, @SERVER_ID, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'fields', 'aid,channel_code,area,ip,create_time'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE, 'start_date=2016-03-02\r\nend_date=2016-03-31');

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), 'flume消费kafka里的访问日志', @TASK_GROUP, 17, @TASK_STATUS, 'incessant', @CLUSTER_ID, @SERVER_ID, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'agent_conf', '$ETL_HOME/ad/kafka2flume.conf'),
(@CREATE_BY, NOW(), @task_id, 'agent_name', 'ad');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE);

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `server_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), 'flume接收访问日志并写入hdfs', @TASK_GROUP, 17, @TASK_STATUS, 'incessant', @CLUSTER_ID, 4, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'agent_conf', '$ETL_HOME/ad/flume2hdfs.conf'),
(@CREATE_BY, NOW(), @task_id, 'agent_name', 'ad');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE);

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '解析访问日志得到新增用户 - adv_n', @TASK_GROUP, 16, @TASK_STATUS, @TASK_CYCLE, @CLUSTER_ID, NOW());
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
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE, CONCAT('start_date=', CURDATE()));

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '解析访问日志得到活跃用户 - adv_n', @TASK_GROUP, 16, @TASK_STATUS, @TASK_CYCLE, @CLUSTER_ID, NOW());
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
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE, CONCAT('start_date=', CURDATE()));

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成新增用户聚合表 - adv_n', @TASK_GROUP, 16, @TASK_STATUS, @TASK_CYCLE, @CLUSTER_ID, NOW());
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
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE);

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成活跃用户聚合表 - adv_n', @TASK_GROUP, 16, @TASK_STATUS, @TASK_CYCLE, @CLUSTER_ID, NOW());
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
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE);

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '解析访问日志得到新增用户 - adv_n', @TASK_GROUP, 2, @TASK_STATUS, @TASK_CYCLE, 1, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'tar_cmd', 'source $ETL_HOME/ad/fact_new.sh'),
(@CREATE_BY, NOW(), @task_id, 'hdfs_dir', '/flume/ad'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id2);
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE, CONCAT('start_date=', CURDATE()));

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '解析访问日志得到活跃用户 - adv_n', @TASK_GROUP, 2, @TASK_STATUS, @TASK_CYCLE, 1, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'tar_cmd', 'source $ETL_HOME/ad/fact_active.sh'),
(@CREATE_BY, NOW(), @task_id, 'hdfs_dir', '/flume/ad'),
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id2);
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`, `run_params`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE, CONCAT('start_date=', CURDATE()));

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成新增用户聚合表 - adv_n', @TASK_GROUP, 2, @TASK_STATUS, @TASK_CYCLE, 1, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id2),
(@CREATE_BY, NOW(), @task_id, 'agg_columns', 'create_date,channel_code,area'),
(@CREATE_BY, NOW(), @task_id, 'key_column', 'aid');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE);

INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '生成活跃用户聚合表 - adv_n', @TASK_GROUP, 2, @TASK_STATUS, @TASK_CYCLE, 1, NOW());
SET @task_id=(SELECT @@IDENTITY);
INSERT INTO `t_task_ext` (`create_by`, `create_date`, `task_id`, `prop_name`, `prop_value`) VALUES 
(@CREATE_BY, NOW(), @task_id, 'product_code', 'adv_n'),
(@CREATE_BY, NOW(), @task_id, 'ad_db_id', @ad_db_id2),
(@CREATE_BY, NOW(), @task_id, 'agg_columns', 'create_date,channel_code,area'),
(@CREATE_BY, NOW(), @task_id, 'must_columns', 'active_date,create_date,date_diff'),
(@CREATE_BY, NOW(), @task_id, 'key_column', 'aid');
INSERT INTO `t_task_pool` (`create_by`, `create_date`, `task_id`, `run_time`, `task_state`) VALUES 
(@CREATE_BY, NOW(), @task_id, NOW(), @TASK_STATE);
