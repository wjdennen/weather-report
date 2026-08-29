#!/bin/sh
BUILD_TIME=$(date -u +'%b %d %H:%M UTC')
CACHE_VER=$(date -u +'%Y%m%d%H%M')
BUILD_NUM=$(git rev-list --count HEAD)
sed -i "s/__BUILD_TIME__/${BUILD_TIME}/g" public/index.html
sed -i "s/__BUILD_NUM__/${BUILD_NUM}/g" public/index.html
sed -i "s/__CACHE_VER__/${CACHE_VER}/g" public/sw.js
