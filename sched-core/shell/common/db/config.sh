# 数据库配置信息


# 数据库类型
readonly DB_TYPE_MYSQL=MYSQL
readonly DB_TYPE_ORACLE=ORACLE
readonly DB_TYPE_POSTGRES=POSTGRESQL
readonly DB_TYPE_MSSQL=MSSQLSERVER
readonly DB_TYPE_SYBASE=SYBASE
readonly DB_TYPE_SAIKU=SAIKU
readonly DB_TYPE_HIVE=HIVE

# 数据库连接方式
readonly DB_CONN_TYPE_CLI=0
readonly DB_CONN_TYPE_JDBC=1
readonly DB_CONN_TYPE_ODBC=2
readonly DB_CONN_TYPE_HTTP=3
readonly DB_CONN_TYPE_ZK=4

# 数据同步指令
readonly CMD_CREATE_TABLE=table             # 创建表
readonly CMD_CREATE_EXP=table_file          # 创建表、导出文件
readonly CMD_CREATE_IMP=table_file_data     # 创建表、导入数据
readonly CMD_EXP_FILE=file                  # 导出文件
readonly CMD_IMP_DATA=file_data             # 导入数据

# 创建表模式
readonly CREATE_MODE_SKIP=skip         # 跳过
readonly CREATE_MODE_AUTO=auto         # 自动创建
readonly CREATE_MODE_DROP=drop         # 先删除后创建

# 数据装载模式
readonly LOAD_MODE_IGNORE=ignore          # 忽略重复数据
readonly LOAD_MODE_APPEND=append          # 追加
readonly LOAD_MODE_REPLACE=replace        # 替换重复数据
readonly LOAD_MODE_TRUNCATE=truncate      # 清空数据

# 分页大小
PAGE_SIZE=10                # 分页大小
SYNC_PAGE_SIZE=100000       # 数据同步分页大小

# 开关
SQL_LOG=$SWITCH_ON              # sql日志开关，默认“开启”
