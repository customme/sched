#!/bin/bash
#
# 任务运行器


DIR=`pwd`

source $DIR/config.sh
source $DIR/common.sh
source $DIR/task_config.sh
source $DIR/task_common.sh


#创建目录
mkdir -p $SQL_LOG_DIR 2> /dev/null
mkdir -p $TMP_DIR 2> /dev/null
mkdir -p $DATA_DIR 2> /dev/null


# 获取任务信息
# Globals:
# Arguments:
# Returns:
function get_task_info()
{
    execute_meta "SELECT id,table_name,src_db_id,tar_db_id,
        if(TRIM(split_column)>'',TRIM(split_column),NULL) split_column,
        IF(TRIM(sync_columns)>'',TRIM(sync_columns),NULL) sync_columns,
        IF(TRIM(incr_columns)>'',TRIM(incr_columns),NULL) incr_columns,
        IF(TRIM(query_sql)>'',1,0) query_sql,
        IF(TRIM(update_keys)>'',TRIM(update_keys),NULL) update_keys,
        IFNULL(UNIX_TIMESTAMP(begin_time),0) begin_time,
        UNIX_TIMESTAMP() end_time 
        FROM t_task 
        WHERE id = $task_id 
        OR (schema_name = '$db_name' AND table_name = '$table_name') 
        LIMIT 1
    "
}

# 获取数据库连接信息
# Globals:
# Arguments:
# Returns:
function get_db_info()
{
    local db_id="$1"

    execute_meta "SELECT b.code db_type,a.hostname,a.port,a.username,a.password,a.db_name,a.charset
        FROM t_database a
        INNER JOIN t_db_type b 
        ON a.type_id = b.id 
        AND a.id=$db_id
    "
}

# 更新任务状态
# Globals:
# Arguments:
# Returns:
function update_task_status()
{
    local task_status="$1"

    if [ $task_status -ne $TASK_STATUS_SUCCESS ]; then
        local sql="UPDATE t_task SET status=$task_status WHERE id=$task_id"
    else
        local sql="UPDATE t_task SET status=$task_status,begin_time=IF(incr_columns>'',FROM_UNIXTIME($end_time),NULL) WHERE id=$task_id"
    fi

    execute_meta "$sql"
}

# 获取自定义sql
# Globals:
# Arguments:
# Returns:
function get_query_sql()
{
    execute_meta "SELECT query_sql FROM t_task WHERE id = $task_id"
}

