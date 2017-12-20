#!/bin/bash


# 日志文件目录
LOG_DIR=.


# 生成android id
sh gen_data2-1.sh -a 20000000 > $LOG_DIR/aid.log 2> $LOG_DIR/aid.err


# 生成新增
sh gen_data2.sh -a adv_n,20160315,20170531 > $LOG_DIR/adv_n.log.1 2> $LOG_DIR/adv_n.err.1
sh gen_data2.sh -a compass_n,20161010,20170531 > $LOG_DIR/compass_n.log.1 2> $LOG_DIR/compass_n.err.1
sh gen_data2.sh -a file_n,20160425,20170531 > $LOG_DIR/file_n.log.1 2> $LOG_DIR/file_n.err.1
sh gen_data2.sh -a light_n,20160727,20170531 > $LOG_DIR/light_n.log.1 2> $LOG_DIR/light_n.err.1
sh gen_data2.sh -a recorder_n,20160315,20170531 > $LOG_DIR/recorder_n.log.1 2> $LOG_DIR/recorder_n.err.1
sh gen_data2.sh -a search_n,20170123,20170531 > $LOG_DIR/search_n.log.1 2> $LOG_DIR/search_n.err.1
sh gen_data2.sh -a shop_n,20170501,20170531 > $LOG_DIR/shop_n.log.1 2> $LOG_DIR/shop_n.err.1
sh gen_data2.sh -a weather_n,20160801,20170531 > $LOG_DIR/weather_n.log.1 2> $LOG_DIR/weather_n.err.1


# 生成活跃
sh gen_data2.sh -b adv_n,20160315,20170531 > $LOG_DIR/adv_n.log.2 2> $LOG_DIR/adv_n.err.2 &
sh gen_data2.sh -b compass_n,20161010,20170531 > $LOG_DIR/compass_n.log.2 2> $LOG_DIR/compass_n.err.2 &
sh gen_data2.sh -b file_n,20160425,20170531 > $LOG_DIR/file_n.log.2 2> $LOG_DIR/file_n.err.2 &
sh gen_data2.sh -b light_n,20160727,20170531 > $LOG_DIR/light_n.log.2 2> $LOG_DIR/light_n.err.2 &
sh gen_data2.sh -b recorder_n,20160315,20170531 > $LOG_DIR/recorder_n.log.2 2> $LOG_DIR/recorder_n.err.2 &
sh gen_data2.sh -b search_n,20170123,20170531 > $LOG_DIR/search_n.log.2 2> $LOG_DIR/search_n.err.2 &
sh gen_data2.sh -b shop_n,20170501,20170531 > $LOG_DIR/shop_n.log.2 2> $LOG_DIR/shop_n.err.2 &
sh gen_data2.sh -b weather_n,20160801,20170531 > $LOG_DIR/weather_n.log.2 2> $LOG_DIR/weather_n.err.2 &


# 等待所有活跃生成完
wait


# 生成访问日志
sh gen_data2-1.sh -b adv_n,20160315,20170531,check > $LOG_DIR/adv_n.log.3 2> $LOG_DIR/adv_n.err.3 &
sh gen_data2-1.sh -b compass_n,20161010,20170531,check > $LOG_DIR/compass_n.log.3 2> $LOG_DIR/compass_n.err.3 &
sh gen_data2-1.sh -b file_n,20160425,20170531,check > $LOG_DIR/file_n.log.3 2> $LOG_DIR/file_n.err.3 &
sh gen_data2-1.sh -b light_n,20160727,20170531,check > $LOG_DIR/light_n.log.3 2> $LOG_DIR/light_n.err.3 &
sh gen_data2-1.sh -b recorder_n,20160315,20170531,check > $LOG_DIR/recorder_n.log.3 2> $LOG_DIR/recorder_n.err.3 &
sh gen_data2-1.sh -b search_n,20170123,20170531,check > $LOG_DIR/search_n.log.3 2> $LOG_DIR/search_n.err.3 &
sh gen_data2-1.sh -b shop_n,20170501,20170531,check > $LOG_DIR/shop_n.log.3 2> $LOG_DIR/shop_n.err.3 &
sh gen_data2-1.sh -b weather_n,20160801,20170531,check > $LOG_DIR/weather_n.log.3 2> $LOG_DIR/weather_n.err.3 &


# 统计报表数据
sh load_active2.sh adv_n 20160315 20170531 > $LOG_DIR/adv_n.log.4 2> $LOG_DIR/adv_n.err.4 &
sh load_active2.sh compass_n 20161010 20170531 > $LOG_DIR/compass_n.log.4 2> $LOG_DIR/compass_n.err.4 &
sh load_active2.sh file_n 20160425 20170531 > $LOG_DIR/file_n.log.4 2> $LOG_DIR/file_n.err.4 &
sh load_active2.sh light_n 20160727 20170531 > $LOG_DIR/light_n.log.4 2> $LOG_DIR/light_n.err.4 &
sh load_active2.sh recorder_n 20160315 20170531 > $LOG_DIR/recorder_n.log.4 2> $LOG_DIR/recorder_n.err.4 &
sh load_active2.sh search_n 20170123 20170531 > $LOG_DIR/search_n.log.4 2> $LOG_DIR/search_n.err.4 &
sh load_active2.sh shop_n 20170501 20170531 > $LOG_DIR/shop_n.log.4 2> $LOG_DIR/shop_n.err.4 &
sh load_active2.sh weather_n 20160801 20170531 > $LOG_DIR/weather_n.log.4 2> $LOG_DIR/weather_n.err.4 &


wait
# 删除空文件
find . -maxdepth 1 -name "*.err" -type f -size 0 -delete
