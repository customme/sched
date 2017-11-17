create table if not exists t_db_type(
    id int comment '数据库类型ID',
    code varchar(64) comment '数据库类型代码',
    description varchar(255) comment '描述',
    primary key(id)
) comment '数据库类型';
insert into t_db_type values ('1', 'MYSQL', 'MySQL');
insert into t_db_type values ('2', 'ORACLE', 'Oracle');
insert into t_db_type values ('3', 'MSSQL', 'MS SQL Server');
insert into t_db_type values ('4', 'SYBASE', 'Sybase');
insert into t_db_type values ('5', 'POSTGRESQL', 'PostgreSQL');
insert into t_db_type values ('6', 'DB2', 'IBM DB2');
insert into t_db_type values ('7', 'HIVE', 'Hadoop Hive');
insert into t_db_type values ('8', 'DERBY', 'Apache Derby');
insert into t_db_type values ('9', 'FS', 'Local File System');
insert into t_db_type values ('10', 'HDFS', 'Hadoop Distributed File System');

create table if not exists t_db_con_type(
    id int comment '数据库连接类型ID',
    code varchar(32) comment '数据库连接类型代码',
    description varchar(255) comment '描述',
    primary key(id)
) comment '数据库连接类型';
insert into t_db_con_type values ('1', 'JDBC', 'Java Database Connectivity');
insert into t_db_con_type values ('2', 'ODBC', 'Open Database Connectivity');
insert into t_db_con_type values ('3', 'CLI', 'Command Line Interface');

create table if not exists t_database(
    id int auto_increment comment '数据库连接ID',
    name varchar(64) comment '数据库连接名',
    db_name varchar(64) comment '数据库名',
    type_id int not null comment '数据库类型ID',
    con_type_id int comment '数据库连接类型ID',
    username varchar(64) comment '数据库连接用户名',
    password varchar(128) comment '数据库连接密码',
    host_name varchar(64) comment '主机名',
    port int comment '数据库端口号',
    charset varchar(32) comment '数据库编码',
    description varchar(255) comment '描述',
    create_user varchar(64) comment '创建者',
    create_time datetime comment '创建时间',
    update_user varchar(64) comment '更新者',
    update_time datetime comment '更新时间',
    primary key(id)
) comment '数据库连接信息';
insert into t_database values ('1', null, 'dc_retail_gms', '7', '1', null, null, '172.17.210.120', null, 'utf8', null, null, null, null, null);
insert into t_database values ('2', null, 'dc_retail_pos', '7', '1', null, null, '172.17.210.120', null, 'utf8', null, null, null, null, null);
insert into t_database values ('3', null, 'dc_retail_mdm', '7', '1', null, null, '172.17.210.120', null, 'utf8', null, null, null, null, null);
insert into t_database values ('4', null, 'retail_gms', '1', '1', 'retail_gms', 'retail_gms', '172.17.210.180', '3306', 'utf8', null, null, null, null, null);
insert into t_database values ('5', null, 'retail_pos', '1', '1', 'retail_pos', 'retail_pos', '172.17.210.180', '3306', 'utf8', null, null, null, null, null);
insert into t_database values ('6', null, 'retail_mdm', '1', '1', 'retail_mdm', 'retail_mdm', '172.17.210.180', '3306', 'utf8', null, null, null, null, null);
insert into t_database values ('7', null, 'test', '1', '1', 'etl', '123456', '172.17.206.35', '3306', 'utf8', null, null, null, null, null);
insert into t_database values ('8', null, 'orcl', '2', '1', 'usr_ho_scheduler_new', 'usr_ho_scheduler_new01', '172.17.210.34', '1521', 'utf8', null, null, null, null, null);
insert into t_database values ('9', null, 'test', '4', '1', 'test', 'belle@014', '172.17.17.237', '51000', 'gbk', null, null, null, null, null);
insert into t_database values ('10', null, '/root/data/retail', '9', null, null, null, null, null, null, null, null, null, null, null);
insert into t_database values ('11', null, null, '9', null, null, null, null, null, null, null, null, null, null, null);

create table if not exists t_task(
    id int auto_increment comment '任务ID',
    name varchar(64) comment '任务名称',
    table_name varchar(64) comment '表名',
    src_db_id int comment '源数据库ID',
    tar_db_id int comment '目标数据库ID',
    split_column varchar(64) comment '任务拆分字段',
    sync_columns text comment '同步字段',
    incr_columns varchar(255) comment '增量字段',
    query_sql text COMMENT '自定义sql',
    sync_freq bigint comment '同步频率',
    begin_time datetime comment '同步开始时间',
    status tinyint comment '任务状态 0-初始状态 1-运行中 2-暂停 6-执行成功 9-执行失败',
    valid tinyint comment '任务是否有效 0-无效 1-有效',
    create_time datetime comment '任务创建时间',
    primary key(id)
) comment '任务信息';