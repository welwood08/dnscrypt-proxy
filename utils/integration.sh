#!/usr/bin/env bash
set -o errexit

#for f in ${{ matrix.artifact }}/*; do case "$f" in *.zip) unzip "$f" ;; *gz) tar xzvf "$f" ;; esac done
ls -l build
#for f in ${{ matrix.artifact }}/dnscrypt-proxy{,.exe}; do [ -x "$f" ] || continue; "$f" -version; done
