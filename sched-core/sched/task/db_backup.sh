#!/bin/bash
#
# 元数据库备份


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