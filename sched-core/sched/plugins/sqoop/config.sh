#!/bin/bash
#
# 基本配置信息


# sql日志开关
SQL_LOG=on

# sql日志目录
LOG_DIR=~/log/retail/sql
# 临时文件目录
TMP_DIR=~/tmp/retail
# 数据文件目录
DATA_DIR=~/data/retail

# 指令
CMD_CREATE_TABLE=table          # 创建表
CMD_CREATE_EXP=table_file       # 创建表、导出文件
CMD_CREATE_IMP=table_file_data  # 创建表、导入数据
CMD_EXP_FILE=file               # 导出文件
CMD_IMP_DATA=file_data          # 导入数据

# 异常编码
E_INVALID_ARGS=1000     # 非法参数
E_UNSUPPORTED_DB=1001   # 不支持的数据库
