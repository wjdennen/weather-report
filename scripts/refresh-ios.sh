#!/bin/bash
# Rebuild the iPhone app and reinstall it over Wi-Fi/USB, so the free Apple ID's 7-day signing never lapses.
# Run by hand (add --force to skip the age check) or from the launchd agent (see scripts/README-refresh.md).
#
#   DEVICE   iPhone identifier from `xcrun devicectl list devices` (default below)
#   MAX_AGE  only reinstall if the last successful install is older than this many days (default 3)
#   PROFILE_MAX_AGE_HOURS  cached provisioning profiles older than this are deleted so Xcode issues new
#            7-day ones (default 24). Xcode otherwise REUSES an existing profile until it is nearly expired,
#            so a plain rebuild does not extend the app's life.

set -uo pipefail

DEVICE="${DEVICE:-00008140-000661A93EE8801C}"
MAX_AGE_DAYS="${MAX_AGE:-3}"
PROFILE_MAX_AGE_HOURS="${PROFILE_MAX_AGE_HOURS:-24}"
PROFILES="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
BUNDLE_PREFIX="com.wjdennen.weatherreport.ios"
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

# Prints a provisioning-profile field (Name, CreationDate, ExpirationDate, ...) from a .mobileprovision file.
profile_field() { security cms -D -i "$1" 2>/dev/null | plutil -extract "$2" raw - 2>/dev/null; }
# Seconds since an ISO UTC timestamp like 2026-10-04T14:16:54Z.
age_seconds() { echo $(( $(date +%s) - $(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s) )); }

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

# Drop stale cached profiles for this app so the build below gets brand-new 7-day ones.
for f in "$PROFILES"/*.mobileprovision; do
  [ -f "$f" ] || continue
  case "$(profile_field "$f" Entitlements.application-identifier)" in
    *."$BUNDLE_PREFIX"|*."$BUNDLE_PREFIX".*) ;;
    *) continue ;;
  esac
  created="$(profile_field "$f" CreationDate)"
  if [ -n "$created" ] && [ "$(age_seconds "$created")" -gt $(( PROFILE_MAX_AGE_HOURS * 3600 )) ]; then
    log "removing stale profile ($created): $(profile_field "$f" Name)"
    rm -f "$f"
  fi
done

cd "$REPO/macos-widget" || fail "repo not found at $REPO"
log "building for $DEVICE"
xcodegen -q >>"$LOG" 2>&1 || fail "xcodegen failed (see $LOG)"

xcodebuild -project WeatherReport.xcodeproj -scheme WeatherReportiOS \
  -destination "id=$DEVICE" -configuration Release \
  -derivedDataPath "$BUILD" -allowProvisioningUpdates build >>"$LOG" 2>&1 \
  || fail "build/signing failed (see $LOG)"

APP="$BUILD/Build/Products/Release-iphoneos/WeatherReportiOS.app"
[ -d "$APP" ] || fail "built app not found"

# Make sure the build really carries fresh profiles (app and widget), otherwise it would still expire early.
for embedded in "$APP/embedded.mobileprovision" "$APP"/PlugIns/*.appex/embedded.mobileprovision; do
  [ -f "$embedded" ] || fail "no embedded provisioning profile in $embedded"
  created="$(profile_field "$embedded" CreationDate)"
  [ "$(age_seconds "$created")" -le $(( PROFILE_MAX_AGE_HOURS * 3600 )) ] \
    || fail "profile was not renewed (created $created). Open Xcode > Settings > Accounts and check the Apple ID."
  log "profile OK: $(profile_field "$embedded" Name) expires $(profile_field "$embedded" ExpirationDate)"
done

log "installing"
xcrun devicectl device install app --device "$DEVICE" "$APP" >>"$LOG" 2>&1 \
  || fail "install failed; is the phone unlocked? (see $LOG)"

touch "$STATE"
log "installed OK"
