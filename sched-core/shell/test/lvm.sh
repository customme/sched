#!/bin/bash
#
# LV缩容扩容
# 日期: 2018-03-05


# 卷组VG
VG_NAME=centos

# 待缩容LV
LV_REDUCE=work
# 待缩容LV路径
LV_PATH_REDUCE=/dev/$VG_NAME/$LV_REDUCE
# 待缩容LV挂载点
LV_MOUNT_REDUCE=/work

# 待扩容LV
LV_EXTEND=root
# 待扩容LV路径
LV_PATH_EXTEND=/dev/$VG_NAME/$LV_EXTEND


# 缩容逻辑卷LV
#㈠ 查看文件系统
df -h
# 查看逻辑卷
lvs
lvdisplay
# 查看文件系统格式
cat /etc/fstab

#㈡ 卸载文件系统
umount $LV_MOUNT_REDUCE
# 查看目录下被打开的文件
lsof +D $LV_MOUNT_REDUCE

#㈢ 查看文件系统是否卸载成功
mount | grep $LV_MOUNT_REDUCE

# 格式化LV
mkfs.ext4 $LV_PATH_REDUCE

#㈣ 进行磁盘检查
e2fsck -f $LV_PATH_REDUCE

#㈤ 调整文件系统大小
resize2fs $LV_PATH_REDUCE 450G

#㈥ 缩容逻辑卷LV
lvreduce -L -350G $LV_PATH_REDUCE

#㈦ 重新挂载
mount $LV_PATH_REDUCE $LV_MOUNT_REDUCE

#㈧ 查看文件系统
df -h
lvs
lvdisplay


# 扩容逻辑卷LV
#㈠ 查看VG（确保VG中有足够的空闲空间）
vgs

#㈡ 扩容LV
lvextend -L +350G $LV_PATH_EXTEND

#㈢ 查看扩容后的LV
lvdisplay

#㈣ 更新文件系统
xfs_growfs $LV_PATH_EXTEND

#㈤ 查看更新后的文件系统
df -h
