#!/bin/bash
#
# 一、生成随机android id和连续id
# 生成规则:
# 1、随机字符由[0-9][a-f]组成
# 2、字符串首位字符由[1-9][a-f]组成
# 3、字符串长度为16位占94%，15位占6%
# 4、id为连续正整数


MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWD=mysql
MYSQL_DB=test
MYSQL_CHARSET=utf8

# android id表名
TBL_AID="t_androidid"

# 临时文件目录
TMPDIR=/tmp


# 执行sql
function exec_sql()
{
    local sql="${1:-`cat`}"
    local params="${2:--s -N --local-infile}"

    echo "SET NAMES $MYSQL_CHARSET;$sql" | mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_USER -p$MYSQL_PASSWD $MYSQL_DB $params
}

# num 个数
# 例如生成100个随机字符串: rand_str 100
function rand_str()
{
    echo "$@" | awk 'BEGIN{
        srand()

        for(i=0;i<=9;i++){
            x[i]=i
        }
        x[10]="a"
        x[11]="b"
        x[12]="c"
        x[13]="d"
        x[14]="e"
        x[15]="f"
        size=length(x)
    }{
        num=$1

        for(i=0;i<num;i++){
            a = int(rand() * (size - 1)) + 1
            str = x[a]

            c = int(rand() * 100)
            if(c < 6){
                digit = 15
            }else{
                digit = 16
            }

            for(j=1;j<digit;j++){
                b = int(rand() * size)
                str = str""x[b]
            }
            print str
        }
    }'
}

function main()
{
    num="${1:-10000}"

    export LC_ALL=C
    set -e

    # 获取已有的aid
    echo "Get data from database"
    time(echo "SELECT aid, id FROM $TBL_AID;" | exec_sql > $TMPDIR/aid.old)

    # 获取最大id
    max_id=`awk '{print $2}' $TMPDIR/aid.old | sort -n | tail -n 1`

    # 生成新aid
    rand_str $num > $TMPDIR/aid.tmp

    # 排序
    sort -u $TMPDIR/aid.old -o $TMPDIR/aid.old
    sort -u $TMPDIR/aid.tmp -o $TMPDIR/aid.tmp

    # 去重
    join -v 1 $TMPDIR/aid.tmp $TMPDIR/aid.old > $TMPDIR/aid.new
    count=`wc -l $TMPDIR/aid.new | awk '{print $1}'`
    # 循环生成直到满足指定个数num为止
    while [[ $count -lt $num ]]; do
        rand_str $((num - count)) > $TMPDIR/aid.tmp

        cat $TMPDIR/aid.new >> $TMPDIR/aid.old

        sort -u $TMPDIR/aid.tmp -o $TMPDIR/aid.tmp
        sort -u $TMPDIR/aid.old -o $TMPDIR/aid.old

        join -v 1 $TMPDIR/aid.tmp $TMPDIR/aid.old >> $TMPDIR/aid.new
        count=`wc -l $TMPDIR/aid.new | awk '{print $1}'`
    done

    # 打乱顺序
    # 生成连续id
    awk 'BEGIN{
        srand()
    }{
        printf("%s\t%d\n",$1,rand() * num * 10)
    }' num=$num $TMPDIR/aid.new |
    sort -k 2 -n |
    awk 'BEGIN{OFS="\t"}{
        print NR + id,$1
    }' id=$max_id > $TMPDIR/aid.txt

    # 导入数据库
    echo "Load data into database"
    echo "CREATE TABLE IF NOT EXISTS $TBL_AID (id BIGINT, aid VARCHAR(16));" | exec_sql
    time(echo "LOAD DATA LOCAL INFILE '$TMPDIR/aid.txt' INTO TABLE $TBL_AID;" | exec_sql)
}
time(main "$@")