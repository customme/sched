#!/bin/bash
# 修复hdfs数据没有按日期分目录的情况


BASE_DIR=/flume/advs
FILE_PREFIX=advs171
TOPIC_PREFIX=topic_ad_


# 生成日期序列
function range_date()
{
    local date_begin=`date +%Y%m%d -d "$1"`
    local date_end=`date +%Y%m%d -d "$2"`

    while [[ $date_begin -le $date_end ]]; do
        date +%F -d "$date_begin"
        date_begin=`date +%Y%m%d -d "$date_begin 1 day"`
    done
}

# 获取hdfs数据
function get_hdfs()
{
    range_date $start_date $end_date | while read the_date; do
        # 下载hdfs文件
        hdfs dfs -get $BASE_DIR/$the_date 2> /dev/null
    done
}

# 修复数据
function repair_data()
{
    local prev_date=`date +%F -d "$start_date 1 day ago"`
    range_date $start_date $end_date | while read the_date; do
        test -d $the_date && ls $the_date |
        while read topic; do
            mkdir -p $topic
            # 按日期和topic汇总
            range_date $prev_date $end_date | while read the_date1; do
                grep -h "createtime\":\"$the_date1 " $the_date/$topic/$FILE_PREFIX.* >> $topic/$FILE_PREFIX.$the_date1
            done
        done
    done
}

# 上传到hdfs
function put_hdfs()
{
    find . -mindepth 1 -maxdepth 1 -type d -name "${TOPIC_PREFIX}*" | while read the_dir; do
        topic=`basename $the_dir`
        ls $the_dir | while read the_file; do
            the_date=${the_file##*.}
            hdfs dfs -mkdir -p $BASE_DIR/$the_date/$topic
            hdfs dfs -put $the_dir/$the_file $BASE_DIR/$the_date/$topic
        done
    done
}

# 删除hdfs数据
function delete_hdfs()
{
    range_date $start_date $end_date | while read the_date; do
        test -d $the_date && find $the_date -type f | grep -v tmp$ | while read the_file; do
            hdfs dfs -rm -f -skipTrash $BASE_DIR/$the_file
        done
    done
}

function main()
{
    if [[ $# -lt 2 ]]; then
        echo "ERROR: Please specify start date and end date"
        exit 1
    fi
    start_date="$1"
    end_date="$2"

    get_hdfs

    repair_data

    put_hdfs

    delete_hdfs
}
main "$@"