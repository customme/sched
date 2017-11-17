#!/bin/bash
#
# mysql元数据整理工具


# 元数据库信息
META_DB_HOST=172.17.210.180
META_DB_PORT=3306
META_DB_USER=dc_scheduler_cli
META_DB_PASS=dc_scheduler_cli
META_DB_NAME=dc_scheduler_client
META_DB_CHARSET=utf8

# 要查找的服务器列表(host port user password charset)
SERVERS="172.17.210.180 3306 retail_gms retail_gms utf8
172.17.210.180 3306 retail_pos retail_pos utf8
172.17.210.180 3306 retail_mdm retail_mdm utf8
172.17.210.180 3306 retail_mps retail_mps utf8
172.17.210.180 3306 pms_replenish retail_pms_replenish utf8
172.17.210.180 3306 retail_fms retail_fms utf8"

# 表的最小更新时间(只支持MyISAM引擎,其他引擎UPDATE_TIME总是为NULL)
MIN_UPDATE_TIME=20130101

# 排除的数据库列表
EXCLUDE_DBS="'information_schema','mysql','test','hive'"

# 排除的表名
EXCLUDE_TABLES="'undefined'"
EXCLUDE_TABLES="'coding_rule','sync_state'"

# 排除的表注释
EXCLUDE_TABLE_COMMENTS="废弃"


# 记录日志
function log()
{
    echo "$(date +'%Y-%m-%d %H:%M:%S') INFO [$@]"
}

# 在方法执行前后记录日志
function log_fn()
{
    echo "$(date +'%Y-%m-%d %H:%M:%S') CALL FUNCTION [$@] begin"
    $@ || return $?
    echo "$(date +'%Y-%m-%d %H:%M:%S') CALL FUNCTION [$@] end"
}

# 执行元数据库sql语句
function execute_meta()
{
    local sql="$1"
    if [ -z "$sql" ]; then
        sql=`cat`
    fi

    echo "$sql" | mysql -h$META_DB_HOST -u$META_DB_USER -p$META_DB_PASS -P$META_DB_PORT $META_DB_NAME --default-character-set=$META_DB_CHARSET -s -N --local-infile
}

# 查询源数据
function execute_src()
{
    local sql="$1"
    if [ -z "$sql" ]; then
        sql=`cat`
    fi

    echo "$sql" | mysql -h$src_db_host -u$src_db_user -p$src_db_pass -P$src_db_port $src_db_name --default-character-set=$src_db_charset -s -N
}

# 查找数据库
# Globals:
# Arguments:
# Returns:
function find_dbs()
{
    echo "CREATE TABLE IF NOT EXISTS meta_dbs ( 
        id int(11) AUTO_INCREMENT COMMENT '主键',
        hostname varchar(64) NOT NULL COMMENT '主机名',
        port int(11) NOT NULL COMMENT '端口号',
        username varchar(64) NOT NULL COMMENT '用户名',
        password varchar(64) NOT NULL COMMENT '密码',
        db_name varchar(64) NOT NULL COMMENT '数据库名',
        charset varchar(32) COMMENT '数据库编码',
        PRIMARY KEY (id),
        UNIQUE KEY (hostname,port,db_name) 
    ) COMMENT='数据库';
    " | execute_meta

    echo "SELECT '$src_db_host','$src_db_port','$src_db_user','$src_db_pass',SCHEMA_NAME,DEFAULT_CHARACTER_SET_NAME 
        FROM information_schema.SCHEMATA 
        WHERE SCHEMA_NAME NOT IN ($EXCLUDE_DBS);
    " | execute_src | awk -F '\t' '{
        printf("INSERT INTO meta_dbs (hostname,port,username,password,db_name,charset) VALUES(\"%s\",%s,\"%s\",\"%s\",\"%s\",\"%s\") ON DUPLICATE KEY UPDATE db_name=\"%s\",charset=\"%s\";\n",$1,$2,$3,$4,$5,$6,$5,$6)
    }' | execute_meta
}

