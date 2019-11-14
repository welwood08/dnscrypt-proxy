#!/usr/bin/env bash
# This script cross-compiles the package to various target
# operating systems and CPU architectures, then compresses
# the result into a release archive.
#
# It expects to be executed from the project root directory.
set -ev

if [ -z "$TGT" ]; then
    echo >&2 "\$TGT cannot be empty" && exit 1
fi
BUILD_DIR="${BUILD_DIR:-build}"
mkdir -p "$BUILD_DIR/$TGT"
go build -mod vendor -ldflags="-s -w" -o "$BUILD_DIR/$TGT" ./...
file "$BUILD_DIR/$TGT"/*
if [ "$GOOS" = 'windows' ]; then
    cp LICENSE dnscrypt-proxy/example-*.{toml,txt} "$BUILD_DIR/$TGT"/
    for i in "$BUILD_DIR/$TGT"/LICENSE "$BUILD_DIR/$TGT"/*.{toml,txt}; do ex -bsc '%!awk "{sub(/$/,\"\r\")}1"' -cx "$i"; done
    ln windows/* "$BUILD_DIR/$TGT"/
else
    ln LICENSE dnscrypt-proxy/example-*.{toml,txt} "$BUILD_DIR/$TGT"/
fi
cd "$BUILD_DIR"
case "$GOOS" in
windows | android)
    zip -9 -r dnscrypt-proxy-"$TGT"-"${TRAVIS_TAG:-dev}".zip "$TGT"
    ;;
*)
    tar czpvf dnscrypt-proxy-"$TGT"-"${TRAVIS_TAG:-dev}".tar.gz "$TGT"
    ;;
esac
rm -rf "$TGT"
