# 调度系统基本配置信息


# 任务配置状态
readonly TASK_STATUS_NORMAL=1        # 正常

# 任务实例状态
readonly TASK_STATE_INITIAL=0        # 等待
readonly TASK_STATE_READY=1          # 就绪
readonly TASK_STATE_ASSIGNED=2       # 已经分配
readonly TASK_STATE_RUNNING=3        # 正在运行
readonly TASK_STATE_SUCCESS=6        # 运行成功
readonly TASK_STATE_KILLED=8         # 被杀死
readonly TASK_STATE_FAILED=9         # 运行失败

# 任务周期类型
readonly TASK_CYCLE_DAY=day                # 天
readonly TASK_CYCLE_WEEK=week              # 周
readonly TASK_CYCLE_MONTH=month            # 月
readonly TASK_CYCLE_HOUR=hour              # 小时
readonly TASK_CYCLE_INTERVAL=interval      # 时间间隔
readonly TASK_CYCLE_INSTANT=instant        # 即时

# 业务表类型
readonly TABLE_TYPE_SIMPLE=0         # 单表
readonly TABLE_TYPE_SHARDING=1       # 分表
readonly TABLE_TYPE_DYNAMIC=2        # 动态表

# 运行模式
readonly RUN_MODE_ONCE=once          # 单次
readonly RUN_MODE_LOOP=loop          # 循环
RUN_MODE=$RUN_MODE_ONCE

# 元数据库配置
META_DB_TYPE=$DB_TYPE_MYSQL
META_DB_HOST=10.10.10.205
META_DB_PORT=3308
META_DB_USER=sched
META_DB_PASSWD=sched#sIeH9g
META_DB_NAME=sched
META_DB_CHARSET=utf8

# 开关
META_SQL_LOG=$SWITCH_ON     # sql日志开关，默认“开启”

# 文件目录
SCHED_LOG_DIR=/var/sched/log             # 调度系统日志文件目录
TASK_LOG_DIR=/var/sched/task/log         # 任务日志文件目录
TASK_DATA_DIR=/var/sched/task/data       # 任务数据文件目录
