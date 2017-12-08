#!/bin/bash

mysql_port=3307
# extra_port=3367
install_log=/tmp/mysql_install.log
mysql_install_dir="/usr/local/mysql_3307"
mysql_data_dir="/data/mysql_3307"
mysql_tmp_dir="/data/mysqltmp_3307"
mysql_5_7_version=5.7.19
jemalloc_version=5.0.1
install_file_dir="/work/soft"
dbrootpwd=mysql
log_dir="/work/log"
character_set=utf8mb4
buffer_pool_size=48G
log_file_size=4G
init_timeout=120

cd ${install_file_dir}
yum -y install gcc gcc-c++ ncurses-devel cmake make perl autoconf automake zlib lz4 lz4-devel numactl \
libxml2 libxml2-devel libgcrypt libtool bison bison-devel libaio libaio-devel readline-devel openssl openssl-devel

# server_id=`ifconfig eno1 | grep "inet" | awk '{print $2}'|awk -F '.' '{print $4}'`
server_id=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|grep 10.10| awk '{print $2}'|tr -d "addr:"|awk -F '.' '{print $4}'`

#create user
groupadd mysql >/dev/null 2>&1
id -u mysql >/dev/null 2>&1
[ $? -ne 0 ] && useradd -M -s /sbin/nologin -g mysql mysql

#create directory
[ ! -d "$mysql_install_dir" ] && mkdir -p $mysql_install_dir
chown mysql:mysql -R $mysql_install_dir
[ ! -d "$mysql_data_dir" ] && mkdir -p $mysql_data_dir
chown mysql.mysql -R $mysql_data_dir


wait_for_pid () {
  i=0
  while test $i -ne $init_timeout ; do
    test -s "$1" && break
    i=`expr $i + 1`
    sleep 1
  done
}


wait_for_init () {
  i=0
  while test $i -ne $init_timeout ; do
    init_status=`cat "$1" | grep 'Generating a new UUID' | wc -l`
    if [[ $init_status -ge 1 ]] ;then
      echo "`date '+%Y-%m-%d %H:%M:%S'`...... initialize ok " | tee -a $install_log
      break
    else
      sleep 1
    fi
    i=`expr $i + 1`
  done
}


Install_Jemalloc()
{
	rm -rf jemalloc-${jemalloc_version}
	tar -jxf ${install_file_dir}/jemalloc-${jemalloc_version}.tar.bz2 -C ./
	cd jemalloc-${jemalloc_version}
	./configure >/dev/null 2>&1
	make >/dev/null 2>&1
	make install

	if [ -f "/usr/local/lib/libjemalloc.so" ];then
	    echo "jemalloc install successfully!"  | tee -a $install_log
	    cd ..
	    rm -rf jemalloc-${jemalloc_version}
	else
	    echo "jemalloc install failed!" | tee -a $install_log
	    kill -9 $$
	fi

	if [ ! -f /etc/ld.so.conf.d/usr_local_lib.conf ]; then
		echo '/usr/local/lib' > /etc/ld.so.conf.d/usr_local_lib.conf
	fi
	/sbin/ldconfig
}

# 单机多实例,独立安装Boost
Install_Boost()
{
	rm -rf boost_1_59_0
	tar -zxf ${install_file_dir}/boost_1_59_0.tar.gz -C ./
	cd boost_1_59_0
	./bootstrap.sh >/dev/null 2>&1
	./b2 install

	if [ -d "/usr/local/include/boost" ];then
	    echo "boost install successfully!" | tee -a $install_log
	    cd ..
	    rm -rf boost_1_59_0
	else
	    echo "boost install failed!" | tee -a $install_log
	    kill -9 $$
	fi
	/sbin/ldconfig
}

Install_MySQL()
{

echo "`date '+%Y-%m-%d %H:%M:%S'`...... Begin Install_MySQL_5_7 " | tee -a $install_log

tar -zxf ${install_file_dir}/mysql-boost-${mysql_5_7_version}.tar.gz -C ./
cd mysql-${mysql_5_7_version}

echo "`date '+%Y-%m-%d %H:%M:%S'`...... make " | tee -a $install_log

#CFLAGS=   # TODO
#CXX=g++
#CXXFLAGS=    # TODO
#export CFLAGS CXX CXXFLAGS              # TODO

make clean
cmake . -DCMAKE_INSTALL_PREFIX=$mysql_install_dir \
-DMYSQL_DATADIR=$mysql_data_dir \
-DSYSCONFDIR=$mysql_install_dir \
-DMYSQL_UNIX_ADDR=$mysql_install_dir/mysql.sock \
-DMYSQL_TCP_PORT=$mysql_port \
-DWITH_INNOBASE_STORAGE_ENGINE=1 \
-DWITH_PARTITION_STORAGE_ENGINE=1 \
-DWITH_FEDERATED_STORAGE_ENGINE=1 \
-DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
-DWITH_PERFSCHEMA_STORAGE_ENGINE=1 \
-DWITH_EMBEDDED_SERVER=1 \
-DWITH_ZLIB=system \
-DENABLED_LOCAL_INFILE=1 \
-DEXTRA_CHARSETS=all \
-DDEFAULT_CHARSET=$character_set \
-DDEFAULT_COLLATION=${character_set}_general_ci \
-DENABLE_DTRACE=0 \
-DCMAKE_EXE_LINKER_FLAGS="-ljemalloc"

# -DENABLE_DOWNLOADS=1

# -DWITH_BOOST=boost # 带boost库源码,非独立安装boost库时可加上.

make   # -j `grep processor /proc/cpuinfo | wc -l`
make install

if [ -d "$mysql_install_dir/support-files" ];then
    echo "${CSUCCESS}MySQL install successfully! ${CEND}"
    cd ..
else
    rm -rf $mysql_install_dir
    echo "${CFAILURE}MySQL install failed, Please contact the author! ${CEND}"
    kill -9 $$
fi

/bin/cp $mysql_install_dir/support-files/mysql.server /etc/init.d/mysqld_$mysql_port
chmod +x /etc/init.d/mysqld_$mysql_port
chkconfig mysqld_$mysql_port on


mkdir -p ${log_dir}/{binlog_$mysql_port,relaylog_$mysql_port,slow_$mysql_port};chown mysql:mysql -R ${log_dir}/{binlog_$mysql_port,relaylog_$mysql_port,slow_$mysql_port}
mkdir -p $mysql_tmp_dir;chown mysql.mysql -R $mysql_tmp_dir
#mkdir -p /var/run/mysqld;chown mysql:mysql -R /var/run/mysqld
#mkdir -p /var/log/mysqld;chown mysql:mysql -R /var/log/mysqld
mkdir -p ${log_dir}/mysqld;chown mysql:mysql -R ${log_dir}/mysqld

cat >$mysql_install_dir/my.cnf<< EOF
[mysql]
no_auto_rehash
prompt = (\u@\h)[\d]>
loose-default_character_set = $character_set
[client]
port = $mysql_port
socket = $mysql_install_dir/mysql.sock
loose-default_character_set = $character_set
[mysqld]
# GENERAL #
# default_time_zone = '+8:00'
local_infile = OFF
server_id = $server_id$mysql_port
port = $mysql_port
user = mysql
default_storage_engine = InnoDB
basedir = $mysql_install_dir
socket = $mysql_install_dir/mysql.sock
pid-file = ${log_dir}/mysqld/mysqld_$mysql_port.pid
datadir = $mysql_data_dir
transaction_isolation = READ-COMMITTED
explicit_defaults_for_timestamp = 1
# lower_case_table_names = 1
character_set_server = $character_set
collation_server = ${character_set}_general_ci
show_compatibility_56 = on
# THREAD POOL # percona
# thread_handling = pool-of-threads
# thread_pool_oversubscribe = 5
# thread_pool_stall_limit = 200
# thread_pool_max_threads = 1000
# thread_pool_high_prio_mode = transactions
# extra_port = $extra_port
# extra_max_connections = 5
# SAFETY #
max_allowed_packet = 64M
secure_file_priv = NULL
skip_name_resolve = 1
skip_ssl = 1
# BINARY LOGGING #
max_binlog_size = 500M
log_bin = ${log_dir}/binlog_$mysql_port/mysql_bin
expire_logs_days = 14
sync_binlog = 1
gtid_mode = ON
enforce_gtid_consistency = 1
binlog_format = ROW
binlog_cache_size = 2M
log_bin_trust_function_creators = 1
binlog_rows_query_log_events = 1
# binlog_group_commit_sync_no_delay_count = 8
# binlog_group_commit_sync_delay = 10000
# REPLICATION #
skip_slave_start = 1
log_slave_updates = 1
relay_log = ${log_dir}/relaylog_$mysql_port/relay_bin
relay_log_recovery = 1
slave_net_timeout = 60
binlog_gtid_simple_recovery = 1
# slave_skip_errors = ddl_exist_errors
# replicate_wild_ignore_table = pt.%
slave_parallel_type = LOGICAL_CLOCK
slave_preserve_commit_order = 1
slave_transaction_retries = 128
slave_parallel_workers = 8
# slave_rows_search_algorithms = 'INDEX_SCAN,HASH_SCAN'
master_info_repository = TABLE
relay_log_info_repository = TABLE
########semi sync replication settings########
plugin_dir=$mysql_install_dir/lib/plugin
plugin_load = "rpl_semi_sync_master=semisync_master.so;rpl_semi_sync_slave=semisync_slave.so"
loose-rpl_semi_sync_master_enabled = 1
loose-rpl_semi_sync_slave_enabled = 1
loose-rpl_semi_sync_master_timeout = 5000
# report_host = 'xxx.xxx.xxx.xxx'
# report_port = $mysql_port
# GR # 
# 可去掉semi sync replication settings
# binlog_checksum = NONE
# transaction_write_set_extraction = XXHASH64
# loose-group_replication_group_name = "0b31a888-6c38-4950-83a3-6ed49325ae8d"
# # loose-group_replication_start_on_boot = off
# loose-group_replication_start_on_boot = on
# super_read_only = 1
# loose-group_replication_local_address = "192.168.1.181:23301"
# loose-group_replication_group_seeds = "192.168.1.181:23301,192.168.1.182:23301,192.168.1.183:23301"
# loose-group_replication_bootstrap_group = off
# loose-group_replication_single_primary_mode = FALSE
# auto_increment_offset = 3 # 1 2 3 4 5
# auto_increment_increment = 3 # 5
# loose-group_replication_auto_increment_increment = 3 # 5
# loose-group_replication_enforce_update_everywhere_checks = FALSE
# loose-group_replication_poll_spin_loops = 10000
# loose-group_replication_flow_control_mode = DISABLED
# # group_replication_flow_control_mode = QUOTA
# # group_replication_flow_control_certifier_threshold = 25000
# # group_replication_flow_control_applier_threshold   = 25000
# loose-group_replication_transaction_size_limit = 209715200
# # loose-group_replication_compression_threshold = 2097152
# CACHES AND LIMITS #
tmp_table_size = 64M
max_heap_table_size = 64M
read_buffer_size = 8M
read_rnd_buffer_size = 16M
sort_buffer_size = 8M
join_buffer_size = 8M
tmpdir = $mysql_tmp_dir
query_cache_type = 0
query_cache_size = 0
max_connections = 2000
max_user_connections = 2000
max_connect_errors = 100000
thread_cache_size = 64
open_files_limit = 65000
table_definition_cache = 4096
table_open_cache = 4096
interactive_timeout = 4200
wait_timeout = 4200
lock_wait_timeout = 4200
# INNODB #
innodb_flush_method = O_DIRECT
innodb_file_per_table  = 1
innodb_data_file_path = ibdata1:1G;ibdata2:200M:autoextend
innodb_buffer_pool_size = ${buffer_pool_size}
innodb_buffer_pool_instances = 8
# metadata_locks_hash_instances = 8
innodb_buffer_pool_load_at_startup = 1
innodb_buffer_pool_dump_at_shutdown = 1
innodb_buffer_pool_dump_pct = 40
innodb_lru_scan_depth = 2048
innodb_lock_wait_timeout = 10
innodb_io_capacity = 2000
innodb_io_capacity_max = 4000
# innodb_file_format = Barracuda
# innodb_file_format_max = Barracuda
innodb_write_io_threads = 8
innodb_read_io_threads = 8
innodb_max_dirty_pages_pct = 60
innodb_undo_logs = 128
innodb_undo_tablespaces = 3
# innodb_undo_directory = /log/undo_$mysql_port/
innodb_undo_log_truncate  = 1
innodb_max_undo_log_size = 2G
innodb_purge_rseg_truncate_frequency = 128
innodb_autoinc_lock_mode = 2
innodb_thread_concurrency = 64
innodb_stats_persistent_sample_pages = 64
innodb_flush_neighbors = 0
# innodb_log_group_home_dir = /log/redo_$mysql_port/
innodb_log_files_in_group = 3
innodb_log_file_size = ${log_file_size}
innodb_log_buffer_size = 16M
innodb_sort_buffer_size = 64M
# innodb_log_block_size=4096
innodb_open_files = 4096
innodb_purge_threads = 4
innodb_large_prefix = 1
innodb_print_all_deadlocks = 1
innodb_strict_mode = 1
innodb_flush_log_at_trx_commit = 2 # 1
innodb_page_cleaners = 8
# innodb_online_alter_log_max_size=1G
# MyISAM #
key_buffer_size = 32M
myisam_recover_options = default
bulk_insert_buffer_size = 64M
myisam_sort_buffer_size = 8M
myisam_repair_threads = 1
# myisam_recover_options = 1
# LOGGING #
log_timestamps = SYSTEM
log_error = ${log_dir}/mysqld/mysqld_$mysql_port.log
slow_query_log_file = ${log_dir}/slow_$mysql_port/slow.log
slow_query_log = 1
# log_queries_not_using_indexes = 1
# log_throttle_queries_not_using_indexes = 10
log_slow_admin_statements = 1
log_slow_slave_statements = 1
long_query_time = 1
[mysqldump]
quick
max_allowed_packet = 64M
socket = $mysql_install_dir/mysql.sock
default_character_set = ${character_set}
#user = bk_user
#password =
[xtrabackup]
#user = bk_user
#password =
[myisamchk]
key_buffer_size = 16M
sort_buffer_size = 16M
[mysqlhotcopy]
interactive_timeout
[mysqld_safe]
user = mysql
basedir = $mysql_install_dir
pid-file = ${log_dir}/mysqld/mysqld_$mysql_port.pid
# malloc_lib
EOF

echo "`date '+%Y-%m-%d %H:%M:%S'`...... initialize " | tee -a $install_log
rm -f ${log_dir}/mysqld/mysqld_$mysql_port.log
$mysql_install_dir/bin/mysqld --defaults-file=$mysql_install_dir/my.cnf --user=mysql --basedir=$mysql_install_dir --initialize-insecure --datadir=$mysql_data_dir

mv /etc/my.cnf /etc/my.cnf.bak >/dev/null 2>&1

wait_for_init "${log_dir}/mysqld/mysqld_$mysql_port.log"

/etc/init.d/mysqld_$mysql_port start
[ -z "`grep ^'export PATH=' /etc/profile`" ] && echo "export PATH=$mysql_install_dir/bin:\$PATH" >> /etc/profile
[ -n "`grep ^'export PATH=' /etc/profile`" -a -z "`grep $mysql_install_dir /etc/profile`" ] && sed -i "s@^export PATH=\(.*\)@export PATH=$mysql_install_dir/bin:\1@" /etc/profile

source /etc/profile

wait_for_pid "${log_dir}/mysqld/mysqld_$mysql_port.pid"

$mysql_install_dir/bin/mysql -S $mysql_install_dir/mysql.sock -e "grant all privileges on *.* to root@'127.0.0.1' identified by \"$dbrootpwd\" with grant option;"
$mysql_install_dir/bin/mysql -S $mysql_install_dir/mysql.sock -e "grant all privileges on *.* to root@'localhost' identified by \"$dbrootpwd\" with grant option;flush privileges;"
$mysql_install_dir/bin/mysql -uroot -p$dbrootpwd -S $mysql_install_dir/mysql.sock -e "delete from mysql.user where user='' or authentication_string='';"
$mysql_install_dir/bin/mysql -uroot -p$dbrootpwd -S $mysql_install_dir/mysql.sock -e "delete from mysql.user where user='root' and host not in ('localhost', '127.0.0.1', '::1');"
$mysql_install_dir/bin/mysql -uroot -p$dbrootpwd -S $mysql_install_dir/mysql.sock -e "delete from mysql.proxies_priv where Host!='localhost';"
$mysql_install_dir/bin/mysql -uroot -p$dbrootpwd -S $mysql_install_dir/mysql.sock -e "grant all on *.* to dba_cm@'10.10.%' identified by \"$dbrootpwd\" with grant option;"
$mysql_install_dir/bin/mysql -uroot -p$dbrootpwd -S $mysql_install_dir/mysql.sock -e "flush privileges;"
$mysql_install_dir/bin/mysql -uroot -p$dbrootpwd -S $mysql_install_dir/mysql.sock -e "flush logs;reset master;"

rm -rf /etc/ld.so.conf.d/{mysql,mariadb,percona}*.conf
echo "$mysql_install_dir/lib" >> /etc/ld.so.conf.d/mysql-x86_64.conf
/sbin/ldconfig

echo "`date '+%Y-%m-%d %H:%M:%S'`...... service mysqld_${mysql_port} stop" | tee -a $install_log
service mysqld_$mysql_port stop
}

Install_Jemalloc
Install_Boost
Install_MySQL