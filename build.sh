#!/bin/sh
BUILD_TIME=$(date -u +'%b %d %H:%M UTC')
sed -i "s/__BUILD_TIME__/${BUILD_TIME}/g" public/index.html
