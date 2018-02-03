# 发送短信


# 用户名
ACCOUNT=jiuzhitianxia1
# 密码
PASSWORD=152339
# 短信网关
SMS_URL=http://sms.chanzor.com:8001/sms.aspx
# 超时时间
TIMEOUT=5
# 短信内容最大长度
MAX_LENGTH=280
# 临时文件目录
TMP_DIR=/tmp/sms_$USER


function main()
{
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <mobile phone numbers> <message content>" >&2
        exit 1
    fi

    phone_nums="$1"
    if [[ $# -gt 1 ]]; then
        msg_content="$2"
    else
        msg_content=`cat`
    fi

    # 流水号
    no=$(date +'%Y%m%d%H%M%S%N')

    # 创建目录
    mkdir -p $TMP_DIR/$no

    # 删除一段时间的历史文件（10天前）
    find $TMP_DIR -ctime +10 -type d | xargs -r rm -rf

    # 超出单条短信内容最大长度，则拆分成多条
    echo -e "$msg_content" | awk '{
        len = length($0)
        total += len
        if(total > max_length){
            if(msg > ""){
                ptotal = total - len
                size = int(ptotal / max_length)
                if (ptotal % max_length > 0) size += 1
                for(i=0;i<size;i++){
                    print substr(msg,i * max_length + 1,max_length) > "'$TMP_DIR/$no/message-'"++j
                }
            }
            total = len
            msg = $0
        }else{
            if(msg > ""){
                msg = msg"\n"$0
            }else{
                msg = $0
            }
        }
    } END {
        size = int(total / max_length)
        if (total % max_length > 0) size += 1
        for(i=0;i<size;i++){
            print substr(msg,i * max_length + 1,max_length) > "'$TMP_DIR/$no/message-'"++j
        }
    }' max_length=$MAX_LENGTH

    # 发送短信
    ls $TMP_DIR/$no/message-* | sort -t '-' -k 2n | while read file_name; do
        # 短信内容
        post_data="content=九指运维短信报警：`cat $file_name`【牙牙关注】"

        curl -s -w "\n%{http_code} %{time_connect} %{time_starttransfer} %{time_total}\n" --connect-timeout $TIMEOUT \
--data-urlencode "$post_data" "${SMS_URL}?action=send&account=${ACCOUNT}&password=${PASSWORD}&mobile=${phone_nums}"
    done > $TMP_DIR/$no/sms_log 2>&1
}
main "$@"