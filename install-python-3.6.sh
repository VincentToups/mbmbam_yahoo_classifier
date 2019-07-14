#!/bin/bash

wget http://www.python.org/ftp/python/3.6.1/Python-3.6.1.tgz
tar zxvf Python-3.6.1.tgz
cd Python-3.6.1
./configure --enable-loadable-sqlite-extensions
make
yum install zlib-devel
make install
export PATH=$PATH:/usr/local/bin/python3
