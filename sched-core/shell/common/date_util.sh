# 日期时间工具


# 设置日期时间变量
function set_datetime()
{
    if [[ -n "$1" ]]; then
        the_date=$(date +%F -d "$1")
    else
        the_date=$(date +%F)
    fi

    the_week=$(date +%w -d "$the_date")
    the_month=${the_date:0:7}
    the_year=${the_date:0:4}

    prev_date=$(date +%F -d "$the_date 1 day ago")
    next_date=$(date +%F -d "$the_date 1 day")
    prev_month=$(date +%Y-%m -d "${the_month}-01 1 month ago")
    next_month=$(date +%Y-%m -d "${the_month}-01 1 month")
    prev_year=$(date +%Y -d "${the_year}-01-01 1 year ago")
    next_year=$(date +%Y -d "${the_year}-01-01 1 year")

    local diff=$((1 - ${the_week/0/7}))
    mon_date=$(date +%F -d "$the_date $diff day")               # 周一
    sun_date=$(date +%F -d "$mon_date 6 day")                   # 周日
    first_date="${the_month}-01"                                # 月初
    last_date=$(date +%F -d "$first_date 1 month 1 day ago")    # 月末
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

# 日期间隔天数
function date_diff()
{
    local start_date="$1"
    local end_date="${2:-$(date +%F)}"

    local start_time=$(date +%s -d "$start_date")
    local end_time=$(date +%s -d "$end_date")
    local date_diff=$(((end_time - start_time) / 60 / 60 / 24))

    echo "$date_diff"
}
