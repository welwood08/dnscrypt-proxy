#!/usr/bin/env bash
# This script cross-compiles the package to various target
# operating systems and CPU architectures, then compresses
# the result into a release archive.
#
# It expects to be executed from the project root directory.
set -ev

gimme --list
echo $TRAVIS_GO_VERSION
cd dnscrypt-proxy

go clean -mod vendor
env GOOS=windows GOARCH=386 go build -mod vendor -ldflags="-s -w"
mkdir win32
ln dnscrypt-proxy.exe win32/
cp ../LICENSE example-dnscrypt-proxy.toml example-*.txt win32/
for i in win32/LICENSE win32/*.toml win32/*.txt; do ex -bsc '%!awk "{sub(/$/,\"\r\")}1"' -cx "$i"; done
ln ../windows/* win32/
zip -9 -r dnscrypt-proxy-win32-${TRAVIS_TAG:-dev}.zip win32

go clean -mod vendor
env GOOS=windows GOARCH=amd64 go build -mod vendor -ldflags="-s -w"
mkdir win64
ln dnscrypt-proxy.exe win64/
cp ../LICENSE example-dnscrypt-proxy.toml example-*.txt win64/
for i in win64/LICENSE win64/*.toml win64/*.txt; do ex -bsc '%!awk "{sub(/$/,\"\r\")}1"' -cx "$i"; done
ln ../windows/* win64/
zip -9 -r dnscrypt-proxy-win64-${TRAVIS_TAG:-dev}.zip win64

go clean -mod vendor
env GO386=387 GOOS=openbsd GOARCH=386 go build -mod vendor -ldflags="-s -w"
mkdir openbsd-i386
ln dnscrypt-proxy openbsd-i386/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt openbsd-i386/
tar czpvf dnscrypt-proxy-openbsd_i386-${TRAVIS_TAG:-dev}.tar.gz openbsd-i386

go clean -mod vendor
env GOOS=openbsd GOARCH=amd64 go build -mod vendor -ldflags="-s -w"
mkdir openbsd-amd64
ln dnscrypt-proxy openbsd-amd64/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt openbsd-amd64/
tar czpvf dnscrypt-proxy-openbsd_amd64-${TRAVIS_TAG:-dev}.tar.gz openbsd-amd64

go clean -mod vendor
env GOOS=freebsd GOARCH=386 go build -mod vendor -ldflags="-s -w"
mkdir freebsd-i386
ln dnscrypt-proxy freebsd-i386/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt freebsd-i386/
tar czpvf dnscrypt-proxy-freebsd_i386-${TRAVIS_TAG:-dev}.tar.gz freebsd-i386

go clean -mod vendor
env GOOS=freebsd GOARCH=amd64 go build -mod vendor -ldflags="-s -w"
mkdir freebsd-amd64
ln dnscrypt-proxy freebsd-amd64/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt freebsd-amd64/
tar czpvf dnscrypt-proxy-freebsd_amd64-${TRAVIS_TAG:-dev}.tar.gz freebsd-amd64

go clean -mod vendor
env GOOS=freebsd GOARCH=arm go build -mod vendor -ldflags="-s -w"
mkdir freebsd-arm
ln dnscrypt-proxy freebsd-arm/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt freebsd-arm/
tar czpvf dnscrypt-proxy-freebsd_arm-${TRAVIS_TAG:-dev}.tar.gz freebsd-arm

go clean -mod vendor
env GOOS=freebsd GOARCH=arm GOARM=7 go build -mod vendor -ldflags="-s -w"
mkdir freebsd-armv7
ln dnscrypt-proxy freebsd-armv7/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt freebsd-armv7/
tar czpvf dnscrypt-proxy-freebsd_armv7-${TRAVIS_TAG:-dev}.tar.gz freebsd-armv7

go clean -mod vendor
env GOOS=dragonfly GOARCH=amd64 go build -mod vendor -ldflags="-s -w"
mkdir dragonflybsd-amd64
ln dnscrypt-proxy dragonflybsd-amd64/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt dragonflybsd-amd64/
tar czpvf dnscrypt-proxy-dragonflybsd_amd64-${TRAVIS_TAG:-dev}.tar.gz dragonflybsd-amd64

go clean -mod vendor
env GOOS=netbsd GOARCH=386 go build -mod vendor -ldflags="-s -w"
mkdir netbsd-i386
ln dnscrypt-proxy netbsd-i386/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt netbsd-i386/
tar czpvf dnscrypt-proxy-netbsd_i386-${TRAVIS_TAG:-dev}.tar.gz netbsd-i386

go clean -mod vendor
env GOOS=netbsd GOARCH=amd64 go build -mod vendor -ldflags="-s -w"
mkdir netbsd-amd64
ln dnscrypt-proxy netbsd-amd64/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt netbsd-amd64/
tar czpvf dnscrypt-proxy-netbsd_amd64-${TRAVIS_TAG:-dev}.tar.gz netbsd-amd64

go clean -mod vendor
env GOOS=solaris GOARCH=amd64 go build -mod vendor -ldflags="-s -w"
mkdir solaris-amd64
ln dnscrypt-proxy solaris-amd64/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt solaris-amd64/
tar czpvf dnscrypt-proxy-solaris_amd64-${TRAVIS_TAG:-dev}.tar.gz solaris-amd64

go clean -mod vendor
env CGO_ENABLED=0 GOOS=linux GOARCH=386 go build -mod vendor -ldflags="-s -w"
mkdir linux-i386
ln dnscrypt-proxy linux-i386/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt linux-i386/
tar czpvf dnscrypt-proxy-linux_i386-${TRAVIS_TAG:-dev}.tar.gz linux-i386

go clean -mod vendor
env CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -mod vendor -ldflags="-s -w"
mkdir linux-x86_64
ln dnscrypt-proxy linux-x86_64/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt linux-x86_64/
tar czpvf dnscrypt-proxy-linux_x86_64-${TRAVIS_TAG:-dev}.tar.gz linux-x86_64

go clean -mod vendor
env CGO_ENABLED=0 GOOS=linux GOARCH=arm go build -mod vendor -ldflags="-s -w"
mkdir linux-arm
ln dnscrypt-proxy linux-arm/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt linux-arm/
tar czpvf dnscrypt-proxy-linux_arm-${TRAVIS_TAG:-dev}.tar.gz linux-arm

go clean -mod vendor
env CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -mod vendor -ldflags="-s -w"
mkdir linux-arm64
ln dnscrypt-proxy linux-arm64/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt linux-arm64/
tar czpvf dnscrypt-proxy-linux_arm64-${TRAVIS_TAG:-dev}.tar.gz linux-arm64

go clean -mod vendor
env CGO_ENABLED=0 GOOS=linux GOARCH=mips GOMIPS=softfloat go build -mod vendor -ldflags="-s -w"
mkdir linux-mips
ln dnscrypt-proxy linux-mips/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt linux-mips/
tar czpvf dnscrypt-proxy-linux_mips-${TRAVIS_TAG:-dev}.tar.gz linux-mips

go clean -mod vendor
env CGO_ENABLED=0 GOOS=linux GOARCH=mipsle GOMIPS=softfloat go build -mod vendor -ldflags="-s -w"
mkdir linux-mipsle
ln dnscrypt-proxy linux-mipsle/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt linux-mipsle/
tar czpvf dnscrypt-proxy-linux_mipsle-${TRAVIS_TAG:-dev}.tar.gz linux-mipsle

go clean -mod vendor
env CGO_ENABLED=0 GOOS=linux GOARCH=mips64 go build -mod vendor -ldflags="-s -w"
mkdir linux-mips64
ln dnscrypt-proxy linux-mips64/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt linux-mips64/
tar czpvf dnscrypt-proxy-linux_mips64-${TRAVIS_TAG:-dev}.tar.gz linux-mips64

go clean -mod vendor
env CGO_ENABLED=0 GOOS=linux GOARCH=mips64le go build -mod vendor -ldflags="-s -w"
mkdir linux-mips64le
ln dnscrypt-proxy linux-mips64le/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt linux-mips64le/
tar czpvf dnscrypt-proxy-linux_mips64le-${TRAVIS_TAG:-dev}.tar.gz linux-mips64le

go clean -mod vendor
env GOOS=darwin GOARCH=amd64 go build -mod vendor -ldflags="-s -w"
mkdir macos
ln dnscrypt-proxy macos/
ln ../LICENSE example-dnscrypt-proxy.toml example-*.txt macos/
tar czpvf dnscrypt-proxy-macos-${TRAVIS_TAG:-dev}.tar.gz macos

go clean -mod vendor
env CC=arm-linux-androideabi-clang CXX=arm-linux-androideabi-clang++ CGO_ENABLED=1 GOOS=android GOARCH=arm GOARM=7 go build -mod vendor -ldflags="-s -w"
mkdir android-arm
ln dnscrypt-proxy android-arm/
cp ../LICENSE example-dnscrypt-proxy.toml example-*.txt android-arm/
zip -9 -r dnscrypt-proxy-android_arm-${TRAVIS_TAG:-dev}.zip android-arm

go clean -mod vendor
env CC=aarch64-linux-android-clang CXX=aarch64-linux-android-clang++ CGO_ENABLED=1 GOOS=android GOARCH=arm64 go build -mod vendor -ldflags="-s -w"
mkdir android-arm64
ln dnscrypt-proxy android-arm64/
cp ../LICENSE example-dnscrypt-proxy.toml example-*.txt android-arm64/
zip -9 -r dnscrypt-proxy-android_arm64-${TRAVIS_TAG:-dev}.zip android-arm64

go clean -mod vendor
env CC=i686-linux-android-clang CXX=i686-linux-android-clang++ CGO_ENABLED=1 GOOS=android GOARCH=386 go build -mod vendor -ldflags="-s -w"
mkdir android-i386
ln dnscrypt-proxy android-i386/
cp ../LICENSE example-dnscrypt-proxy.toml example-*.txt android-i386/
zip -9 -r dnscrypt-proxy-android_i386-${TRAVIS_TAG:-dev}.zip android-i386

go clean -mod vendor
env CC=x86_64-linux-android-clang CXX=x86_64-linux-android-clang++ CGO_ENABLED=1 GOOS=android GOARCH=amd64 go build -mod vendor -ldflags="-s -w"
mkdir android-x86_64
ln dnscrypt-proxy android-x86_64/
cp ../LICENSE example-dnscrypt-proxy.toml example-*.txt android-x86_64/
zip -9 -r dnscrypt-proxy-android_x86_64-${TRAVIS_TAG:-dev}.zip android-x86_64
