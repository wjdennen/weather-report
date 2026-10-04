# Native apps: macOS widget + iPhone app (CarPlay-ready)

Two native targets built from one XcodeGen project, using the same free data sources as the web app:
Open-Meteo (forecast, geocoding), Zippopotam (US zip), NOAA NWS (text forecast, alerts), NOAA CO-OPS (tides),
and the web app's Worker proxy for Sunsethue sunset quality. Same WMO condition table and wind/gust rules
(gust shown at +10 mph, amber 30+, red 45+).

| Target | What it is |
|---|---|
| `WeatherReport` + `WeatherWidgetExtension` | macOS app that hosts a small / medium / large desktop widget |
| `WeatherReportiOS` + `WeatherWidgetExtensioniOS` | Native SwiftUI iPhone app and its Home Screen / CarPlay widget (iOS 17+) |

## Layout of the code

```
WeatherWidget/          Widget views + shared logic (used by BOTH platforms)
  WeatherService.swift    Forecast, geocoding, alerts, tides, sunset fetch (widget's slimmer fetch)
  WMO.swift               Condition text/icons/backgrounds, wind formatting
  Beaches.swift           Beach pick (Aquidneck Island / Little Compton, RI)
  TideStatus.swift        "Rising · nearly high" style status
  WeatherWidget.swift     Widget timeline + small/medium/large views (iOS gets a more compact large layout)
WeatherReportApp/       macOS host app (just explains how to add the widget)
WeatherReportApp-iOS/   Native iPhone app (SwiftUI)
  Models.swift, AppService.swift   Richer fetch for the app screen (humidity, UV, NWS text, tide events, ...)
  Store.swift                      State: GPS, saved locations, loading/refresh
  HomeView.swift, HomeSections.swift, SkySections.swift, LocationsView.swift
  Assets.xcassets                  App icon and launch background
WeatherWidget-iOS/      Info.plist for the iOS widget extension
project.yml             XcodeGen spec (the .xcodeproj is generated and gitignored)
```

The iPhone app compiles `WeatherService.swift`, `WMO.swift`, `Beaches.swift` and `TideStatus.swift` straight from
`WeatherWidget/`, so a fix to the weather, tide or beach logic applies to the widget and the app.

## Build

Requires full Xcode (not just Command Line Tools) and a free Apple ID signed in under Xcode > Settings > Accounts.
If `xcrun` complains it can't find `simctl`/`devicectl`, point the tools at Xcode once:

```
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

```
brew install xcodegen
cd macos-widget
xcodegen            # generates WeatherReport.xcodeproj (re-run after editing project.yml)
open WeatherReport.xcodeproj
```

Your Personal Team ID is set as `DEVELOPMENT_TEAM` in `project.yml`, so signing survives regenerating the project.
(Change it there if you use a different team.)

### macOS widget

Run the `WeatherReport` scheme once, then right-click the desktop > Edit Widgets > Weather Report.
Right-click the widget > Edit Widget to set the city or zip (default: New York).

### iPhone app

The app is a native SwiftUI app (no radar): GPS or searched locations (city or US zip), saved locations,
pull to refresh, the NWS alert banners, hero, 24-hour strip, NWS text forecast, conditions, beach pick,
7-day forecast with expandable NWS detail, sun (with sunset quality), moon and tides (next tide, curve,
upcoming list). It uses the web app's dark atmospheric backgrounds and is always dark.
Accessibility: VoiceOver labels, Dynamic Type layouts, Reduce Motion support.

1. Plug in the iPhone, unlock it, and turn on Developer Mode (Settings > Privacy & Security).
2. In Xcode, pick the `WeatherReportiOS` scheme and your iPhone, then Run. (Run only this scheme; it embeds the widget.)
3. Home Screen: touch and hold > + > Weather Report; touch and hold the widget > Edit Widget for the city or zip.
4. In Xcode > Window > Devices and Simulators, tick **Connect via network** to install later over Wi-Fi without a cable.

The widget and the app don't share data (App Groups need a paid account), so set the widget's location with Edit Widget.

### CarPlay

CarPlay (iOS 26+) shows any iPhone widget's `systemSmall` family; no CarPlay entitlement is needed.
Add it under iPhone Settings > General > CarPlay > your car > Customize. You can try it without a car using the
CarPlay Simulator (from "Additional Tools for Xcode") with the phone on USB. The small widget is not yet
laid out specially for the car, and CarPlay hasn't been tested yet.

## Keeping the iPhone app installed (free Apple ID)

Builds signed with a free Apple ID stop launching after 7 days. `scripts/refresh-ios.sh` rebuilds and reinstalls the
app (with `xcodebuild -allowProvisioningUpdates` and `devicectl`), which renews the signature:

```
./scripts/refresh-ios.sh --force      # run now
./scripts/refresh-ios.sh              # no-op unless the last install is 3+ days old (MAX_AGE=days to change)
```

It needs the Mac awake and the phone on the same Wi-Fi (an unlocked phone is not required). It logs to
`~/Library/Logs/weather-report-refresh.log` and posts a macOS notification on failure. The device ID defaults to
this project's phone; override with `DEVICE=<id>` (see `xcrun devicectl list devices`).

To run it automatically, create `~/Library/LaunchAgents/dev.dennen.weather-report-refresh.plist` (outside the repo,
so it isn't tracked) that runs `/bin/bash <repo>/scripts/refresh-ios.sh` daily at 10:00 and at login
(`StartCalendarInterval` Hour 10 / Minute 0, `RunAtLoad` true), then load it:

```
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.dennen.weather-report-refresh.plist
launchctl bootout gui/$(id -u)/dev.dennen.weather-report-refresh      # to turn it off
```

The installed build is whatever is in the working tree at that moment. If you're away from the Wi-Fi for over a
week, run the script by hand when you're back. A paid Apple Developer account ($99/yr) removes the limit.

## Status

- iOS app and widget: built, installed and run on an iPhone 16 Pro.
- macOS widget: compiles for macOS; hasn't been re-checked on the desktop since the iPhone work.
- Not yet tested: the widget in CarPlay.
