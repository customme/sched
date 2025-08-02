#!/usr/bin/expect -f

# scp自动传输文件


# 参数判断
if { $argc < 3 } {
    send_error "Usage: ./autoscp password \[user@host:]src_file \[user@host:]tar_file \[port] \[timeout] \[options]\n"
    exit 1
}

# 参数设置
set password [lindex $argv 0]
set src_file [lindex $argv 1]
set tar_file [lindex $argv 2]
if { $argc > 3 } {
    set port [lindex $argv 3]
} else {
    set port 22
}
if { $argc > 4 } {
    set timeout [lindex $argv 4]
} else {
    set timeout 60
}

# 启动scp进程
spawn scp -P $port -o ConnectTimeout=$timeout -rp $options $src_file $tar_file

# 验证密码
expect {
    "yes/no" { send "yes\r"; exp_continue }
    "password:" { send "$password\r"; exp_continue }
    "ould not resolve" { exit 1 }
    "denied" { exit 2 }
    "o such file" { exit 3 }
    timeout { send_error "Connection timed out"; exit 4 }
    eof { exit }
}