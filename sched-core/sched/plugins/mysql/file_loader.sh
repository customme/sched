#!/bin/bash
#
# Date: 2015-09-15
# Author: superz
# Description: 文件导入mysql
# 环境变量:
#   SCHED_HOME    调度系统家目录
# 调度系统变量
#   log_path           任务日志目录
# 任务扩展属性:
#   src_host           数据文件所在服务器
#   src_port           服务器ssh端口
#   src_user           服务器用户名
#   src_passwd         服务器密码
#   src_dir            文件所在目录
#   src_file           文件名
#   src_field_sep      字段分隔符
#   delete_file        入库后直接删除文件
#   file_suffix        入库后修改文件后缀
#   skip_latest        入库时忽略最新的一个文件
#   tar_db_id          目标数据库id
#   tar_table_name     目标表名
#   tar_columns        目标字段
#   tar_set_columns    SET col_name=expr,...
#   tar_load_mode      目标数据装载模式


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $SHELL_HOME/common/db/db_util.sh
source $SCHED_HOME/plugins/db_util.sh


# 装载数据
function load_data()
{
    # 导入数据库
    debug "Load file: $file_name begin"

    # 替换特殊字符
    cat $file_name | mysql_data_conv > ${file_name}.txt
    file_name=${file_name}.txt

    local sql="LOAD DATA LOCAL INFILE '$file_name' INTO TABLE $tar_table_name FIELDS TERMINATED BY '${src_field_sep:-\t}' OPTIONALLY ENCLOSED BY '\"'"

    # 指定字段
    if [[ -n "$tar_columns" ]]; then
        sql="$sql ( $tar_columns )"
    fi

    # 设置字段
    if [[ -n "$tar_set_columns" ]]; then
        sql="$sql $tar_set_columns"
    fi

    # 执行sql语句
    execute_tar "$sql" "-vvv" > $log_path/${tar_table_name}_`basename $file_name`.log || return $?
    log_task $LOG_LEVEL_INFO "Load file: $file_name done"
}

# 标记完成文件
# 删除文件或加文件后缀
function mark_done()
{
    if [[ -z "$src_host" ]]; then
        if [[ $delete_file -eq 1 ]]; then
            rm -f $file_name
        else
            mv -f $file_name ${file_name}${file_suffix}
        fi
    else
        file_name=`basename $file_name`
        if [[ $delete_file -eq 1 ]]; then
            $SHELL_HOME/common/expect/autossh.exp "$src_passwd" $src_user@$src_host "rm -f $src_dir/$file_name"
        else
            $SHELL_HOME/common/expect/autossh.exp "$src_passwd" $src_user@$src_host "mv -f $src_dir/$file_name $src_dir/${file_name}${file_suffix}"
        fi
    fi
}

function execute()
{
    # 获取目标数据库连接
    get_tar_db

    # 文件同步成功后的后缀
    file_suffix=${file_suffix:-.DONE}

    if [[ -z "$src_host" ]]; then
        if [[ $src_dir =~ ^hdfs:// ]]; then
            # 先删除本地文件
            find $data_path -maxdepth 1 -type f -name "${src_file:-*}" | xargs -r rm -f

            # 下载数据到本地
            hdfs dfs -get $src_dir/${src_file:-*} $data_path

            # 装载数据
            find $data_path -maxdepth 1 -type f -name "${src_file:-*}" | while read file_name; do
                load_data || return $?
            done
        else
            # 查找待导入的文件，最后一个创建的文件不导入，防止有数据进入
            log_task $LOG_LEVEL_INFO "Find files to be load from local directory: $src_dir"
            # 是否忽略最新生成的一个文件
            if [[ $skip_latest -eq 1 ]]; then
                find $src_dir -maxdepth 1 -type f -name "${src_file:-*}" | grep -v "$file_suffix" | xargs -r ls -cr | sed '$d' | while read file_name; do
                    # 装载数据
                    load_data || return $?

                    # 标记完成文件
                    mark_done
                done
            else
                find $src_dir -maxdepth 1 -type f -name "${src_file:-*}" | grep -v "$file_suffix" | xargs -r ls -cr | while read file_name; do
                    # 装载数据
                    load_data || return $?

                    # 标记完成文件
                    mark_done
                done
            fi
        fi
    else
        # 获取文件
        log_task $LOG_LEVEL_INFO "Fetch files from remote host: $src_host"
        $SHELL_HOME/common/expect/autoscp.exp "$src_passwd" $src_user@$src_host:$src_dir/"${src_file:-*}" $data_path

        log_task $LOG_LEVEL_INFO "Find files to be load"
        if [[ $skip_latest -eq 1 ]]; then
            find $data_path -maxdepth 1 -type f -name "${src_file:-*}" | grep -v "$file_suffix" | xargs -r ls -cr | sed '$d' | while read file_name; do
                # 装载数据
                load_data || return $?

                # 标记完成文件
                mark_done
            done
        else
            find $data_path -maxdepth 1 -type f -name "${src_file:-*}" | grep -v "$file_suffix" | xargs -r ls -cr | while read file_name; do
                # 装载数据
                load_data || return $?

                # 标记完成文件
                mark_done
            done
        fi
    fi
}

source $SCHED_HOME/plugins/task_executor.sh