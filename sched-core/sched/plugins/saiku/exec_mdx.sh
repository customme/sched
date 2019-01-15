#!/bin/bash
#
# Date: 2018-01-15
# Author: superz
# Description: 模拟saiku执行mdx
# 环境变量:
#   SCHED_HOME    调度系统家目录
# 调度系统变量
#   log_path           任务日志目录
# 任务扩展属性:
#   src_db_id          saiku连接id
#   saiku_path         saiku服务路径
#   saiku_version      saiku版本(2.x/3.x)
#   catalog_name       
#   schema_name        
#   cube_name          cube名称
#   src_mdx            待执行mdx
#   is_refresh         是否先刷新cube(1:刷新)
#   tar_db_id          目标数据库id
#   tar_table_name     目标表名
#   tar_columns        目标表映射字段
#   tar_load_mode      目标数据装载模式
#   tar_set_columns    SET col_name=expr,...
#   stat_column        统计日期字段
#   source_file        通过source命令引入的文件


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $SHELL_HOME/common/db/db_util.sh
source $SCHED_HOME/plugins/db_util.sh


# 获取源数据库连接
function get_src_db()
{
    if [[ -z "$src_db_id" ]]; then
        error "Empty source database id"
        return 1
    fi

    debug "Get source database by id: $src_db_id"
    src_db=($(get_db $src_db_id))
    if [[ -z "${src_db[@]}" ]]; then
        error "Can not find source database by id: $src_db_id"
        return 1
    fi
    debug "Got source database: ${src_db[@]}"

    # saiku连接信息
    saiku_url="http://${src_db[1]}:${src_db[2]}/$saiku_path"
    saiku_user="${src_db[3]}"
    saiku_passwd="${src_db[4]}"
    conn_name="${src_db[5]}"
    saiku_charset="${src_db[6]}"
    timeout=60
}

# 登录获取cookie
function login_saiku()
{
    login_url=$saiku_url/session

    curl -s --connect-timeout $timeout -c $log_path/cookie.tmp -d "username=$saiku_user&password=$saiku_passwd" $login_url

    # 判断cookie是否获取成功
    if [[ ! -s $log_path/cookie.tmp ]]; then
        error "Log into saiku failed"
        return 1
    fi
}

# 刷新Cube
function refresh_cube()
{
    if [[ $saiku_version =~ 3 ]]; then
        # saiku3
        refresh_url=$saiku_url/admin/datasources/${conn_name}/refresh?_=`date +%s`
    else
        refresh_url=$saiku_url/$saiku_user/discover/$conn_name/refresh?_=`date +%s`
    fi

    curl -s --connect-timeout $timeout -b $log_path/cookie.tmp $refresh_url > /dev/null
}

# 初始化查询
function init_query()
{
    # 生成查询名称
    query_name=`uuidgen`

    # 创建查询请求地址
    if [[ ! $saiku_version =~ 3 ]]; then
        init_query_url=$saiku_url/$saiku_user/query/$query_name

        # 创建查询
        curl -s --connect-timeout $timeout -b $log_path/cookie.tmp -o $log_path/query_result.tmp -X POST -d "connection=$conn_name&catalog=$catalog_name&schema=$schema_name&cube=$cube_name" $init_query_url

        # 判断查询是否创建成功
        if [[ ! -s $log_path/query_result.tmp ]]; then
            error "Create query failed, please check the parameters: {connection=$conn_name&catalog=$catalog_name&schema=$schema_name&cube=$cube_name}"
            return 1
        fi
    else
        # saiku3
        init_query_url=$saiku_url/api/query/$query_name
    fi
}

# 构建请求参数
function build_param()
{
    dos2unix -q $log_path/src_mdx.tmp

    if [[ $saiku_version =~ 3 ]]; then
        echo "{"
        echo "\"cube\" : {"
        echo "\"name\" : \"${cube_name}\","
        echo "\"connection\" : \"${conn_name}\","
        echo "\"catalog\" : \"${catalog_name}\","
        echo "\"schema\" : \"${schema_name}\""
        echo "},"
        echo "\"mdx\" : \"`cat $log_path/src_mdx.tmp`\","
        echo "\"name\" : \"${query_name}\","
        echo "\"type\" : \"MDX\""
        echo "}"
    else
        echo "mdx=`cat $log_path/src_mdx.tmp`"
    fi | tr '\n' ' ' | tr '\t' ' ' | tee $log_path/post_data
}

# 错误检查
function check_error()
{
    egrep '\["error"\]' | awk -F '\t' '{
        if($2 != "null"){
            gsub("\\\\","",$2)
            print substr($2,2,length($2)-2)
        }
    }'
}

