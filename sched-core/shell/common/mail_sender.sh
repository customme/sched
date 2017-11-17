# 发送邮件


mail_from="zhangchao@9zhitx.com"


# sendmail
#   邮件队列文件: /var/spool/mail/$USER
#   邮件日志文件: /var/log/mailog
#   查看邮件发送队列: mailq/sendmail -bp
#   删除队列中的邮件: postsuper -d queue_id/ALL
function main()
{
    if [[ $# -lt 3 ]]; then
        echo "Usage: $0 <to list> <subject> <mail content>" >&2
        exit 1
    fi

    local to_list="$1"
    local subject=`echo "$2" | base64`
    local content="$3"

    if [[ -n "$log_path" ]]; then
        local mail_file=$log_path/mail_content.tmp
    else
        local mail_file=/tmp/mail_content_$(date +%s).tmp
    fi

    echo "From: $mail_from" > $mail_file
    echo "To: $to_list" >> $mail_file
    echo "Mime-Version: 1.0" >> $mail_file
    echo "Content-Disposition: inline" >> $mail_file
    echo "Content-Type: text/html;charset=uft-8" >> $mail_file
    echo "Subject: =?utf-8?B?${subject}?=" >> $mail_file

    if [[ -f "$content" ]]; then
        cat $content >> $mail_file
    else
        echo "$content" >>  $mail_file
    fi

    cat $mail_file | sendmail -t
}
main "$@"