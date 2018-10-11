#!/bin/bash
#
# Author: superz
# Date: 2017-06-20
# Description: sched集群自动安装程序
# Dependency: yum autossh autoscp


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source $DIR/shell/common/include.sh


# 集群配置信息
# ip admin_user admin_passwd roles server_id cluster_id
HOSTS="10.10.10.61 root 123456 manager,scheduler 1 1
10.10.10.64 root 123456 scheduler 2 1
10.10.10.65 root 123456 scheduler 3 1
10.10.10.66 root 123456 scheduler 4 1
10.10.10.67 root 123456 scheduler 5 1"

# 安装目录
INSTALL_DIR=/usr/local

# 环境变量
SHELL_HOME=$INSTALL_DIR/shell
SCHED_HOME=$INSTALL_DIR/sched

# 日志级别
LOG_LEVEL=$LOG_LEVEL_INFO


# 安装环境
function install_env()
{
    # 出错立即退出
    set -e
    # expect wget
    yum -y -q install expect

    # 出错不要立即退出
    set +e
    # 删除别名
    unalias cp mv rm

    # 出错立即退出
    set -e
    # 安装autossh autoscp
    if [[ ! -e /usr/bin/autossh ]]; then
        cp -f $DIR/shell/common/expect/autossh.exp /usr/lib/
        ln -sf /usr/lib/autossh.exp /usr/bin/autossh
        chmod +x /usr/bin/autossh
    fi
    if [[ ! -e /usr/bin/autoscp ]]; then
        cp -f $DIR/shell/common/expect/autoscp.exp /usr/lib/
        ln -sf /usr/lib/autoscp.exp /usr/bin/autoscp
        chmod +x /usr/bin/autoscp
    fi

    # 出错不要立即退出
    set +e
    # 删除别名
    echo "$HOSTS" | grep -v $LOCAL_IP | while read ip admin_user admin_passwd others; do
        autossh "$admin_passwd" ${admin_user}@${ip} "unalias cp mv rm"
    done
}

# 安装mysql命令
function install_mysql()
{
    echo "$HOSTS" | while read ip admin_user admin_passwd roles server_id others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 安装mysql命令
            type mysql > /dev/null 2>&1 || yum install -y -q mysql-community-client
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "type mysql > /dev/null 2>&1 || yum install -y -q mysql-community-client"
        fi
    done
}

# 设置环境变量
function set_env()
{
    echo "$HOSTS" | while read ip admin_user admin_passwd others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            sed -i '/^# sched config start/,/^# sched config end/d' /etc/profile
            sed -i '$ G' /etc/profile
            sed -i '$ a # sched config start' /etc/profile
            sed -i "$ a export SHELL_HOME=$SHELL_HOME" /etc/profile
            sed -i "$ a export SCHED_HOME=$SCHED_HOME" /etc/profile
            sed -i '$ a # sched config end' /etc/profile
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# sched config start/,/^# sched config end/d' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ G' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # sched config start' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export SHELL_HOME=$SHELL_HOME\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export SCHED_HOME=$SCHED_HOME\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # sched config end' /etc/profile"
        fi
    done
}