# 过滤数据
function filter_data(){
    egrep '\["cellset",[0-9]+,[0-9]+,"value"\]' | awk -F '\t' '{
        value=substr($2,2,length($2)-2)
        if(value~"^[0-9,.]+$"){
            gsub(",","",value)
        }
        split($1,aa,",")
        if(aa[3]==0 && NR>1){
            printf("\n")
            col=0
            row=row+1
        }
        if(col>0){
            printf("\t")
        }
        printf(value)
        col=col+1
    }'
}

function execute()
{
    # 获取待执行mdx语句
    log_task $LOG_LEVEL_INFO "Get mdx to be executed"
    get_prop_replace $task_id src_mdx > $log_path/src_mdx.tmp

    # 获取源数据库连接信息
    get_src_db

    # 登录获取cookie
    log_task $LOG_LEVEL_INFO "Log into saiku and get cookie"
    login_saiku

    # 是否刷新
    if [[ $is_refresh -eq 1 ]]; then
        log_task $LOG_LEVEL_INFO "Refresh cube"
        refresh_cube
    fi

    # 初始化查询
    log_task $LOG_LEVEL_INFO "Create a new query"
    init_query

    # 查询请求地址
    if [[ $saiku_version =~ 3 ]]; then
        # saiku3
        query_url=$saiku_url/api/query/execute
    else
        query_url=$saiku_url/$saiku_user/query/$query_name/result/flat
    fi

    # 执行mdx语句
    if [[ -n "$tar_db_id" ]]; then
        # 获取目标数据库连接信息
        get_tar_db

        tar_table=$tar_table_name

        # 任务重做
        if [[ $redo_flag -eq 1 ]]; then
            # 必须要有统计日期字段
            if [[ -z "$stat_column" ]]; then
                error "Can not find statistical column, program do not know how to redo the task"
                exit 1
            fi
            execute_tar "DELETE FROM $tar_table WHERE $stat_column = '$prev_date'" "-vvv" > $log_path/redo.log
        fi

        # 构建请求参数
        info "Build query parameters for post request"
        post_data=`build_param`

        # 设置请求头
        if [[ $saiku_version =~ 3 ]]; then
            http_header="-H Content-Type:application/json -H Accept:application/json"
        fi

        # 执行查询，下载数据
        log_task $LOG_LEVEL_INFO "Execute mdx query and download data to file: $data_path/result.json"
        http_code=$(curl -s -w %{http_code} --connect-timeout $timeout -b $log_path/cookie.tmp -o $data_path/result.json $http_header -X POST -d "$post_data" $query_url)

        if [[ ! "$http_code" =~ ^200|30[0-9]$ ]]; then
            error "Query failed, saiku server return http code: $http_code"
            exit 1
        fi

        # json数据转tab
        log_task $LOG_LEVEL_INFO "Convert json data to tab separated data"
        echo -e "$data_path/result.json\n" | awk -f $SHELL_HOME/common/JSON.awk > $data_path/result.tmp

        # 执行mdx结果错误判断
        local error_msg=`check_error < $data_path/result.tmp`
        if [[ -n "$error_msg" ]]; then
            error "$error_msg"
            exit 1
        fi

        debug "Filter data"
        filter_data < $data_path/result.tmp > $data_path/result.txt

        # 判断文件内容是否为空
        if [[ ! -s $data_path/result.txt ]]; then
            error "Can not fetch any data"
            exit 1
        fi

        # 获取表头行数
        header_lines=`sed '/\t"DATA_CELL"$/q' $data_path/result.tmp | tail -n 1 | cut -d , -f 2`

        # 预装载数据
        debug "Preload data"
        preload

        # 导入目标表
        local sql="LOAD DATA LOCAL INFILE '$data_path/result.txt' $load_mode INTO TABLE $tar_table IGNORE $header_lines LINES"

        # 指定字段
        if [[ -n "$tar_columns" ]]; then
            sql="$sql ( $tar_columns )"
        fi

        # 统计日期
        if [[ -n "$stat_column" ]]; then
            sql="$sql SET $stat_column = DATE($prev_day)"
        fi

        # 设置字段
        if [[ -n "$tar_set_columns" ]]; then
            if [[ -n "$stat_column" ]]; then
                sql="$sql, $tar_set_columns"
            else
                sql="$sql SET $tar_set_columns"
            fi
        fi

        log_task $LOG_LEVEL_INFO "Load data to target table: $tar_table"
        execute_tar "$sql" "-vvv" > $log_path/load_data.log
    else
        curl -s --connect-timeout $timeout -b $log_path/cookie.tmp -d "mdx=`cat $log_path/src_mdx.tmp`" $query_url
    fi
}

source $SCHED_HOME/plugins/task_executor.sh