#!/bin/bash
#
# 爬取港币兑人民币汇率
# 数据来源: 中国银行外汇牌价


# URL地址
URL=http://srh.bankofchina.com/search/whpj/search.jsp
# 港币货币编号
CUR_NO=1315
# 页大小
PAGE_SIZE=$((20 - 5))
# 港币币种ID
SRC_CUR=1
# 人民币币种ID
TAR_CUR=0
# 数据库名
DB_NAME=jeecg_dev

# 日志文件目录
LOG_PATH=/var/crawl
# 临时文件目录
TMP_PATH=/tmp/crawl/$(date +%s%N)


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

# 执行sql
function exec_sql()
{
    local sql="${1:-`cat`}"
    local params="${2:--s -N --local-infile}"

    echo "SET NAMES utf8;$sql" | mysql -uroot $DB_NAME $params
}

# 解析数据
function parse()
{
    awk '{
        if($0 ~ /<td>港币<\/td>/){
            flag=1
            print $0
        }else{
            if(flag == 1){
                if($0 ~ /<td>[0-9]{4}\.[0-9]{2}\.[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}<\/td>/){
                    gsub(/\./,"-",$0)
                    flag=0
                }
                print $0
            }
        }
    }' | sed 's/.*<td>\(.*\)<\/td>.*/\1/' | awk -F '\t' 'BEGIN{OFS=FS}{
        if($1 == "港币"){
            flag=1
            printf("%s",$1)
        }else{
            if(flag == 1){
                printf("\t%s",$1)
                if($0 ~ /[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/){
                    flag=0
                    printf("\n")
                }
            }
        }
    }' | sort -u
}

# 存储数据
function persist()
{
    awk -F '\t' 'BEGIN{OFS=FS}{
        printf("INSERT IGNORE INTO ps_rate(src_cur, tar_cur, rate, update_time) VALUES(%s, %s, %s, \"%s\");\n","'$SRC_CUR'","'$TAR_CUR'",$2,$7)
    }' | exec_sql
}

# 爬取数据
function crawl()
{
    # 下载网页存储文件
    local file_tmp=$TMP_PATH/result.tmp.$the_date

    # 开始下载
    http_code=`curl -s -w %{http_code} --connect-timeout 60 -X post -d "erectDate=$the_date&nothing=$the_date&pjname=$CUR_NO&page=${page:-1}" -o $file_tmp $URL`

    # 解析数据
    if [[ $http_code == 200 ]]; then
        parse < $file_tmp > ${file_rate}.${page:-1}

        # 判断是否可能有下一页
        count=`wc -l ${file_rate}.${page:-1} | awk '{print $1}'`
        if [[ $count -ge $PAGE_SIZE ]]; then
            # 爬取下一页
            page=`expr ${page:-1} + 1`
            crawl
        else
            # 合并小文件
            cat ${file_rate}.* | sort -t $'\t' -k 7 -u > $file_rate
            rm -f ${file_rate}.*

            # 存储数据
            persist < $file_rate
        fi
    else
        # 休眠1分钟后重试
        sleep 1m
        crawl
    fi
}

function main()
{
    begin_date="$1"
    end_date="$2"
    if [[ -z "$begin_date" ]]; then
        begin_date=$(date +%F)
    fi
    if [[ -z "$end_date" ]]; then
        end_date=$begin_date
    fi

    # 创建目录
    mkdir -p $TMP_PATH

    # 逐天爬取
    range_date $begin_date $end_date | while read the_date; do
        # 创建目录
        mkdir -p $LOG_PATH/$the_date

        # 汇率数据文件
        file_rate=$LOG_PATH/$the_date/hkd-cny

        # 开始爬取
        crawl &
    done
}
main "$@"