# 安装
function install()
{
    # 出错立即退出
    set -e

    # 安装sched
    echo "$HOSTS" | while read ip admin_user admin_passwd roles server_id others; do
        # 修改server_id
        sed -i "s/\(SERVER_ID=\).*/\1${server_id}/" $DIR/sched/scheduler/config.sh

        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 创建安装目录
            mkdir -p $INSTALL_DIR

            # 拷贝文件
            cp -rfp $DIR/shell $INSTALL_DIR
            cp -rfp $DIR/sched $INSTALL_DIR

            # 授权
            chmod +x $SHELL_HOME/daemon.sh $SHELL_HOME/common/mail_sender.py $SHELL_HOME/common/sms_sender.sh $SCHED_HOME/*.sh
            find $SCHED_HOME/plugins -mindepth 2 -maxdepth 2 -type f -name "*.sh" | xargs -r chmod +x
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $INSTALL_DIR"

            autoscp "$admin_passwd" $DIR/shell ${admin_user}@${ip}:$INSTALL_DIR
            autoscp "$admin_passwd" $DIR/sched ${admin_user}@${ip}:$INSTALL_DIR

            autossh "$admin_passwd" ${admin_user}@${ip} "chmod +x $SHELL_HOME/daemon.sh $SHELL_HOME/common/mail_sender.py $SHELL_HOME/common/sms_sender.sh $SCHED_HOME/*.sh"
            autossh "$admin_passwd" ${admin_user}@${ip} "find $SCHED_HOME/plugins -mindepth 2 -maxdepth 2 -type f -name '*.sh' | xargs -r chmod +x"
        fi
    done

    # 设置环境变量
    set_env

    # 出错不要立即退出
    set +e
}

# 卸载
function remove()
{
    echo "$HOSTS" | while read ip admin_user admin_passwd roles others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 删除安装文件
            rm -rf $SHELL_HOME $SCHED_HOME
            # 删除日志文件
            rm -f /var/log/task_manager.log /var/log/task_scheduler.log

            # 删除计划任务
            sed -i '/SHELL_HOME/d' /var/spool/cron/$USER
            sed -i '/SCHED_HOME/d' /var/spool/cron/$USER

            # 杀死进程
            ps aux | egrep 'task_manager|task_scheduler' | grep -v grep | awk '{print $2}' | xargs -r kill
            sleep 5
            ps aux | egrep 'task_manager|task_scheduler' | grep -v grep | awk '{print $2}' | xargs -r kill -9
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $SHELL_HOME $SCHED_HOME"
            autossh "$admin_passwd" ${admin_user}@${ip} "rm -f /var/log/task_manager.log /var/log/task_scheduler.log"

            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/SHELL_HOME/d' /var/spool/cron/$USER"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/SCHED_HOME/d' /var/spool/cron/$USER"

            autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | egrep 'task_manager|task_scheduler' | grep -v grep | awk '{print \$2}' | xargs -r kill"
            sleep 5
            autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | egrep 'task_manager|task_scheduler' | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
        fi
    done

    # 删除本地autossh autoscp
    if [[ "$remove_cmd" = all ]]; then
        rm -f /usr/lib/autossh.exp /usr/lib/autoscp.exp /usr/bin/autossh /usr/bin/autoscp
    fi
}

# 初始化
function init()
{
    # 加载数据库配置信息
    source $SCHED_HOME/common/config.sh
    if [[ "$LOCAL_IP" =~ 192.168 ]]; then
        source $SCHED_HOME/common/config-test.sh
    fi

    # 初始化数据
    mysql -h$META_DB_HOST -P$META_DB_PORT -u$META_DB_USER -p$META_DB_PASSWD < $SCHED_HOME/sql/sched.sql

    # 插入服务器数据
    echo "$HOSTS" | while read ip admin_user admin_passwd roles server_id cluster_id; do
        echo "INSERT IGNORE INTO t_server (id, cluster_id, ip) VALUES ($server_id, $cluster_id, '$ip');"
    done | mysql -h$META_DB_HOST -P$META_DB_PORT -u$META_DB_USER -p$META_DB_PASSWD $META_DB_NAME

    # 启动
    start
}

# 启动
function start()
{
    echo "$HOSTS" | while read ip admin_user admin_passwd roles others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            sed -i "$ a SHELL_HOME=$SHELL_HOME" /var/spool/cron/$USER
            sed -i "$ a SCHED_HOME=$SCHED_HOME" /var/spool/cron/$USER

            if [[ $roles =~ manager ]]; then
                (crontab -l 2> /dev/null;echo '*/1 * * * * $SHELL_HOME/daemon.sh $SCHED_HOME/task_manager.sh -m loop >> /var/log/task_manager.log 2>&1') | crontab -
            fi
            if [[ $roles =~ scheduler ]]; then
                (crontab -l 2> /dev/null;echo '*/1 * * * * $SHELL_HOME/daemon.sh $SCHED_HOME/task_scheduler.sh -m loop >> /var/log/task_scheduler.log 2>&1') | crontab -
            fi
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a SHELL_HOME=$SHELL_HOME\" /var/spool/cron/$USER"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a SCHED_HOME=$SCHED_HOME\" /var/spool/cron/$USER"

            if [[ $roles =~ manager ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "(crontab -l 2> /dev/null;echo '*/1 * * * * \$SHELL_HOME/daemon.sh \$SCHED_HOME/task_manager.sh -m loop >> /var/log/task_manager.log 2>&1') | crontab -"
            fi
            if [[ $roles =~ scheduler ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "(crontab -l 2> /dev/null;echo '*/1 * * * * \$SHELL_HOME/daemon.sh \$SCHED_HOME/task_scheduler.sh -m loop >> /var/log/task_scheduler.log 2>&1') | crontab -"
            fi
        fi
    done
}

# 停止
function stop()
{
    echo "$HOSTS" | while read ip admin_user admin_passwd roles others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 删除计划任务
            sed -i '/SHELL_HOME/d' /var/spool/cron/$USER
            sed -i '/SCHED_HOME/d' /var/spool/cron/$USER

            # 杀死进程
            ps aux | egrep 'task_manager|task_scheduler' | grep -v grep | awk '{print $2}' | xargs -r kill
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/SHELL_HOME/d' /var/spool/cron/$USER"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/SCHED_HOME/d' /var/spool/cron/$USER"

            autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | egrep 'task_manager|task_scheduler' | grep -v grep | awk '{print \$2}' | xargs -r kill"
        fi
    done
}

# 重启
function restart()
{
    echo "$HOSTS" | while read ip admin_user admin_passwd roles others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 杀死进程
            ps aux | egrep 'task_manager|task_scheduler' | grep -v grep | awk '{print $2}' | xargs -r kill
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | egrep 'task_manager|task_scheduler' | grep -v grep | awk '{print \$2}' | xargs -r kill"
        fi
    done
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 [-i install] [-r remove<all/sched>] [-s start<init/start/stop/restart>] [-v verbose]"
}

# 管理
function admin()
{
    ps aux | grep task_
}

function main()
{
    if [[ $# -eq 0 ]]; then
        print_usage
        exit 1
    fi

    # -i install 安装
    # -r [all/sched] 卸载
    # -s [init/start/stop/restart] 初始化/启动/停止/重启
    # -v debug模式
    while getopts "ir:s:v" name; do
        case "$name" in
            i)
                install_flag=1;;
            r)
                remove_cmd="$OPTARG";;
            s)
                start_cmd="$OPTARG";;
            v)
                LOG_LEVEL=$LOG_LEVEL_DEBUG;;
            ?)
                print_usage
                exit 1;;
        esac
    done

    # 安装环境
    log_fn install_env

    # 安装mysql命令
    log_fn install_mysql

    # 卸载集群
    [[ $remove_cmd ]] && log_fn remove

    # 安装集群
    [[ $install_flag ]] && log_fn install

    # 启动集群
    [[ $start_cmd ]] && log_fn $start_cmd
}
main "$@"