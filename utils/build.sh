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
mkdir -p build/"$TGT"
go build -mod vendor -ldflags="-s -w" -o build/"$TGT" ./...
file build/"$TGT"/*
if [ "$GOOS" = 'windows' ]; then
    cp LICENSE dnscrypt-proxy/example-*.{toml,txt} build/"$TGT"/
    for i in build/"$TGT"/LICENSE build/"$TGT"/*.{toml,txt}; do ex -bsc '%!awk "{sub(/$/,\"\r\")}1"' -cx "$i"; done
    ln windows/* build/"$TGT"/
else
    ln LICENSE dnscrypt-proxy/example-*.{toml,txt} build/"$TGT"/
fi
cd build
case "$GOOS" in
windows | android)
    zip -9 -r dnscrypt-proxy-"$TGT"-"${TRAVIS_TAG:-dev}".zip "$TGT"
    ;;
*)
    tar czpvf dnscrypt-proxy-"$TGT"-"${TRAVIS_TAG:-dev}".tar.gz "$TGT"
    ;;
esac
rm -rf "$TGT"
