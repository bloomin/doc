#!/bin/bash
# data:2012/09/13  @2012.11.08  @v0.5
#                  @2013.02.17  @v0.5.1
#                  @2013.04.15  修正单ip bug
#备份线上db和相关目录文件 并生成相关状态检测结果日志 
#异地同步到集中式备份存储 并做相关备份校验

################################################################################################
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
export PATH
CURDAY=`date "+%Y-%m-%d"`
# CURTIME=`date "+%Y-%m-%d %H:%M:%S"`
CURTIME=`date "+%Y%m%d-%H%M%S"`

#定义保留多少个备份
MAX_OLD_BACKUP=2
#项目名
PROJ_NAME=houtai
#代理名
AGENT=Scheduler
# 服名
GSNUM=db

#服务器IP
IP=$(ifconfig | grep "inet addr" | awk '{print $2;}' | cut -f2 -d":"| nali |grep '电信'|awk -F "[" '{print $1}')
#假设单ip nali数据不准没有抓到取第一个公网ip
if [ x${IP} = x"" ];then
IP=$(ifconfig | grep "inet addr" | awk '{print $2;}' | cut -f2 -d":"|grep -v 127.0.0.1|head -n1)
fi


#定义备份存放根目录
BACKUP_BASE_DIR="/data/backup/New_backup"
DAY_DIR=`date '+%Y%m%d-%H%M%S'`
BACKUP_DAY_DIR=${BACKUP_BASE_DIR}/${DAY_DIR}

#定义log文件名
LOG_FILE="${BACKUP_DAY_DIR}/${PROJ_NAME}_${AGENT}_${GSNUM}_${CURDAY}_${IP}.log"

#定义是否备份，如果为1则备份，0则不备份，默认为1
BACKUP_DIR=0
BACKUP_DB=1

#定义相关备份工具
MYSQLPASSWORD=`cat /data/save/mysql_root`
MYSQL="/usr/local/mysql/bin/mysql"
MYSQLADMIN="/usr/local/mysql/bin/mysqladmin"
MYSQLDUMP="/usr/local/mysql/bin/mysqldump"
SOCK="/tmp/mysql.sock"
#在5.5版本还要跳过performance_schema这个库 否则备份会出错
SKIP_DB="mysql|information_schema|test|performance_schema"
TABLES=""

#定义要备份的db
#DB_NAME=`${MYSQL} -uroot -p${MYSQLPASSWORD} -S${SOCK} -e"show databases;"|grep -v Database|grep -v -w -E "${SKIP_DB}"`
DB_NAME="ladder scheduler"

#定义要备份的目录
DATA_DIR="
/data/conf
"
###############################################################################################

#创建备份文件存放目录
if [ ! -d ${BACKUP_DAY_DIR} ]
then
    mkdir -p ${BACKUP_DAY_DIR}
        chown -R mysql:mysql ${BACKUP_DAY_DIR}
fi

#检查命令的退出状态函数
check_result()
{
        if [ $1 -eq 0 ]
        then
                #传参数给write_logs，第一个是日志类型，0代表True，其他代表False，最后第三个参数是日志内容
                write_logs "progress" "0" $2 $3
        else 
                write_logs "progress" "1" $2 $3
        fi
}

#写日志函数
write_logs(){
#日志类型,progress代表是备份过程的状态检测,check_md5代表检查文件md5值
LOG_TYPE=$1
#状态
STATUS=$2
FILENAME=$3
shift
shift
shift
LOG_CONTENT=$*
echo "${CURTIME},${PROJ_NAME},${AGENT},${GSNUM},${IP},${LOG_TYPE},${STATUS},${FILENAME},${LOG_CONTENT}" >> ${LOG_FILE}
}

backup_file()
{
local prefix self

echo "do backup for $1"

  prefix=`dirname $1`
  self=`basename $1`
  
TARTIME=`date "+%Y%m%d-%H%M%S"`
BACKUPFILENAME=${PROJ_NAME}%${AGENT}%${GSNUM}%${self}%${TARTIME}.tar.gz

  if [ ! -z "$1" ] ; then
    cd ${prefix}
    tar zcf ${BACKUP_DAY_DIR}/${BACKUPFILENAME} ${self} --exclude="*.log"
        check_result $? ${BACKUPFILENAME} "dump"
		check_result $? ${BACKUPFILENAME} "tar"
  fi

}

backup_db(){
echo "do backup for $1"

BACKUPDIR="${BACKUP_DAY_DIR}/$1-${CURTIME}"
mkdir -p ${BACKUPDIR}
chown -R mysql:mysql ${BACKUP_DAY_DIR}
cd ${BACKUP_DAY_DIR}

TARTIME=`date "+%Y%m%d-%H%M%S"`
BACKUPFILENAME="${PROJ_NAME}%${AGENT}%${GSNUM}%$1%${TARTIME}.tar.gz"

# 只导出整个数据库结构，不包括内容
${MYSQLADMIN} -uroot -p${MYSQLPASSWORD} -S${SOCK} flush-log
${MYSQLDUMP} -uroot -p${MYSQLPASSWORD} -S${SOCK} -d $1 > "${BACKUPDIR}/$1_db_struc.sql"
# 以 txt 文件的方式分表导出数据
${MYSQLDUMP} -uroot -p${MYSQLPASSWORD} -S${SOCK} --single-transaction -T${BACKUPDIR}  $1 ${TABLES}
# check_result $? "$1 dump txt"
check_result $? "$1 dump"
# 打包导出的数据
/bin/tar zcf ${BACKUP_DAY_DIR}/${BACKUPFILENAME} $1-${CURTIME}
check_result $? ${BACKUPFILENAME} "tar"
/bin/rm -rf $1-${CURTIME}

}

if [ "G${BACKUP_DIR}" == "G1" ]
then
for data in ${DATA_DIR}
do
    backup_file ${data}
done
fi

if [ "G${BACKUP_DB}" == "G1" ]
then
for db in ${DB_NAME}
do
    backup_db ${db}
done
fi

if cd ${BACKUP_DAY_DIR}/
then
for file in `ls *.tar.*`
do 
        md5_value=`/usr/bin/md5sum ${file} |awk '{print $1}'`
        file_size=`/bin/ls -l ${file} |awk '{print $5}'`
        write_logs "check_md5" "0" "${file}" "${file_size},${md5_value}"
done
fi

# clean old backup
if [ -d ${BACKUP_BASE_DIR} ]
then
/usr/bin/find ${BACKUP_BASE_DIR} -type d -name "20*" -mtime +${MAX_OLD_BACKUP} |xargs -r /bin/rm -rf
fi 
