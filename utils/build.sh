#!/usr/bin/env bash
set -o errexit

TGT="${1:-}"
TAG="${2:-$(git describe --first-parent 2>/dev/null || echo 'dev')}"
BUILD_DIR="$PWD/${BUILD_DIR:-build}"

usage() {
    cat <<EOF
This script cross-compiles the project to various target operating systems and
CPU architectures, then compresses the result into a release archive.

It expects to be executed from the project root directory.

Usage:
    $0 [target] [tag]

For android builds, ensure the appropriate NDK toolchain is in your PATH.
Starting with NDK r19, prebuilt toolchains can be found in the bundle under
\`toolchains/llvm/prebuilt/<host>/bin\`. For older NDKs, standalone toolchains
must be built using \`build/tools/make_standalone_toolchain.py\`.

Arguments:
    target      A name to use for the build output directory and as part of
                the archive name. If the name is known to this script, Go env
                vars will be set to cross-compile to that target. If empty
                then a default will be generated based on the Go env provided.

    tag         A name to use as part of the archive name. If empty then a
                default will be generated based on the current Git head.

Environment:
    BUILD_DIR   The directory in which to place artifacts. If empty then
                'build' will be used.

Known Targets:
$(sed -r '/^([^() ]+)\) export .+$/!d;s//    \1/' "$0")
EOF
    exit 0
}

case "$TGT" in
-h | *help | *usage) usage ;;
win32) export GOOS=windows GOARCH=386 ;;
win64) export GOOS=windows GOARCH=amd64 ;;
linux-i386) export GOOS=linux GOARCH=386 ;;
linux-x86_64) export GOOS=linux GOARCH=amd64 ;;
linux-arm) export GOOS=linux GOARCH=arm ;;
linux-arm64) export GOOS=linux GOARCH=arm64 ;;
linux-mips) export GOOS=linux GOARCH=mips GOMIPS=softfloat ;;
linux-mipsle) export GOOS=linux GOARCH=mipsle GOMIPS=softfloat ;;
linux-mips64) export GOOS=linux GOARCH=mips64 ;;
linux-mips64le) export GOOS=linux GOARCH=mips64le ;;
openbsd-i386) export GOOS=openbsd GOARCH=386 GO386=387 ;;
openbsd-amd64) export GOOS=openbsd GOARCH=amd64 ;;
freebsd-i386) export GOOS=freebsd GOARCH=386 ;;
freebsd-amd64) export GOOS=freebsd GOARCH=amd64 ;;
freebsd-arm) export GOOS=freebsd GOARCH=arm ;;
freebsd-armv7) export GOOS=freebsd GOARCH=arm GOARM=7 ;;
dragonflybsd-amd64) export GOOS=dragonfly GOARCH=amd64 ;;
netbsd-i386) export GOOS=netbsd GOARCH=386 ;;
netbsd-amd64) export GOOS=netbsd GOARCH=amd64 ;;
solaris-amd64) export GOOS=solaris GOARCH=amd64 ;;
macos) export GOOS=darwin GOARCH=amd64 ;;
android-arm) export GOOS=android GOARCH=arm GOARM=7 CGO_ENABLED=1 ;;
android-arm64) export GOOS=android GOARCH=arm64 CGO_ENABLED=1 ;;
android-i386) export GOOS=android GOARCH=386 CGO_ENABLED=1 ;;
android-x86_64) export GOOS=android GOARCH=amd64 CGO_ENABLED=1 ;;
'') TGT="$(go env GOOS)-$(go env GOARCH)" ;;
*) echo 'Specified target unrecognised, leaving Go env alone.' ;;
esac

[ "${CGO_ENABLED+ok}" ] || export CGO_ENABLED=0
if [ "$GOOS" = 'android' ] && [[ -z "$CC" || -z "$CXX" ]]; then
    [ -n "$ANDROID_HOME" ] && [ -d "$ANDROID_HOME/ndk-bundle/toolchains/llvm/prebuilt/linux-x86_64/bin" ] &&
        export PATH="$ANDROID_HOME/ndk-bundle/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"
    ndk_cc=()
    case "$GOARCH" in
    arm) ndk_cc=('armv7a-linux-androideabi19-clang' 'arm-linux-androideabi-clang') ;;
    arm64) ndk_cc=('aarch64-linux-android21-clang' 'aarch64-linux-android-clang') ;;
    386) ndk_cc=('i686-linux-android19-clang' 'i686-linux-android-clang') ;;
    amd64) ndk_cc=('x86_64-linux-android21-clang' 'x86_64-linux-android-clang') ;;
    esac
    for cc in "${ndk_cc[@]}"; do
        builtin type -P "$cc" "$cc++" &>/dev/null && export CC="$cc" CXX="$cc++" && break
    done
fi

mkdir -p "$BUILD_DIR/$TGT"
go build -o "$BUILD_DIR/$TGT" -ldflags="-s -w" ./...
file "$BUILD_DIR/$TGT"/*

if [ "$GOOS" = 'windows' ]; then
    cp -t "$BUILD_DIR/$TGT" LICENSE dnscrypt-proxy/example-*.{toml,txt}
    #for i in "$BUILD_DIR/$TGT"/LICENSE "$BUILD_DIR/$TGT"/*.{toml,txt}; do ex -bsc '%!awk "{sub(/$/,\"\r\")}1"' -cx "$i"; done
    ln -t "$BUILD_DIR/$TGT" windows/*
else
    ln -t "$BUILD_DIR/$TGT" LICENSE dnscrypt-proxy/example-*.{toml,txt}
fi

cd "$BUILD_DIR"
case "$GOOS" in
windows | android)
    zip -9 -r dnscrypt-proxy-"$TGT"-"$TAG".zip ./"$TGT"
    ;;
*)
    tar czpvf dnscrypt-proxy-"$TGT"-"$TAG".tar.gz ./"$TGT"
    ;;
esac
rm -rf ./"$TGT"
