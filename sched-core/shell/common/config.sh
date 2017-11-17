# 基本配置信息


# 开关
readonly SWITCH_ON=0        # 开启
readonly SWITCH_OFF=1       # 关闭

# 日志级别
readonly LOG_LEVEL_DEBUG=0      # 调试信息
readonly LOG_LEVEL_INFO=1       # 基本信息
readonly LOG_LEVEL_WARN=2       # 警告信息
readonly LOG_LEVEL_ERROR=3      # 错误信息
LOG_LEVEL=$LOG_LEVEL_DEBUG      # 设置日志级别

# 指令
readonly CMD_INIT=init        # 初始化
readonly CMD_STAY=stay        # 常驻内存

# ssh默认端口
SSH_PORT=22

UNDEFINED_VALUE=TheUndefinedValue       # 未定义

# 文件目录
LOG_DIR=/var/log         # 日志文件目录
DATA_DIR=/var/lib        # 数据文件目录
