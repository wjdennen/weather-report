#!/bin/bash
# Rebuild the iPhone app and reinstall it over Wi-Fi/USB, so the free Apple ID's 7-day signing never lapses.
# Run by hand (add --force to skip the age check) or from the launchd agent (see scripts/README-refresh.md).
#
#   DEVICE   iPhone identifier from `xcrun devicectl list devices` (default below)
#   MAX_AGE  only reinstall if the last successful install is older than this many days (default 3)

set -uo pipefail

DEVICE="${DEVICE:-00008140-000661A93EE8801C}"
MAX_AGE_DAYS="${MAX_AGE:-3}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
STATE="$HOME/.weather-report-last-install"
LOG="$HOME/Library/Logs/weather-report-refresh.log"
BUILD="$HOME/Library/Caches/weather-report-ios-build"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

mkdir -p "$(dirname "$LOG")"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; echo "$*"; }
fail() {
  log "FAILED: $*"
  osascript -e "display notification \"$*\" with title \"Weather Report refresh failed\"" 2>/dev/null
  exit 1
}

if [ "${1:-}" != "--force" ] && [ -f "$STATE" ]; then
  age_days=$(( ( $(date +%s) - $(stat -f %m "$STATE") ) / 86400 ))
  if [ "$age_days" -lt "$MAX_AGE_DAYS" ]; then
    log "skip: last install ${age_days}d ago (< ${MAX_AGE_DAYS}d)"
    exit 0
  fi
fi

# Is the phone reachable right now? (On Wi-Fi it must be awake and on the same network.)
if ! xcrun devicectl list devices 2>/dev/null | grep "$DEVICE" | grep -q connected; then
  fail "iPhone not reachable. Unlock it and join the same Wi-Fi as the Mac."
fi

cd "$REPO/macos-widget" || fail "repo not found at $REPO"
log "building for $DEVICE"
xcodegen -q >>"$LOG" 2>&1 || fail "xcodegen failed (see $LOG)"

xcodebuild -project WeatherReport.xcodeproj -scheme WeatherReportiOS \
  -destination "id=$DEVICE" -configuration Release \
  -derivedDataPath "$BUILD" -allowProvisioningUpdates build >>"$LOG" 2>&1 \
  || fail "build/signing failed (see $LOG)"

APP="$BUILD/Build/Products/Release-iphoneos/WeatherReportiOS.app"
[ -d "$APP" ] || fail "built app not found"

log "installing"
xcrun devicectl device install app --device "$DEVICE" "$APP" >>"$LOG" 2>&1 \
  || fail "install failed; is the phone unlocked? (see $LOG)"

touch "$STATE"
log "installed OK"
