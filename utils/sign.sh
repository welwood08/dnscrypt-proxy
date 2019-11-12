#!/usr/bin/env bash
# This script signs release archives, usually called from
# Travis-CI's `before_deploy` job.
#
# It expects to be executed from the project root directory.
set -ev

mkdir -p /tmp/bin /tmp/lib /tmp/include
export LD_LIBRARY_PATH=/tmp/lib:LD_LIBRARY_PATH
export PATH=/tmp/bin:$PATH
git clone --depth 1 https://github.com/jedisct1/libsodium.git --branch=stable
cd libsodium
env ./configure --disable-dependency-tracking --prefix=/tmp
make -j$(nproc) install
cd -
git clone --depth 1 https://github.com/jedisct1/minisign.git
cd minisign/src
gcc -O2 -o /tmp/bin/minisign -I/tmp/include -L/tmp/lib *.c -lsodium
cd -
minisign -v
echo '#' >/tmp/minisign.key
echo "$MINISIGN_SK" >>/tmp/minisign.key
cd build
echo | minisign -s /tmp/minisign.key -Sm dnscrypt-proxy-*.tar.gz dnscrypt-proxy-*.zip
