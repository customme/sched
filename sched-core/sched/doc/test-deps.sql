-- 测试调度系统任务依赖

SET @CREATE_BY = 'superz';
SET @TASK_GROUP = '测试 - 调度系统任务依赖';
SET @TASK_STATUS = 1;
SET @DATE_SERIAL = 1;
SET @TASK_TYPE_DUMMY = 1;
SET @TASK_CYCLE_DAY = 'day';
SET @TASK_CYCLE_WEEK = 'week';
SET @TASK_CYCLE_MONTH = 'month';
SET @TASK_CYCLE_HOUR = 'hour';
SET @LINK_TYPE_LAST = 0;
SET @LINK_TYPE_FULL = 1;
SET @LINK_TYPE_ANY = 2;
SET @CLUSTER_SCHED = 1;

SET @PREV_DAY = NOW() - INTERVAL 1 DAY;
SET @PREV_WEEK = NOW() - INTERVAL 1 WEEK;
SET @PREV_MONTH = NOW() - INTERVAL 1 MONTH;
SET @PREV_HOUR = NOW() - INTERVAL 1 HOUR;
SET @CUR_WEEK = WEEKDAY(CURDATE()) + 1;
SET @CUR_DAY = DAY(CURDATE());

SET @TASK_MAXIMUM = 30;

-- 自身依赖
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `date_serial`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '自身依赖 - 天', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_DAY, @DATE_SERIAL, @CLUSTER_SCHED, @PREV_DAY);
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cycle_value`, `date_serial`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '自身依赖 - 周', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_WEEK, @CUR_WEEK, @DATE_SERIAL, @CLUSTER_SCHED, @PREV_WEEK);
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cycle_value`, `date_serial`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '自身依赖 - 月', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_MONTH, @CUR_DAY, @DATE_SERIAL, @CLUSTER_SCHED, @PREV_MONTH);
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `date_serial`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '自身依赖 - 小时', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_HOUR, @DATE_SERIAL, @CLUSTER_SCHED, @PREV_HOUR);

-- 最后一个周期依赖
-- 天A -> 天B,小时C
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '最后一个周期依赖 - 天依赖 - 天A', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_DAY, @CLUSTER_SCHED, NOW());
SET @task_id1=(SELECT @@IDENTITY);
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '最后一个周期依赖 - 天依赖 - 天B', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_DAY, @CLUSTER_SCHED, NOW());
SET @task_id2=(SELECT @@IDENTITY);
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '最后一个周期依赖 - 天依赖 - 小时C', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_HOUR, @CLUSTER_SCHED, @PREV_DAY);
SET @task_id3=(SELECT @@IDENTITY);
INSERT INTO t_task_link (`create_by`, `create_date`, `task_id`, `task_pid`, `link_type`) VALUES 
(@CREATE_BY, NOW(), @task_id1, @task_id2, @LINK_TYPE_LAST),
(@CREATE_BY, NOW(), @task_id1, @task_id3, @LINK_TYPE_LAST);

-- 周A -> 天B,周C
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cycle_value`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '最后一个周期依赖 - 周依赖 - 周A', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_WEEK, @CUR_WEEK, @CLUSTER_SCHED, NOW());
SET @task_id1=(SELECT @@IDENTITY);
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '最后一个周期依赖 - 周依赖 - 天B', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_DAY, @CLUSTER_SCHED, NOW());
SET @task_id2=(SELECT @@IDENTITY);
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cycle_value`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '最后一个周期依赖 - 周依赖 - 周C', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_WEEK, @CUR_WEEK, @CLUSTER_SCHED, NOW());
SET @task_id3=(SELECT @@IDENTITY);
INSERT INTO t_task_link (`create_by`, `create_date`, `task_id`, `task_pid`, `link_type`) VALUES 
(@CREATE_BY, NOW(), @task_id1, @task_id2, @LINK_TYPE_LAST),
(@CREATE_BY, NOW(), @task_id1, @task_id3, @LINK_TYPE_LAST);

