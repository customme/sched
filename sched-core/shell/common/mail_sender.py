#!/usr/bin/python
# -*- coding: utf-8 -*-
# 发送邮件


import sys
import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication


# 外网
smtp_host = "smtp.9zhitx.com"
# 内网
smtp_host = "10.10.10.7"
smtp_port = 25
mail_user = "zhangchao@9zhitx.com"
mail_passwd = "q12345"
timeout = 60


def main(argv):
    to_list = sys.argv[1]
    subject = sys.argv[2]

    msg = MIMEMultipart()
    msg['From'] = mail_user
    msg['To'] = to_list
    msg['Subject'] = subject

    # 正文
    content = ""
    if (len(sys.argv) > 3 and len(sys.argv[3].strip()) > 0):
        content = sys.argv[3]
    else:
        for line in sys.stdin:
            content += line
    msg_text = MIMEText(content, _subtype='html', _charset='utf-8')
    msg.attach(msg_text)

    # 附件
    if (len(sys.argv) > 4 and len(sys.argv[4].strip()) > 0):
        attachments = sys.argv[4].split(",")
        for attachment in attachments:
            msg_file = MIMEApplication(open(attachment, 'rb').read())
            msg_file.add_header('Content-Disposition', 'attachment', filename=os.path.basename(attachment))
            msg.attach(msg_file)

    server = None
    try:
        server = smtplib.SMTP(smtp_host, smtp_port, timeout)
        server.login(mail_user, mail_passwd)
        server.sendmail(mail_user, to_list.split(";"), msg.as_string())
        print "邮件发送成功"
        sys.exit(0)
    except Exception, e:
        sys.stderr.write("邮件发送失败: " + str(e) + "\n")
        sys.exit(1)
    finally:
        if server: server.close()

if __name__ == "__main__":
    if (len(sys.argv) < 3):
        sys.stderr.write("Usage: " + sys.argv[0] + " <to list> <mail subject> <mail content> [attachment file]\n")
        sys.exit(1)

    main(sys.argv)