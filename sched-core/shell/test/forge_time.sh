#!/bin/bash
#
# 伪造文件修改时间


# 扫描目标文件目录（多个用逗号隔开）
tar_dirs=/work/data/logs/fans_n,social_n,/work/www/shell/logs

# 扫描时间间隔（3600秒）
CHECK_INTERVAL=3600


# 记录日志
function log()
{
    echo "$(date +'%F %T.%N') [ $@ ]"
}

function check()
{
    for dir in `echo "$tar_dirs" | tr ',' '\n'`; do
        pdir=`dirname "$dir"`
        if [[ "$pdir" != "." ]]; then
            ppdir="$pdir"
        fi
        echo "${ppdir:-$pdir}/"`basename "$dir"`
    done |
    xargs -r -I {} find {} -name "*\.[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]" |
    while read file; do
        # 最后修改时间
        modify_date=`stat $file | awk '$1 ~ /Modify/ {print $2}'`
        modify_time=`stat $file | awk '$1 ~ /Modify/ {print substr($3,1,5)}'`
        # 数据日期
        the_date=`echo $file | awk -F '.' '{print $NF}'`

        if [[ "$modify_date" != "$the_date" || "$modify_time" != "23:59" ]]; then
            # 伪造时间
            fake_time=`echo $the_date | awk 'BEGIN{
                srand()
            }{
                second=int(rand() * 60)
                printf("%s 23:59:%02d",$1,second)
            }'`

            echo -e "$file\t$modify_date $modify_time\t$fake_time"
            touch -m -d "$fake_time" $file
        fi
    done #| awk -F '[.\t ]' '{if($2 != $3) print $2,$3}'
}

function main()
{
    if [[ -n "$@" ]]; then
        tar_dirs="$@"

        # 扫描一次
        check
    else
        # 循环扫描
        while :; do
            log "Scan files"
            check

            log "Sleep $CHECK_INTERVAL"
            sleep $CHECK_INTERVAL
        done
    fi
}
main "$@"