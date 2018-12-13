# 常用工具


if [[ -f $SHELL_HOME/common/config.sh ]]; then
    source $SHELL_HOME/common/config.sh
elif [[ -f $DIR/shell/common/config.sh ]]; then
    source $DIR/shell/common/config.sh
else
    echo "$(date +'%F %T') WARN [ Can not find config.sh ]"
fi


# 生成等长数字序列
# 参数:
#   最小数字
#   最大数字
#   跨度（可选）
# 示例:
#   range_num 0 99
#   range_num 0 98 2
function range_num()
{
    echo $@ | awk '{
        num_begin=$1
        num_end=$2
        span=$3 > 0 ? $3 : 1

        size=length(num_end)

        while(num_begin <= num_end){
            printf("%0*d\n",size,num_begin)
            num_begin += span
        }
    }'
}

# 生成等长随机字数字
# 参数:
#   位数（可选）
#   个数（可选）
function random_num()
{
    echo $@ | awk 'BEGIN{
        srand()
    }{
        digit=$1 > 0 ? $1 : 1
        num=$2 > 0 ? $2 : 1
        for(i=0;i < num;i++){
            value=10 ^ digit * rand()
            printf("%0*d\n",digit,value)
        }
    }'
}

# 去掉左右空格
function trim()
{
    sed 's/^[[:space:]]*\|[[:space:]]*$//g'
}

# 转小写
function to_lower()
{
    tr 'A-Z' 'a-z'
}

# 转大写
function to_upper()
{
    tr 'a-z' 'A-Z'
}

# 左对齐
# 参数:
#   原字符串
#   补位后的长度
#   填充字符（可选，如果原字符串是数字，则默认为0）
function lalign()
{
    echo $@ | awk '{
        value=$1
        total_size=$2
        char=$3 > "" ? $3 : " "

        if(value ~ /^[[:digit:]]*$/) char=char > " " ? char : 0

        size=total_size - length(value)

        printf("%s",value)
        for(i=1;i<size;i++){
            printf("%s",char)
        }
        printf("%s\n",char)
    }'
}

# 获取文件大小
# 参数:
#   文件名
function file_size()
{
    ls -l "$1" | awk '{print $5}'
}

# 获取本机ip
function local_ip()
{
    /sbin/ifconfig -a | grep inet | grep -Ev "127.0.0.1|inet6" | awk 'NR == 1 {print $2}' | tr -d 'addr:'
}
LOCAL_IP=`local_ip`

# 获取系统版本
function sys_version()
{
    sed 's/.* release \([0-9]\.[0-9]\).*/\1/' /etc/redhat-release
}
SYS_VERSION=`sys_version`

# 获取进程数
# 参数:
#   进程名称
#   排除列表（可选）
function count_thread()
{
    local thread="$1"
    local excludes="$2"

    if [ -z "$excludes" ]; then
        excludes="grep"
    else
        excludes="grep|$excludes"
    fi

    local count=`ps -ef | grep "$thread" | grep -Ev "$excludes" | wc -l 2> /dev/null`

    echo ${count:-0}
}

# 记录日志
function log()
{
    echo "$(date +'%F %T') $@"
}

# 调试信息
function debug()
{
    if [[ $LOG_LEVEL -le $LOG_LEVEL_DEBUG ]]; then
        log "DEBUG ${FUNCNAME[1]}:${BASH_LINENO[0]} [ $@ ]"
    fi
}

# 基本信息
function info()
{
    if [[ $LOG_LEVEL -le $LOG_LEVEL_INFO ]]; then
        log "INFO ${FUNCNAME[1]}:${BASH_LINENO[0]} [ $@ ]"
    fi
}

# 警告信息
function warn()
{
    if [[ $LOG_LEVEL -le $LOG_LEVEL_WARN ]]; then
        log "WARN ${FUNCNAME[1]}:${BASH_LINENO[0]} [ $@ ]" >&2
    fi
}

# 错误信息
function error()
{
    if [[ $LOG_LEVEL -le $LOG_LEVEL_ERROR ]];then
        log "ERROR ${FUNCNAME[1]}:${BASH_LINENO[0]} [ $@ ]" >&2
    fi
}

# 在方法执行前后记录日志
function log_fn()
{
    info "Function call begin [ $@ ]"
    $@
    info "Function call end [ $@ ]"
}

# 函数功能尚未实现
function todo_fn()
{
    if [[ -n "$@" ]]; then
        warn "$@"
    else
        warn "Function: ${FUNCNAME[1]} is yet to be implemented"
    fi
}

# 删除所有空目录
function rm_empty_dir()
{
    local base_dir="$1"

    while [[ `find $base_dir -type d -empty | wc -l` -gt 0 ]]; do
        find $base_dir -type d -empty | while read the_dir; do
            debug "Delete directory: $the_dir"
            rm -rf $the_dir
        done
    done
}

# 查找文件内容
# 参数:
#   查找目录
#   文件通配符
#   查找关键字
function search_file()
{
    local base_dir="$1"
    local wildcard="$2"
    local keyword="$3"

    find $base_dir -type f -name "$wildcard" | while read file_name; do
        grep -l "$keyword" $file_name
    done | while read file_name; do
        echo $file_name
        grep -n "$keyword" $file_name
    done
}

# 数字转ip
function num2ip()
{
    local num="$1"

    local ip1=$((num >> 24))
    local ip2=$((num >> 16 & 0xff))
    local ip3=$((num >> 8 & 0xff))
    local ip4=$((num & 0xff))

    echo "$ip1.$ip2.$ip3.$ip4"
}

# ip转数字
function ip2num()
{
    local ip="$1"

    local arr=(${ip//./ })

    echo $((${arr[0]} << 24 | ${arr[1]} << 16 | ${arr[2]} << 8 | ${arr[3]}))
}
