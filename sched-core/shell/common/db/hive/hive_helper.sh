#!/bin/bash
#
# hive 工具


# 删除数据库所有表
# 排除数据库default、dc_test
# Globals:
# Arguments:
# Returns:
function drop_tables()
{
    hive -S -e "show databases;" | grep -Ev "default|dc_test" | while read db_name; do
        echo "drop database if exists $db_name cascade;create database if not exists $db_name;"
    done | hive
}

# 清数据库空所有表
# 排除数据库default、dc_test
# Globals:
# Arguments:
# Returns:
function truncate_tables()
{
    hive -S -e "show databases;" | grep -Ev "default|dc_test" | while read db_name; do
        hive -S --database $db_name -e "show tables;" | while read table_name; do
            echo "truncate table $table_name;"
        done | hive --database $db_name
    done
}

function main()
{
    truncate_tables
}
main "$@"
