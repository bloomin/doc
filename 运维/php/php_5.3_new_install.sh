#!/bin/bash
#@新安装5.3.27
#@ZCola
#@2013.08.11
#====================================================================================
# Variable Defs:
#====================================================================================
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#old_php_version=`/usr/local/php/bin/php -r 'echo PHP_VERSION;'`
php_version="5.3.27"

#====================================================================================
# Function Defs:
#====================================================================================


prepare_install() {
# Check if user is root
if [ $(id -u) != "0" ]; then
  echo "Error: You must be root to run this script, please use root to install"
  exit 1
fi

clear

#echo "Current PHP Version:$old_php_version"
#if [ "$php_version" == "$old_php_version" ]; then
#  echo "Error: The upgrade PHP Version is the same as the old Version!!"
#  exit 1
#fi
echo "=================================================="
echo "You want to install php  $php_version"
echo "=================================================="

if [ ! -d "/dist/src" ]  ; then mkdir -p /dist/{dist,src};fi
}

check_files() {
cd /dist/dist
if [ ! -f php-5.3.27.tar.gz ];then wget http://is1.php.net/distributions/php-5.3.27.tar.gz;fi
if [ ! -f libevent-0.0.5.tgz ];then wget http://pecl.php.net/get/libevent-0.0.5.tgz;fi
if [ ! -f inotify-0.1.6.tgz ];then wget http://pecl.php.net/get/inotify-0.1.6.tgz;fi
if [ ! -f APC-3.1.9.tgz ];then wget http://pecl.php.net/get/APC-3.1.9.tgz;fi
if [ ! -f memcache-2.2.7.tgz ];then wget -c http://pecl.php.net/get/memcache-2.2.7.tgz;fi
if [ ! -f memcached-1.0.2.tgz ];then wget -c http://pecl.php.net/get/memcached-1.0.2.tgz;fi
if [ ! -f libevent-0.0.5.tgz ];then wget -c http://pecl.php.net/get/libevent-0.0.5.tgz;fi
if [ ! -f nicolasff-phpredis-2.1.3-167-ga5e53f1.tar.gz ];then wget -c wget http://113.107.160.154/nicolasff-phpredis-2.1.3-167-ga5e53f1.tar.gz;fi
if [ ! -f php5327.ini ];then wget -c http://113.107.160.154/php5327.ini;fi
}


#backup_old() {
#Backup old php version configure files
#echo "Backup old php version configure files......"
#if [ -d "/usr/local/php/" ];then cp -R /usr/local/php/ /usr/local/php_bak/;\cp /etc/php.ini /usr/local/php_bak/etc/;fi
#}


php_install() {
  cd /dist/src
  echo "Starting install php......"
  tar xzf ../dist/php-5.3.27.tar.gz
  cd php-5.3.27

  CHOST="x86_64-pc-linux-gnu" CFLAGS="-march=nocona -O2 -pipe" CXXFLAGS="-march=nocona -O2 -pipe" \
    ./configure --prefix=/usr/local/php \
    --with-config-file-path=/usr/local/php/etc \
    --with-mysql=/usr/local/mysql --with-pdo-mysql=/usr/local/mysql/bin/mysql_config \
    --with-mysqli=/usr/local/mysql/bin/mysql_config \
    --with-iconv-dir=/usr/local \
    --with-freetype-dir --with-jpeg-dir \
    --with-png-dir \
    --enable-zip --with-zlib \
    --enable-xml \
    --enable-fpm \
    --with-gd \
    --enable-gd-native-ttf \
    --enable-pcntl \
    --disable-debug --disable-rpath \
    --enable-safe-mode --enable-bcmath \
    --enable-shmop --enable-sysvsem \
    --enable-inline-optimization \
    --with-curl --with-curlwrappers \
    --enable-mbregex \
    --enable-mbstring --with-mcrypt \
    --disable-ipv6 \
    --enable-static \
    --enable-maintainer-zts \
    --enable-zend-multibyte \
    --enable-sockets \
    --enable-soap \
    --with-openssl \
    --with-mhash \
    --without-sqlite --without-pdo-sqlite \
    --with-ldap --with-ldap-sasl \
    --with-xmlrpc \
    --with-libxml-dir=/usr

  make   || { echo "ERR: "; exit 1; }
  make install
  echo "Copy new php configure file."
  mkdir -p /usr/local/php/etc
  cp /dist/dist/php5327.ini /usr/local/php/etc/php5327.ini
  ln -s /usr/local/php/etc/php5327.ini /usr/local/php/etc/php.ini
  ln -s /etc/php.ini /usr/local/php/etc/php.ini
  cat >/usr/local/php/etc/php-fpm.conf<<EOF
[global]
pid = run/php-fpm.pid
error_log = log/php-fpm.log
 
[www]
user = www
group = www
listen = 127.0.0.1:9000
listen.owner = www
listen.group = www
 
pm = dynamic
pm.max_children = 64
pm.start_servers = 2
pm.min_spare_servers = 2
pm.max_spare_servers = 6
request_terminate_timeout = 180
EOF

cp /dist/src/php-5.3.27/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
chmod 755 /etc/init.d/php-fpm

sed -i "s#/usr/local/php/sbin/php-fpm#/etc/init.d/php-fpm#g" /root/fastcgi_*

}

php_ext_install() {
  #memcache
  cd /dist/src/
  rm -rf memcache-2.2.7
  tar zxf ../dist/memcache-2.2.7.tgz
  cd memcache-2.2.7/
  /usr/local/php/bin/phpize

  CHOST="x86_64-pc-linux-gnu" CFLAGS="-march=nocona -O2 -pipe" CXXFLAGS="-march=nocona -O2 -pipe" \
    ./configure --enable-memcache --with-php-config=/usr/local/php/bin/php-config
  make && make install

  #memcached
  cd /dist/src
  tar xzf ../dist/memcached-1.0.2.tgz 
  cd memcached-1.0.2
  /usr/local/php/bin/phpize 

  ./configure --enable-memcached --with-php-config=/usr/local/php/bin/php-config 
  make && make install
  #libevent
  cd /dist/src
  tar xzf ../dist/libevent-0.0.5.tgz 
  cd libevent-0.0.5
  /usr/local/php/bin/phpize
  ./configure --with-php-config=/usr/local/php/bin/php-config
  make && make install
  #phpredis
  cd /dist/src
  tar xzf ../dist/nicolasff-phpredis-2.1.3-167-ga5e53f1.tar.gz
  cd nicolasff-phpredis-a5e53f1
  /usr/local/php/bin/phpize
  ./configure --with-php-config=/usr/local/php/bin/php-config
  make && make install
  #inotify
  cd /dist/src
  tar xzf ../dist/inotify-0.1.6.tgz
  cd inotify-0.1.6
  /usr/local/php/bin/phpize
  ./configure --with-php-config=/usr/local/php/bin/php-config
  make && make install
  #apc，可以替换成o+
  cd /dist/src
  tar xzf ../dist/APC-3.1.9.tgz 
  cd APC-3.1.9
  /usr/local/php/bin/phpize
  ./configure --with-php-config=/usr/local/php/bin/php-config
  make && make install

}




#====================================================================================
# MAIN: 
#====================================================================================
prepare_install

check_files

#backup_old

php_install 

php_ext_install

pkill -9 php-cgi
sleep 1s
/root/fastcgi_start
 

