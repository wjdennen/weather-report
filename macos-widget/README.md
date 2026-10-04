# macOS + iPhone/CarPlay widget

Native WidgetKit widget (small / medium / large) using the same free APIs as the web app:
Open-Meteo (forecast + city geocoding), Zippopotam (US zip), NWS (alerts). Same WMO condition table
and wind/gust rules (gust shown at +10 mph, amber 30+, red 45+).

## Build

Requires full Xcode (not just Command Line Tools) and a free Apple ID signed in under Xcode > Settings > Accounts.

```
brew install xcodegen
cd macos-widget
xcodegen            # generates WeatherReport.xcodeproj
open WeatherReport.xcodeproj
```

In Xcode, select both targets > Signing & Capabilities > Team = your Personal Team, then Run the
`WeatherReport` scheme once. Then right-click the desktop > Edit Widgets > Weather Report.
Right-click the widget > Edit Widget to set the city or zip (default: New York).

Sources are typechecked with `swiftc -typecheck`; it has not been built or run in Xcode yet.

## iPhone and CarPlay

The same widget sources also build as an iPhone app + widget (`WeatherReportiOS` scheme, iOS 17+).
CarPlay (iOS 26+) shows any iPhone widget's `systemSmall` family, so no CarPlay entitlement is needed.
Build and run `WeatherReportiOS` on your iPhone (free Apple ID works; builds expire after 7 days, and
the phone needs Developer Mode on under Settings > Privacy & Security). Then:

- Home Screen: touch and hold > + > Weather Report; touch and hold the widget > Edit Widget for the city or zip.
- CarPlay: iPhone Settings > General > CarPlay > your car > Customize, add Weather Report.

Test without a car using the CarPlay Simulator (macOS, from "Additional Tools for Xcode") with the phone on USB.
The iPhone app itself is a full-screen web view of https://weather.dennen.dev (location prompts use the app's location permission).
The iOS targets were verified to compile for the simulator, but have not been run on a device or in CarPlay.
