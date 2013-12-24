#!/bin/bash
#指定运行的脚本shell
#运行脚本要给用户执行权限
bakdir=/backup
month=`date +%m`
day=`date +%d`
year=`date +%Y`
hour=`date +%k`
min=`date +%M`

pre=$year-$month-$day-$hour-$min

path=$year$month$day
mkdir $bakdir/$path
#mkdir $bakdir/$dirname
#mkdir $bakdir/$dirname/conf
#mkdir $bakdir/$dirname/web
#mkdir $bakdir/$dirname/db

#echo $pre

#热备份数据库
#config
cp /etc/my.cnf $bakdir/$path/$pre-my.cnf

cd /usr/local/infobright
bin/mysqldump --opt test>$bakdir/$path/$pre-test.sql
#bin/mysqldump --opt -u root -p --password=1986 test>$bakdir/$dirname/db/test.sql
#mysqldump --opt -u zhy -p --password=1986 phpwind>$bakdir/$dirname/db/phpwind.sql
