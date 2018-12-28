#!/bin/bash
#
# Date: 2015-10-12
# Author: superz
# Description: 元数据库备份
# 调度系统变量:
#   DATA_DIR          数据目录
#   META_DB_NAME      元数据库名
#   META_DB_HOST      元数据库主机
#   META_DB_PORT      元数据库端口
#   META_DB_USER      元数据库用户名
#   META_DB_PASSWD    元数据库密码
# 任务扩展属性:
#   backup_dir    备份目录
#   keep_num      备份保留个数


function execute()
{
    backup_dir=${backup_dir:-$DATA_DIR/$META_DB_NAME}

    if [[ -d $backup_dir ]]; then
        # 删除多余备份
        find $backup_dir -name "${META_DB_NAME}-*.gz" | xargs -r ls -c | sed "1,${keep_num:-9} d" | xargs -r rm -f
    else
        mkdir -p $backup_dir
    fi

    # 备份
    mysqldump -h$META_DB_HOST -P$META_DB_PORT -u$META_DB_USER -p$META_DB_PASSWD --opt -R $META_DB_NAME | gzip > $backup_dir/${META_DB_NAME}-$(date +%Y%m%d).gz
}
execute "$@"