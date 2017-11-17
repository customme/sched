# shell技巧


# 求和
seq -s+ 1 10 | bc


# 打印从第一行到匹配行的上一行
sed '/match/,$d' data.txt
sed '/match/Q' data.txt


# 打印从匹配行到最后一行
sed -n '/match/,/$!/p' data.txt
sed -n '/match/,$p' data.txt


# 以空格为间隔，先按照第一个域的第2个字符开始，以第一个域的第2个字符结束排序，若相同，则再以第3个域开始，第3个域结束排序
sort -t ' ' -k 1.2,1.2 -k 3,3 data.txt

# 先按第二列排序，然后按第三列以数字降序排
sort -t ' ' -k 2 -k 3nr data.txt


#
seq 0 9


#
echo "zhangchao" | fold -w1


# 反转
echo "zhangchao" | rev

# 查看进程占用内存大小（USER PID %CPU %MEM RSS）
ps aux | awk 'BEGIN{OFS="\t"} NR > 1 {print $1,$2,$3,$4,$6}' | sort -k 4nr | head -n 10


# 目录大小监控
du -h --max-depth 1 /tmp/


# 查找大文件
find . -type f -size +800M


# 查看CPU个数
grep "physical id" /proc/cpuinfo | sort -u

# 查看CPU物理核个数
grep "cpu cores" /proc/cpuinfo | uniq

# 查看CPU逻辑核个数
grep "processor" /proc/cpuinfo | wc -l

# 查看CPU是否启用超线程
grep -e "cpu cores" -e "siblings" /proc/cpuinfo | sort -u
