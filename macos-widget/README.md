# macOS desktop widget

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
