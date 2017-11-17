#!/bin/bash
#
# 守护进程
# 用法:
: '
SHELL_HOME=/usr/local/script
SCHED_HOME=/usr/local/schedule
*/5 * * * * $SHELL_HOME/daemon.sh $SCHED_HOME/task_manager.sh -m loop >> /var/log/task_manager.log 2>&1
*/5 * * * * $SHELL_HOME/daemon.sh $SCHED_HOME/task_scheduler.sh -m loop >> /var/log/task_scheduler.log 2>&1
'

# 待启动命令
command="$1"
shift
# 参数
params="$@"

if [[ -n "$command" ]]; then
    # 待启动命令进程数
    thread_count=`ps -ef | grep "$command" | grep -Ev "$0|grep" | wc -l`
    if [[ $thread_count -eq 0 ]]; then
        echo `date +'%F %T'`" INFO [ Execute command: $command $params ]"
        exec $command $params
    fi
else
    echo `date +'%F %T'`" ERROR [ The command is empty ]" >&2
fi