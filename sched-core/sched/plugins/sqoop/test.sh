#!/bin/bash
#
# sqoop测试


DIR=`pwd`

source $DIR/config.sh
source $DIR/common.sh
source $DIR/task_config.sh
source $DIR/task_common.sh


#创建目录
mkdir -p $SQL_LOG_DIR 2> /dev/null
mkdir -p $TMP_DIR 2> /dev/null


# 准备数据
# Globals:
# Arguments:
# Returns:
function init_data()
{
    # 数据库
    echo "truncate table t_database;
    insert into t_database(db_name,type_id,con_type_id,username,password,hostname,port,charset) values 
    ('retail_gms',1,1,'retail_gms','retail_gms','172.17.210.180',3306,'utf8'),
    ('retail_pos',1,1,'retail_pos','retail_pos','172.17.210.180',3306,'utf8'),
    ('retail_mdm',1,1,'retail_mdm','retail_mdm','172.17.210.180',3306,'utf8'),
    ('retail_mps',1,1,'retail_mps','retail_mps','172.17.210.134',8066,'utf8'),
    ('retail_pms_replenish',1,1,'pms_replenish','retail_pms_replenish','172.17.210.180',3306,'utf8'),
    ('retail_fms',1,1,'retail_fms','retail_fms','172.17.210.180',3306,'utf8'),
    ('dc_retail_gms',7,1,'root',null,'172.17.210.120',10000,'utf8'),
    ('dc_retail_pos',7,1,'root',null,'172.17.210.120',10000,'utf8'),
    ('dc_retail_mdm',7,1,'root',null,'172.17.210.120',10000,'utf8'),
    ('dc_retail_mps',7,1,'root',null,'172.17.210.120',10000,'utf8'),
    ('dc_retail_pms',7,1,'root',null,'172.17.210.120',10000,'utf8'),
    ('dc_retail_fas',7,1,'root',null,'172.17.210.120',10000,'utf8'),
    ('DEVZBSHOES',2,1,'u_sd_bl','belle','172.17.17.81',1521,'utf8'),
    ('dc_test',7,1,'root',null,'172.17.210.120',10000,'utf8')
    ;" | execute_meta

    # 任务
    echo "truncate table t_task;
    INSERT INTO t_task ( name, table_name, src_db_id, tar_db_id, status, valid ) 
    SELECT
        CONCAT( c.code, ' to ', e.code, ' ', a.table_name ) task_name,
        a.table_name,
        b.id src_db_id,
        d.id tar_db_id,
        0 status,
        1 valid
    FROM
        ( SELECT db_name src_db_name,
                CASE db_name
            WHEN 'retail_gms' THEN 'dc_retail_gms'
            WHEN 'retail_pos' THEN 'dc_retail_pos'
            WHEN 'retail_mdm' THEN 'dc_retail_mdm'
            WHEN 'retail_mps' THEN 'dc_retail_mps'
            WHEN 'retail_pms_replenish' THEN 'dc_retail_pms'
            WHEN 'retail_fms' THEN 'dc_retail_fas'
            WHEN 'DEVZBSHOES' THEN 'dc_test'
            END tar_db_name,
            table_name
        FROM
            (
                ( SELECT SUBSTR( db_name, POSITION('.' IN db_name) + 1 ) db_name, table_name
                    FROM meta_tables a 
                    INNER JOIN meta_dbs b 
                    ON a.db_id = b.id 
                    AND b.hostname IN ('172.17.17.81')
                    AND a.table_rows >= 1000000
                    ORDER BY table_rows DESC LIMIT 10
                )
                UNION ALL
                    ( SELECT db_name, table_name
                        FROM meta_tables a 
                        INNER JOIN meta_dbs b 
                        ON a.db_id = b.id 
                        AND b.hostname IN ( '172.17.210.180', '172.17.210.134' )
                        AND a.table_rows >= 1000000
                        ORDER BY table_rows DESC LIMIT 10
                    )
            ) t
        ) a,
        t_database b,
        t_db_type c,
        t_database d,
        t_db_type e
    WHERE a.src_db_name = b.db_name
    AND b.type_id = c.id
    AND a.tar_db_name = d.db_name
    AND d.type_id = e.id;" | execute_meta

    # 添加 split-by 字段
    execute_meta "UPDATE t_task SET split_column='c_custkey' WHERE name LIKE 'MYSQL to HIVE%' AND table_name='customer';
    UPDATE t_task SET split_column='l_orderkey' WHERE name LIKE 'MYSQL to HIVE%' AND table_name='lineitem';
    UPDATE t_task SET split_column='o_orderkey' WHERE name LIKE 'MYSQL to HIVE%' AND table_name='orders';
    UPDATE t_task SET split_column='p_partkey' WHERE name LIKE 'MYSQL to HIVE%' AND table_name='part';
    UPDATE t_task SET split_column='ps_partkey' WHERE name LIKE 'MYSQL to HIVE%' AND table_name='partsupp';
    UPDATE t_task SET split_column='id' WHERE name LIKE 'MYSQL to HIVE%' AND table_name='bill_shop_sale_order';"

    # 更新和mdm表同名的任务为无效（valid=0）
    execute_meta "UPDATE t_task a INNER JOIN t_task b 
    ON a.schema_name = 'dc_retail_mdm'
    AND b.schema_name <> 'dc_retail_mdm'
    AND a.table_name = b.table_name
    SET b.valid = 0
    "
}

