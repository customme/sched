# 数据库工具
#
# 变量依赖:
#   src_db=(db_type hostname port username password db_name charset db_conn_type)
#   tar_db=(MYSQL 10.10.20.103 3306 ums_dw SiGiy4qO6kpVc6 jz_ums utf8 CLI)


source $SHELL_HOME/common/db/config.sh


# 执行数据源sql
function execute_src()
{
    local sql="$1"
    local extras="$2"

    if [[ -z "$sql" ]]; then
      sql=`cat`
    fi

    local sql_log_file=$log_path/src_sql.log

    case ${src_db[0]} in
        $DB_TYPE_MYSQL)
            src_db_url=$(make_mysql_url "${src_db[1]}" "${src_db[3]}" "${src_db[4]}" "${src_db[5]}" "${src_db[2]}")
            src_db_charset=${src_db[6]}
            mysql_executor "SET NAMES $src_db_charset;$sql" "$src_db_url $extras"
            ;;
        $DB_TYPE_ORACLE)
            error "Unsupported database type: ${src_db[0]}"
            exit 1
            ;;
        $DB_TYPE_POSTGRESQL)
            error "Unsupported database type: ${src_db[0]}"
            exit 1
            ;;
        $DB_TYPE_HIVE)
            if [[ ${src_db[7]} -eq $DB_CONN_TYPE_JDBC ]]; then
                src_db_url=$(make_hive_url "${src_db[7]}" "${src_db[1]}" "${src_db[3]}" "${src_db[4]}" "${src_db[5]}" "${src_db[2]}")
            else
                src_db_url=$(make_hive_url "${src_db[7]}" "${src_db[5]}" "${src_db[3]}")
            fi
            hive_executor "$sql" "$src_db_url $extras"
            ;;
        *)
            error "Unsupported database type: ${src_db[0]}"
            exit 1
            ;;
    esac
}

# 执行数据目标sql
function execute_tar()
{
    local sql="$1"
    local extras="$2"

    if [[ -z "$sql" ]]; then
      sql=`cat`
    fi

    local sql_log_file=$log_path/tar_sql.log

    case ${tar_db[0]} in
        $DB_TYPE_MYSQL)
            tar_db_url=$(make_mysql_url "${tar_db[1]}" "${tar_db[3]}" "${tar_db[4]}" "${tar_db[5]}" "${tar_db[2]}")
            tar_db_charset=${tar_db[6]}
            mysql_executor "SET NAMES $tar_db_charset;$sql" "$tar_db_url $extras"
            ;;
        $DB_TYPE_ORACLE)
            error "Unsupported database type: ${tar_db[0]}"
            exit 1
            ;;
        $DB_TYPE_POSTGRESQL)
            error "Unsupported database type: ${tar_db[0]}"
            exit 1
            ;;
        $DB_TYPE_HIVE)
            if [[ ${tar_db[7]} -eq $DB_CONN_TYPE_JDBC ]]; then
                tar_db_url=$(make_hive_url "${tar_db[7]}" "${tar_db[1]}" "${tar_db[3]}" "${tar_db[4]}" "${tar_db[5]}" "${tar_db[2]}")
            else
                tar_db_url=$(make_hive_url "${tar_db[7]}" "${tar_db[5]}" "${tar_db[3]}")
            fi
            hive_executor "$sql" "$tar_db_url $extras"
            ;;
        *)
            error "Unsupported database type: ${tar_db[0]}"
            exit 1
            ;;
    esac
}

# 预装载数据
function preload()
{
    # 装载模式
    case $tar_load_mode in
        $LOAD_MODE_IGNORE)
            load_mode=IGNORE
            ;;
        $LOAD_MODE_REPLACE)
            load_mode=REPLACE
            ;;
        $LOAD_MODE_TRUNCATE)
            debug "Truncate table: $tar_table"
            execute_tar "TRUNCATE TABLE $tar_table"
            ;;
        $LOAD_MODE_APPEND)
            warn "An error will occur when a duplicate key value is found for current load mode: $tar_load_mode"
            ;;
        *)
            warn "Unknow data load mode: $tar_load_mode"
            ;;
    esac
}