-- 月A -> 天B,月C
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cycle_value`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '最后一个周期依赖 - 月依赖 - 月A', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_MONTH, @CUR_DAY, @CLUSTER_SCHED, NOW());
SET @task_id1=(SELECT @@IDENTITY);
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '最后一个周期依赖 - 月依赖 - 天B', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_DAY, @CLUSTER_SCHED, NOW());
SET @task_id2=(SELECT @@IDENTITY);
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cycle_value`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '最后一个周期依赖 - 月依赖 - 月C', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_MONTH, @CUR_DAY, @CLUSTER_SCHED, NOW());
SET @task_id3=(SELECT @@IDENTITY);
INSERT INTO t_task_link (`create_by`, `create_date`, `task_id`, `task_pid`, `link_type`) VALUES 
(@CREATE_BY, NOW(), @task_id1, @task_id2, @LINK_TYPE_LAST),
(@CREATE_BY, NOW(), @task_id1, @task_id3, @LINK_TYPE_LAST);

-- 小时A -> 小时B
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '最后一个周期依赖 - 小时依赖 - 小时A', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_HOUR, @CLUSTER_SCHED, NOW());
SET @task_id1=(SELECT @@IDENTITY);
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '最后一个周期依赖 - 小时依赖 - 小时B', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_HOUR, @CLUSTER_SCHED, NOW());
SET @task_id2=(SELECT @@IDENTITY);
INSERT INTO t_task_link (`create_by`, `create_date`, `task_id`, `task_pid`, `link_type`) VALUES 
(@CREATE_BY, NOW(), @task_id1, @task_id2, @LINK_TYPE_LAST);

-- 全周期依赖
-- 天A -> 小时B
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '全周期依赖 - 天依赖 - 天A', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_DAY, @CLUSTER_SCHED, NOW());
SET @task_id1=(SELECT @@IDENTITY);
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '全周期依赖 - 天依赖 - 小时B', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_HOUR, @CLUSTER_SCHED, @PREV_DAY);
SET @task_id2=(SELECT @@IDENTITY);
INSERT INTO t_task_link (`create_by`, `create_date`, `task_id`, `task_pid`, `link_type`) VALUES 
(@CREATE_BY, NOW(), @task_id1, @task_id2, @LINK_TYPE_FULL);

-- 周A -> 天B
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cycle_value`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '全周期依赖 - 周依赖 - 周A', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_WEEK, @CUR_WEEK, @CLUSTER_SCHED, NOW());
SET @task_id1=(SELECT @@IDENTITY);
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '全周期依赖 - 周依赖 - 天B', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_DAY, @CLUSTER_SCHED, @PREV_WEEK);
SET @task_id2=(SELECT @@IDENTITY);
INSERT INTO t_task_link (`create_by`, `create_date`, `task_id`, `task_pid`, `link_type`) VALUES 
(@CREATE_BY, NOW(), @task_id1, @task_id2, @LINK_TYPE_LAST);

-- 月A -> 天B
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cycle_value`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '全周期依赖 - 月依赖 - 月A', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_MONTH, @CUR_DAY, @CLUSTER_SCHED, NOW());
SET @task_id1=(SELECT @@IDENTITY);
INSERT INTO `t_task` (`create_by`, `create_date`, `name`, `task_group`, `type_id`, `task_status`, `task_cycle`, `cluster_id`, `start_time`) VALUES 
(@CREATE_BY, NOW(), '全周期依赖 - 月依赖 - 天B', @TASK_GROUP, @TASK_TYPE_DUMMY, @TASK_STATUS, @TASK_CYCLE_DAY, @CLUSTER_SCHED, @PREV_MONTH);
SET @task_id2=(SELECT @@IDENTITY);
INSERT INTO t_task_link (`create_by`, `create_date`, `task_id`, `task_pid`, `link_type`) VALUES 
(@CREATE_BY, NOW(), @task_id1, @task_id2, @LINK_TYPE_LAST);

-- 更新任务最大并发数
UPDATE `t_server` SET task_maximum = @TASK_MAXIMUM WHERE cluster_id = @CLUSTER_SCHED;
