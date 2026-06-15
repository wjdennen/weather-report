#!/bin/sh
BUILD_TIME=$(date -u +'%b %d %H:%M UTC')
CACHE_VER=$(date -u +'%Y%m%d%H%M')
sed -i "s/__BUILD_TIME__/${BUILD_TIME}/g" public/index.html
sed -i "s/__CACHE_VER__/${CACHE_VER}/g" public/sw.js
