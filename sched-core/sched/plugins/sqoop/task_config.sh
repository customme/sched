#!/bin/bash
#
# 任务配置信息


# 元数据库
META_DB_HOST=172.17.210.180
META_DB_USER=dc_scheduler_cli
META_DB_PASS=dc_scheduler_cli
META_DB_NAME=dc_scheduler_client
META_DB_CHARSET=utf8
META_DB_PARAMS="-s -N"

# 任务日志目录
TASK_LOG_DIR=~/log/retail/task

# 任务有效性
TASK_VALID=1

# 任务状态
TASK_STATUS_INIT=0
TASK_STATUS_RUNNING=1
TASK_STATUS_PAUSED=2
TASK_STATUS_SUCCESS=6
TASK_STATUS_FAILED=9

# 一次获取任务数量
TASK_FETCH_SIZE=10

# 最大并发数
MAX_THREAD_COUNT=3

# 任务扫描时间间隔
TASK_CHECK_INTERVAL=1m

# 异常编码
E_TASK_NOT_FOUND=10000      # 找不到任务