# 查找所有表
# 排除包含tmp/temp/bak/back/backup的数据库
# 排除包含tmp/temp/bak/back/backup的表
# 排除列表在$src_db_host:$src_db_port-$src_db_user.ignores
function find_tables()
{
    echo "SELECT TABLE_SCHEMA,TABLE_NAME,TABLE_ROWS,UPDATE_TIME,
        IF(TABLE_COMMENT>'',TABLE_COMMENT,NULL) table_comment 
        FROM information_schema.TABLES 
        WHERE TABLE_TYPE = 'BASE TABLE' 
        AND TABLE_SCHEMA NOT IN ($EXCLUDE_DBS) 
        AND TABLE_NAME NOT IN ($EXCLUDE_TABLES);
        #AND UPDATE_TIME >= $MIN_UPDATE_TIME
    " | execute_src | awk -F"\t" 'BEGIN{
        IGNORECASE=1
    }{
    if($1 !~ /tmp|temp[^a-z]|temp$|bak[^a-z]|bak$|back[^a-z]|back$|backup/ && $2 !~ /tmp|temp[^a-z]|temp$|bak[^a-z]|bak$|back[^a-z]|back$|backup/){
        split($2,arr,"_");
        size=length(arr);
        if(size>1 && arr[size] ~/^[0-9]*$/){
            printf("%s\t%s\t%s\t%s\t%s\n",$1,substr($2,1,index($2,arr[size])-2),$3,$4,$5)
        }else{
            printf("%s\t%s\t%s\t%s\t%s\n",$1,$2,$3,$4,$5)
        }
    }else{
        printf("%s\t%s\t%s\t%s\t%s\n",$1,$2,$3,$4,$5) >> "'$src_db_host:$src_db_port-$src_db_user.ignores'";
    }}' | grep -Ev "$EXCLUDE_TABLE_COMMENTS" > $src_db_host:$src_db_port-$src_db_user.tables

    echo "CREATE TEMPORARY TABLE IF NOT EXISTS tmp_meta_tables(
        db_name varchar(64) NOT NULL COMMENT '数据库名',
        table_name varchar(64) NOT NULL COMMENT '表名',
        table_rows int(11) COMMENT '表数据行数',
        update_time datetime COMMENT '表最后更新时间',
        table_comment varchar(255) COMMENT '表注释'
    );

    LOAD DATA LOCAL INFILE '$src_db_host:$src_db_port-$src_db_user.tables' INTO TABLE tmp_meta_tables;

    CREATE TABLE IF NOT EXISTS meta_tables(
        id int(11) AUTO_INCREMENT COMMENT '主键',
        db_id int(11) NOT NULL COMMENT '数据库ID',
        table_name varchar(64) NOT NULL COMMENT '表名',
        table_rows int COMMENT '表数据行数',
        update_time datetime COMMENT '表最后更新时间',
        table_comment varchar(255) COMMENT '表注释',
        PRIMARY KEY (id),
        UNIQUE KEY (db_id,table_name) 
    ) COMMENT='表';

    REPLACE INTO meta_tables (db_id,table_name,table_rows,update_time,table_comment) 
    SELECT b.id db_id, a.table_name, a.table_rows, a.update_time, a.table_comment
    FROM tmp_meta_tables a 
    INNER JOIN meta_dbs b 
    ON b.hostname = '$src_db_host' 
    AND b.port = '$src_db_port' 
    AND a.db_name = b.db_name;
    " | execute_meta

    # 删除临时文件
    rm -f $src_db_host:$src_db_port-$src_db_user.tables
}

# 查询表定义
function find_columns()
{
    echo "SELECT db_name, table_name 
    FROM meta_tables a 
    INNER JOIN meta_dbs b 
    ON b.hostname= '$src_db_host' 
    AND b.port = $src_db_port 
    AND a.db_id = b.id;
    " | execute_meta | while read db_name table_name; do
        get_columns
    done
}

# 获取表字段
function get_columns()
{
    echo "SELECT COLUMN_NAME,COLUMN_TYPE,ORDINAL_POSITION,IS_NULLABLE,
        IF(COLUMN_KEY>'',COLUMN_KEY,NULL) column_key,
        IF(COLUMN_COMMENT>'',COLUMN_COMMENT,NULL) column_comment 
        FROM information_schema.COLUMNS 
        WHERE TABLE_SCHEMA='$db_name' 
        AND TABLE_NAME='$table_name';
    " | execute_src > $db_name.$table_name.columns

    echo "CREATE TEMPORARY TABLE IF NOT EXISTS tmp_meta_columns( 
        db_name varchar(64) NOT NULL COMMENT '数据库名',
        table_name varchar(64) NOT NULL COMMENT '表名',
        column_name varchar(64) NOT NULL COMMENT '字段名',
        column_type varchar(64) COMMENT '字段类型',
        column_order int(11) COMMENT '字段序号',
        is_nullable varchar(3) COMMENT '是否允许为空',
        column_key varchar(4) COMMENT '键类型',
        column_comment varchar(255) COMMENT '字段注释' 
    );

    LOAD DATA LOCAL INFILE '$db_name.$table_name.columns' INTO TABLE tmp_meta_columns (column_name,column_type,column_order,is_nullable,column_key,column_comment) 
    SET db_name='$db_name',table_name='$table_name';

    CREATE TABLE IF NOT EXISTS meta_columns( 
        id int(11) AUTO_INCREMENT COMMENT '主键',
        table_id int(11) NOT NULL COMMENT '表ID',
        column_name varchar(64) NOT NULL COMMENT '字段名',
        column_type varchar(64) COMMENT '字段类型',
        column_order int(11) COMMENT '字段序号',
        is_nullable varchar(3) COMMENT '是否允许为空',
        column_key varchar(4) COMMENT '键类型',
        column_comment varchar(255) COMMENT '字段注释',
        PRIMARY KEY (id),
        UNIQUE KEY (table_id,column_name) 
    ) COMMENT='字段';

    REPLACE INTO meta_columns (table_id,column_name,column_type,column_order,is_nullable,column_key,column_comment) 
    SELECT b.id, a.column_name, a.column_type, a.column_order, a.is_nullable, a.column_key, a.column_comment 
    FROM tmp_meta_columns a 
    INNER JOIN meta_tables b 
    INNER JOIN meta_dbs c 
    ON c.hostname = '$src_db_host' 
    AND c.port = $src_db_port 
    AND c.db_name = '$db_name' 
    AND b.table_name = '$table_name';
    " | execute_meta

    # 删除临时文件
    rm -f $db_name.$table_name.columns
}