# 添加sqoop参数到配置文件
# Globals:
# Arguments:
# Returns:
function config_sqoop()
{
    if [ $# -gt 0 ]; then
        echo -e "$@" >> $TMP_DIR/$src_db_name/$table_name.opts
    else
        cat >> $TMP_DIR/$src_db_name/$table_name.opts
    fi
}

# 设置数据库参数
# Globals:
# Arguments:
# Returns:
function set_db_params()
{
    local db_type="$1"
    local db_host="$2"
    local db_port="$3"
    local db_user="$4"
    local db_pass="$5"
    local db_name="$6"
    local db_charset="$7"

    local db_url
    if [ "${db_type}" = "MYSQL" ]; then
        db_url="jdbc:mysql://${db_host}:${db_port}/${db_name}?characterEncoding=${db_charset}"
    elif [ "${db_type}" = "ORACLE" ]; then
        db_url="jdbc:oracle:thin:@${db_host}:${db_port}:${db_name}"
    elif [ "${db_type}" = "SYBASE" ]; then
        config_sqoop "--driver \n com.sybase.jdbc4.jdbc.SybDriver"
        db_url="jdbc:sybase:Tds:${db_host}:${db_port}/${db_name}"
    elif [ "${db_type}" = "MSSQL" ]; then
        db_url="jdbc:sqlserver://${db_host}:${db_port};DatabaseName=${db_name}"
    elif [ "${db_type}" = "POSTGRESQL" ]; then
        db_url="jdbc:postgresql://${db_host}:${db_port}/${db_name}"
    fi

    config_sqoop "--connect \n $db_url"
    config_sqoop "--username \n $db_user"
    config_sqoop "--password \n $db_pass"
}

function execute()
{
    #更新任务状态为1（正在运行）
    update_task_status $TASK_STATUS_RUNNING

    # 获取任务配置信息
    task_info=($(get_task_info))
    if [[ -z "${task_info[@]}" ]]; then
        err "Can not find any task by id=$task_id or (schema_name=$schema_name and table_name=$table_name)"
        exit 1
    fi

    # 设置任务参数
    task_id=${task_info[0]}
    table_name=${task_info[1]}
    src_db_id=${task_info[2]}
    tar_db_id=${task_info[3]}
    split_column=${task_info[4]}
    sync_columns="${task_info[5]/NULL/*}"
    incr_columns=${task_info[6]}
    query_sql=${task_info[7]}
    update_keys=${task_info[8]}
    begin_time=${task_info[9]}
    end_time=${task_info[10]}

    # 数据源
    src_db=($(get_db_info $src_db_id))
    src_db_type=${src_db[0]}
    src_db_name=${src_db[5]}

    # 数据目标
    tar_db=($(get_db_info $tar_db_id))
    tar_db_type=${tar_db[0]}
    tar_db_name="${tar_db[5]/NULL/}"

    if [[ -n "$incr_columns" && "$incr_columns" != "NULL" ]]; then
        create_time=${incr_columns%,*}
        update_time=${incr_columns#*,}

        # 日期格式转换
        case "${src_db_type}" in
            MYSQL)
                f_begin_time="FROM_UNIXTIME($begin_time)"
                f_end_time="FROM_UNIXTIME($end_time)"
                ;;
            ORACLE)
                f_begin_time="TO_DATE('$begin_time','yyyymmddhh24miss')"
                f_end_time="TO_DATE('$end_time','yyyymmddhh24miss')"
                ;;
            POSTGRESQL)
                f_begin_time="TO_DATE('$begin_time','yyyymmddhh24miss')"
                f_end_time="TO_DATE('$end_time','yyyymmddhh24miss')"
                ;;
            SYBASE)
                f_begin_time="CONVERT(DATETIME,'${begin_time:0:4}-${begin_time:4:2}-${begin_time:6:2} ${begin_time:8:2}:${begin_time:10:2}:${begin_time:12:2}')"
                f_begin_end="CONVERT(DATETIME,'${begin_time:0:4}-${begin_time:4:2}-${begin_time:6:2} ${begin_time:8:2}:${begin_time:10:2}:${begin_time:12:2}')"
                ;;
            HIVE)
                f_begin_time="FROM_UNIXTIME($begin_time)"
                f_end_time="FROM_UNIXTIME($end_time)"
                ;;
            *)
                err "Unsupported database type ${src_db_type}"
                exit 1
                ;;
        esac

        if [[ "$create_time" = "$update_time" ]]; then
            where=" AND ( $create_time >= $f_begin_time AND $create_time < $f_end_time ) "
        else
            where=" AND ( ( $create_time >= $f_begin_time AND $create_time < $f_end_time ) OR ( $update_time >= $f_begin_time AND $update_time < $f_end_time ) ) "
        fi
    fi

    if [ "${src_db_type}" = "HIVE" ]; then
        # 从hive导出
        if [ "${tar_db_type}" = "FS" ]; then
            # 导出到本地文件系统
            local export_dir=$DATA_DIR/$src_db_name/$table_name
            if [ -n "$tar_db_name" ]; then
                cd $tar_db_name && export_dir=`pwd`/$table_name && cd -
            fi

            local sql="INSERT OVERWRITE LOCAL DIRECTORY '$export_dir' ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' SELECT ${sync_columns} FROM ${src_db_name}.${table_name} WHERE 1=1 ${where};"

            # 日志
            log "export data from hive to local fs [$sql]"

            # 导出数据到local fs
            hive_executor "$sql"

            return $?
        else
            # 导出到数据库
            mkdir -p $TMP_DIR/$src_db_name 2> /dev/null

            echo "export" > $TMP_DIR/$src_db_name/$table_name.opts

            # 设置数据库参数
            set_db_params "${tar_db[@]}"

            # 导出hive数据到hdfs，路径为/user/$USER/$src_db_name/$table_name
            local export_dir=/user/$USER/$src_db_name/$table_name
            hadoop fs -mkdir -p $export_dir 2> /dev/null

            local sql="INSERT OVERWRITE DIRECTORY '$export_dir' SELECT ${sync_columns} FROM ${src_db_name}.${table_name} WHERE 1=1 ${where};"

            # 日志
            log "export data from hive to hdfs [$sql]"

            # 导出数据到hdfs
            hive_executor "$sql"

            # sqoop参数
            config_sqoop "--table \n $table_name"
            config_sqoop "--export-dir \n ${export_dir}"
            config_sqoop "--input-fields-terminated-by \n '\\\001'"
            config_sqoop "--input-null-string \n '\\\\\\N'"
            config_sqoop "--input-null-non-string \n '\\\\\\N'"
            # 批量模式
            config_sqoop "--batch"
            # 更新模式
            if [ "$update_keys" != "NULL" ]; then
                config_sqoop "--update-key \n ${update_keys}"
                config_sqoop "--update-mode \n allowinsert"
            fi
        fi
    else
        # 导入hive
        mkdir -p $TMP_DIR/$src_db_name 2> /dev/null

        echo "import" > $TMP_DIR/$src_db_name/$table_name.opts

        # 设置数据库参数
        set_db_params "${src_db[@]}"

        # 自定义sql
        if [ $query_sql -eq 1 ]; then
            local query_sql=$(get_query_sql | sed 's/\*/\\*/g')
            if [ -n "$where" ]; then
                query_sql="$query_sql WHERE 1=1 $where"
            fi
            config_sqoop "--query \n '$query_sql AND \$CONDITIONS'"
            sed -i 's/\\\*/\*/g' $TMP_DIR/$src_db_name/$table_name.opts

            # 目录存在，则先删除
            hadoop fs -rm -r /tmp/${tar_db_name}/${table_name} 2> /dev/null
            config_sqoop "--target-dir \n /tmp/${tar_db_name}/${table_name}"
        else
            # 表名
            config_sqoop "--table \n $table_name"
            # 同步字段
            if [ "$sync_columns" != "*" ]; then
                config_sqoop "--columns \n $sync_columns"
            fi
            # where条件
            if [ -n "$where" ]; then
                # 需要去掉第一个 AND
                config_sqoop "--where \n '${where:4}'"
            fi
        fi

        # sqoop参数
        config_sqoop "--hive-import"
        config_sqoop "--hive-table \n ${tar_db[5]}.${table_name}"
        config_sqoop "--fields-terminated-by \n '\\\t'"
        config_sqoop "--null-string \n '\\\\\\N'"
        config_sqoop "--null-non-string \n '\\\\\\N'"
        config_sqoop "--delete-target-dir"

        # 分区日期
        biz_date=`date -d @$end_time +%Y%m%d`
        config_sqoop "--hive-partition-key \n biz_date"
        config_sqoop "--hive-partition-value \n $biz_date"

        # split-by
        if [ "$split_column" != "NULL" ]; then
            config_sqoop "--split-by \n $split_column"
        else
            config_sqoop "-m \n 1"
        fi
    fi

    config_sqoop "--bindir \n $TMP_DIR/$src_db_name"
    config_sqoop "--outdir \n $TMP_DIR/$src_db_name"

    # 日志
    log `cat $TMP_DIR/$src_db_name/$table_name.opts`

    sqoop --options-file $TMP_DIR/$src_db_name/$table_name.opts

    if [ $? -eq 0 ]; then
        #更新任务状态为6（成功）
        update_task_status $TASK_STATUS_SUCCESS
    else
        #更新任务状态为9（失败）
        update_task_status $TASK_STATUS_FAILED
    fi
}

function main()
{
    if [ $# -eq 0 ]; then
        err "Invalid arguments"
        exit 1
    elif [ $# -eq 1 ]; then
        task_id="$1"
    elif [ $# -eq 2 ]; then
        task_id=0
        db_name="$1"
        table_name="$2"
    fi

    execute
}
main "$@"
