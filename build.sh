#!/bin/sh
BUILD_TIME=$(date -u +'%b %d %H:%M UTC')
CACHE_VER=$(date -u +'%Y%m%d%H%M')
# Cloudflare builds from a shallow clone, where the commit count is always 1
if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
  git fetch --unshallow --quiet || echo "warning: could not unshallow; build number will be wrong"
fi
BUILD_NUM=$(git rev-list --count HEAD)
sed -i "s/__BUILD_TIME__/${BUILD_TIME}/g" public/index.html
sed -i "s/__BUILD_NUM__/${BUILD_NUM}/g" public/index.html
sed -i "s/__CACHE_VER__/${CACHE_VER}/g" public/sw.js