# 读取元数据生成任务配置
# Globals:
# Arguments:
# Returns:
function init_task()
{
    echo "CREATE TABLE IF NOT EXISTS meta_tasks ( 
        id int(11) COMMENT '主键 等于表ID',
        sync_columns text COMMENT '同步字段',
        time_columns text COMMENT '时间字段',
        incr_columns varchar(255) COMMENT '增量字段',
        normal tinyint(4) DEFAULT 0 COMMENT '规范性 0:不规范,1:规范',
        valid tinyint(4) DEFAULT 0 COMMENT '有效性 0:无效,1:有效',
        create_time datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
        PRIMARY KEY (id) 
    ) COMMENT='任务';
    " | execute_meta

    echo "SELECT table_id,column_name,column_type 
    FROM meta_columns 
    ORDER BY table_id,column_order;
    " | execute_meta > meta_columns.tmp

    # 在文件末尾插入一行
    echo "" >> meta_columns.tmp

    # 生成任务配置信息
    # 1. 任务ID，等于表ID
    # 2. 同步字段列表，默认所有字段
    # 3. 时间类型字段
    # 4. 增量字段，满足以下条件之一:
    #   a. 只有一个时间类型字段，且名称为 create_time 或 update_time
    #   b. 至少有两个时间类型字段，且名称同时分别包含 create_time 和 update_time
    # 5. 是否规范，满足以上条件之一为规范
    awk -F '\t' 'BEGIN{OFS=FS}{
        if(prev_id == "" || prev_id == $1){
            # 拼接字段
            sync_columns = sync_columns == "" ? $2 : sync_columns","$2
            # 拼接时间类型字段
            if($3 ~ /^date|^timestamp/) time_columns = time_columns == "" ? $2 : time_columns","$2
        } else { # 打印输出
            # 根据时间类型字段判断是否符合规范
            if(time_columns ~ /^create_time$|^update_time$/){
                incr_columns = time_columns
                normal = 1
            }else if(time_columns ~ /create_time,.*update_time|update_time,.*create_time/){
                incr_columns = "create_time,update_time"
                normal = 1
            }
            print prev_id,sync_columns,time_columns,incr_columns,normal
            time_columns = $3 ~ /^date|^timestamp/ ? $2 : ""
            sync_columns=$2
        }
        prev_id=$1
    }' meta_columns.tmp > meta_tasks.tmp

    # 导入数据
    echo "LOAD DATA LOCAL INFILE 'meta_tasks.tmp' INTO TABLE meta_tasks (id,sync_columns,time_columns,incr_columns,normal) 
    SET valid = 1;
    " | execute_meta

    # 删除临时文件
    rm -f meta_columns.tmp
    rm -f meta_tasks.tmp

    # 更新和mdm库(db_name=retail_mdm)中表名相同的任务为无效(valid=0)
    echo "UPDATE meta_tasks a 
    INNER JOIN meta_tables b 
    INNER JOIN meta_dbs c 
    INNER JOIN meta_tasks d 
    INNER JOIN meta_tables e 
    INNER JOIN meta_dbs f 
    ON a.id = b.id 
    AND b.db_id = c.id 
    AND d.id = e.id 
    AND e.db_id = f.id 
    AND c.db_name = 'retail_mdm' 
    AND f.db_name <> 'retail_mdm' 
    AND b.table_name = e.table_name 
    SET d.valid = 0;
    " | execute_meta
}

# 清理元数据
# Globals:
# Arguments:
# Returns:
function clear_data()
{
    echo "truncate table meta_tasks;
    truncate table meta_columns;
    truncate table meta_tables;
    truncate table meta_dbs;
    " | execute_meta
}

# 查找所有
# Globals:
#   SERVERS
# Arguments:
# Returns:
function find_all()
{
    echo "$SERVERS" | grep -v "#" | while read src_db_host src_db_port src_db_user src_db_pass src_db_charset; do
        log "find in $src_db_host:$src_db_port with user $src_db_user begin"
        log_fn find_dbs
        log_fn find_tables
        log_fn find_columns
        log "find in $src_db_host:$src_db_port with user $src_db_user end"
    done
}

function main()
{
    flag="$1"

    if [ "$flag" = "clear" ]; then
        clear_data
    fi

    find_all

    init_task
}
main "$@"
