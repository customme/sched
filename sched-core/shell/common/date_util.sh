# 日期时间工具


# 初始化时间变量
function init_date()
{
    the_day="$1"

    cur_date=$(date +%Y%m%d)
    cur_datetime=$(date +%Y%m%d%H%M%S)

    if [[ -z "$the_day" ]]; then
        the_day=$cur_date
    fi

    the_month=`date +%Y%m -d "$the_day"`
    the_year=`date +%Y -d "$the_day"`
    prev_day=`date +%Y%m%d -d "$the_day 1 day ago"`
    next_day=`date +%Y%m%d -d "$the_day 1 day"`
    prev_month=`date +%Y%m -d "${the_month}01 1 month ago"`
    next_month=`date +%Y%m -d "${the_month}01 1 month"`
    prev_year=`date +%Y -d "${the_year}0101 1 year ago"`
    next_year=`date +%Y -d "${the_year}0101 1 year"`

    the_day1=`date +%Y-%m-%d -d "$the_day"`
    the_month1=`date +%Y-%m -d "$the_day"`
    prev_day1=`date +%Y-%m-%d -d "$the_day 1 day ago"`
    next_day1=`date +%Y-%m-%d -d "$the_day 1 day"`
    prev_month1=`date +%Y-%m -d "${the_month}01 1 month ago"`
    next_month1=`date +%Y-%m -d "${the_month}01 1 month"`
}

# 生成日期/月份/小时
# 用法:
: '
range_date 20120101 20120131
range_date 201201 201212
range_date 2012010100 2012010320
'
function range_date()
{
    local date_begin="$1"
    local date_end="$2"
    local span="${3:-1}"

    while [ $date_begin -le $date_end ]; do
        echo "$date_begin"
        if [ ${#date_begin} -eq 10 ]; then
            date_begin=${date_begin:0:8}" "${date_begin:8:10}
            date_begin=`date +%Y%m%d%H -d "$date_begin $span hour"`
        elif [ ${#date_begin} -eq 6 ]; then
            date_begin=`date +%Y%m -d "${date_begin}01 $span month"`
        else
            date_begin=`date +%Y%m%d -d "${date_begin} $span day"`
        fi
    done
}

# 生成某年第几周、周开始日期、周结束日期
# 用法:
:<<eof
range_week 20140501 20140510
range_week 20140501 20140510 extend
eof
function range_week()
{
    local date_begin="$1"
    local date_end="$2"
    local extend="$3"

    local week_num=`date +%w -d "$date_begin"`
    week_num=$((week_num > 0 ? week_num : 7))
    if [ -n "$extend" ]; then
        week_num=$((week_num == 1 ? 0 : 1 - $week_num))
    else
        week_num=$((week_num == 1 ? 0 : 7 - $week_num + 1))
    fi
    local week_begin=`date +%Y%m%d -d "$date_begin $week_num day"`

    week_num=`date +%w -d "$date_end"`
    if [ -n "$extend" ]; then
        week_num=$((week_num == 0 ? 0 : 7 - $week_num))
    else
        week_num=$((week_num == 0 ? 0 : -$week_num))
    fi
    local week_end=`date +%Y%m%d -d "$date_end $week_num day"`

    while [[ `date +%Y%m%d -d "$week_begin 1 day"` -lt $week_end ]]; do
        echo `date +%Y%W -d "$week_begin"` $week_begin `date +%Y%m%d -d "$week_begin 6 day"`
        week_begin=`date +%Y%m%d -d "$week_begin 7 day"`
    done
}

# 是否为日期格式(yyyy-mm-dd)
function is_date()
{
    echo "$1" | grep '^[0-9]\{4\}\(-[0-9]\{2\}\)\{2\}$' > /dev/null 2>&1
}

# 验证日期是否合法
function is_valid_date()
{
    date +%F -d "$1" > /dev/null 2>&1
}

# 格式化时间(%Y%m%d%H%M[%S] -> %F %T)
# 用法:
:<<!
format_time 201410301750
format_time 20141030175011
!
function format_time()
{
    local the_time="$1"
    local the_second=${the_time:12:2}

    echo `date +'%Y-%m-%d %H:%M' -d "${the_time:0:8} ${the_time:8:4}"`:${the_second:-00}
}