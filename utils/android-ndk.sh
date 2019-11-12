#!/usr/bin/env bash
# This script prepares a set of standalone Android NDK
# toolchains which are required by the Android build jobs.
set -ev

NDK_VER=r18
curl -LO http://dl.google.com/android/repository/android-ndk-${NDK_VER}-linux-x86_64.zip
unzip -q android-ndk-${NDK_VER}-linux-x86_64.zip -d $HOME
rm android-ndk-${NDK_VER}-linux-x86_64.zip
NDK_TOOLS=$HOME/android-ndk-${NDK_VER}
NDK_STANDALONE=$HOME/ndk-standalone-${NDK_VER}
MAKE_TOOLCHAIN=$NDK_TOOLS/build/tools/make_standalone_toolchain.py
for arch in x86 arm; do
    python $MAKE_TOOLCHAIN --arch $arch --api 19 --install-dir $NDK_STANDALONE/$arch
    NDK_PATH=$NDK_PATH:$NDK_STANDALONE/$arch/bin
done
for arch in x86_64 arm64; do
    python $MAKE_TOOLCHAIN --arch $arch --api 21 --install-dir $NDK_STANDALONE/$arch
    NDK_PATH=$NDK_PATH:$NDK_STANDALONE/$arch/bin
done
rm -rf $NDK_TOOLS
echo $NDK_PATH