# 获取数据库信息
# Globals:
# Arguments:
# Returns:
function get_db()
{
    local db_id="$1"

    execute_meta "SELECT a.hostname,b.name,a.db_name FROM t_database a,t_db_type b WHERE a.type_id=b.id AND a.id=$db_id;"
}

# 获取HDFS文件大小
# Globals:
# Arguments:
# Returns:
function get_file_size()
{
    local db_name="$1"
    local table_name="$2"

    hadoop fs -du -s /hive/warehouse/`echo ${db_name} | tr 'A-Z' 'a-z'`.db/`echo ${table_name} | tr 'A-Z' 'a-z'` | cut -d ' ' -f 1
}

# 检查hive中表是否存在
# Globals:
# Arguments:
# Returns:
function check_tables()
{
    execute_meta "SELECT b.db_name,LOWER(a.table_name) FROM t_task a,t_database b WHERE a.tar_db_id=b.id;" | while read db_name table_name; do
        echo "SELECT '$db_name','$table_name',count(1) FROM tbls a,dbs b WHERE a.DB_ID=b.DB_ID and b.NAME='$db_name' AND a.TBL_NAME='$table_name';"
    done | mysql -u hive -p123456 -s -N -D hive
}

# 清理hive中的数据
# Globals:
# Arguments:
# Returns:
function clear_data()
{
    execute_meta "SELECT b.db_name,a.table_name FROM t_task a,t_database b WHERE a.tar_db_id=b.id;" | while read db_name table_name; do
        echo "use $db_name;truncate table $table_name;"
    done | hive -S
}

# 执行操作
# Globals:
# Arguments:
# Returns:
function execute()
{
    execute_meta "select id,table_name,src_db_id,tar_db_id from t_task where status = 0 and valid = 1 LIMIT 20;" | while read task_id table_name src_db_id tar_db_id; do
        # 开始时间
        begin_time=`date +%s`
        # 启动任务
        sh task_runner.sh $task_id 2>&1 | tee -a $TMP_DIR/test.log
        # 结束时间
        end_time=`date +%s`

        src_db=($(get_db $src_db_id))
        tar_db=($(get_db $tar_db_id))

        # hdfs文件大小
        file_size=$(get_file_size ${tar_db[2]} $table_name)

        # 日志
        echo -e "${src_db[0]}_${src_db[1]}.${src_db[2]}\t${tar_db[0]}_${tar_db[1]}.${tar_db[2]}\t${table_name}\t$((end_time-begin_time))\t${file_size}" | tee -a $TMP_DIR/task.log
    done
}

# 统计
# Globals:
# Arguments:
# Returns:
function statistic()
{
    # 获取sqoop耗时
    grep -iE "mapreduce.ImportJobBase: Transferred" $TMP_DIR/test.log |
    sed 's/.* Transferred \(.*\) in \(.*\) seconds (\(.*\))/\1\t\2\t\3/i;s/,//g' > $TMP_DIR/sqoop.log

    paste -d '\t' $TMP_DIR/task.log $TMP_DIR/sqoop.log |
    awk -F '\t' 'BEGIN{OFS=FS}{print $1,$2,$3,$4,$5,$5/1024/1024,$5/$4/1024/1024,$6,$7,$8}'
}

function main()
{
    local action="$1"

    if [ "$action" = "check" ]; then
        check_tables
    else
        init_data
        clear_data
        execute
        statistic
    fi
}
main "$@"
