#!/bin/bash

warehouse_dir=/hive

function range_date()
{
    local date_begin="$1"
    local date_end="$2"

    while [ $date_begin -le $date_end ]; do
        date +'%Y-%m-%d' -d "$date_begin"
        if [ ${#date_begin} -eq 10 ]; then
            date_begin=${date_begin:0:8}" "${date_begin:8:10}
            date_begin=`date +%Y%m%d%H -d "$date_begin 1 hour"`
        elif [ ${#date_begin} -eq 6 ]; then
            date_begin=`date +%Y%m -d "${date_begin}01 1 month"`
        else
            date_begin=`date +%Y%m%d -d "${date_begin} 1 day"`
        fi
    done
}

# 合并hive小文件
function merge_file()
{
    hdfs dfs -getmerge $warehouse_dir/$db_name.db/$table_name/$part_column=$the_date $table_name.$the_date
    hdfs dfs -rm -f -skipTrash $warehouse_dir/$db_name.db/$table_name/$part_column=$the_date/part-*
    hdfs dfs -put $table_name.$the_date $warehouse_dir/$db_name.db/$table_name/$part_column=$the_date/part-00000
}

# 参数列表
# db_name table_name part_column start_date end_date
# 例如: recommender d_info_click click_date 20160716 20161212
function main()
{
    db_name="$1"
    table_name="$2"
    part_column="$3"
    start_date="$4"
    end_date="$5"

    range_date "$start_date" "$end_date" | while read the_date; do
        merge_file
    done
}
main "$@"