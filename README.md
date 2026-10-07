# Weather Report

A PWA weather app for current conditions, hourly forecasts, 7-day outlook, tides, and sun info — built by [Clam Code](https://github.com/wjdennen). Deployed on Cloudflare Pages.

## Features

- **Compact hero** — condition label + icon on the left, current temperature on the right; feels-like and hi/lo below
- **Hourly scroll** — 24-hour horizontal chip strip with animated TODAY/TOMORROW/day-name label; precip probability shown as a fill bar (width = probability, color intensity = expected amount) plus a percentage label when above 0%; wind line per hour (`↓ 19 g46`) with an arrow pointing where the wind is heading, gusts shown only when 10+ mph above the steady wind, amber at 30+ mph and red at 45+
- **Weather alerts** — active NWS warnings/watches/advisories shown as color-coded banners (red=warning, orange=watch, yellow=advisory) with the time the hazard ends (NWS `ends`, not the message `expires`); tap to expand full NWS alert text; US locations only, silently absent elsewhere
- **NWS detailed forecast** — paragraph-form text forecast from NOAA NWS for the current period (US locations only; silently skipped otherwise, but a failed fetch is retried and shown as a retry row, see 7-day forecast)
- **Conditions grid** — wind, humidity, UV index, visibility
- **7-day forecast** — condition icons, temperature range bars, NWS condition label, max wind/gust with dominant direction (same gust colors as hourly), expandable NWS detail per day; NWS calls retry transient failures (network error, 429, 5xx) up to 3 times, and if they still fail the list ends with a "Detailed forecast unavailable. Tap to retry." row instead of silently losing the expand chevrons
- **Radar** — animated tile-based radar map centered on user location; ESRI World Dark Gray base map (zoom 8) with RainViewer radar overlay (zoom 6, last ~60 min, 6 frames); works globally
- **Moon phase** — phase name, illumination %, and day in lunar cycle; calculated locally with no API call; new moon shown as an outlined circle (visible on dark background)
- **Sun** — sunrise, sunset, daylight duration, solar noon arc; tonight's (or tomorrow's) sunset quality rating, cloud cover and best-light window from Sunsethue, shown only when the Worker proxy is configured
- **Tides** — nearest NOAA tide station (within 150 mi); a "next tide" summary with where you are in the cycle (rising/falling, just past, nearly, mid-tide); today's tide curve as a smooth SVG chart; chronological high/low tide list with Today/Tomorrow day labels; stations with only hi/lo data get sinusoidal interpolation for the chart
- **Beach pick** — near Aquidneck Island / Little Compton, RI only: ranks 10 local beaches by how much of the next 4 hours of forecast wind blows in your face (each beach's facing direction measured from OpenStreetMap coastline data), with a best pick and an "any beach is fine" call under 8 mph; same logic as the macOS widget (`macos-widget/WeatherWidget/Beaches.swift`)
- **Cruise ships** — within 20 miles of Newport, RI only: which ships are calling today and over the next four days, from the Newport Harbormaster's published Perrotti Park schedule, with the cruise line; tap a ship for its passenger capacity and the ports of call on that cruise (Newport highlighted), plus Newport arrival/departure times where known. Cancelled calls are shown struck through. Stored as a bundled snapshot, `public/cruise-newport.json`, refreshed by hand (see Refresh cruise schedule); also shown in the iPhone app
- **Atmospheric background** — gradient shifts dynamically based on weather condition and time of day
- **Location search** — tap the location name or `+` button to search by city name or US zip code; save multiple locations; persistent in localStorage
- **Geolocation** — defaults to browser GPS with reverse geocoding; skips geolocation on return visits if a saved location exists (loads instantly)
- **Build version** — footer shows auto-incrementing build number (git commit count) and exact deploy timestamp
- **PWA** — installable on iOS and Android; service worker caches the app shell and auto-busts the cache on every deploy; "Sunset tide" app icon, SVG/PNG/ICO favicons and an apple-touch-icon
- **Accessibility** — pinch zoom allowed; alerts, forecast rows, the beach card and location cards are keyboard-focusable `role="button"` elements with `aria-expanded`; icon-only buttons are labelled and icon glyphs hidden from screen readers; live regions for loading and errors; visible focus ring; `prefers-reduced-motion` disables animations (the radar then shows a static latest frame)
- **Native apps** — a macOS desktop widget and an iPhone app + widget (CarPlay-ready) built from the same data logic; see [`macos-widget/README.md`](macos-widget/README.md)

## Layout

Single full-screen scroll — no bottom navigation bar. Everything is on one page in this order:

1. Weather alerts (US only, when active)
2. Compact weather hero
3. Hourly scroll (with precip probability bars)
4. NWS detailed forecast
5. Conditions grid (wind, humidity, UV, visibility)
6. Beach pick (only near Aquidneck Island / Little Compton)
7. 7-day forecast
8. Radar (animated tile map)
9. Sun info
10. Moon phase
11. Tides
12. Cruise ships (only within 20 miles of Newport, RI)

To change location, tap the location name or the `+` button in the top bar.

## Data sources (all free, no API key)

| What | Source |
|------|--------|
| Weather (current, hourly, daily), UV index, sunrise/sunset | [Open-Meteo](https://open-meteo.com/) |
| Tide predictions | [NOAA CO-OPS API](https://tidesandcurrents.noaa.gov/api/) |
| City/location search | [Open-Meteo Geocoding](https://geocoding-api.open-meteo.com/) |
| US zip code lookup | [Zippopotam.us](https://api.zippopotam.us/) |
| Reverse geocoding (GPS → city name) | [BigDataCloud](https://api.bigdatacloud.net/) |
| Detailed text forecasts + alerts (US only) | [NOAA NWS API](https://api.weather.gov/) |
| Sunset quality | [Sunsethue](https://sunsethue.com/dev-api), proxied through the Worker in `worker/index.js` so the API key stays server-side (needs a key; the feature is hidden without one) |
| Cruise ship schedule (Newport, RI only) | Dates: [Discover Newport](https://www.discovernewport.org/industry/cruise-ship-schedule/) / Office of the Newport Harbormaster, transcribed from their schedule PDF. Cruise lines, passenger capacities, itineraries and port times: compiled by hand from cruise line and travel agent sailing listings. All in the bundled `public/cruise-newport.json` (no live fetch) |
| Animated radar overlay | [RainViewer](https://www.rainviewer.com/api.html) |
| Base map tiles | [ESRI](https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer) World Dark Gray (free, no key) |
| Tide station list | Bundled `public/stations.json` (~3,450 NOAA stations) |

## Stack

- Vanilla HTML/CSS/JS — no framework, all code in `public/index.html`
- One small Cloudflare Worker (`worker/index.js`) that serves only `/api/*` (the Sunsethue proxy, with edge caching); everything else is static assets
- Native companion apps in `macos-widget/` (SwiftUI + WidgetKit, generated with XcodeGen)
- Minimal build step (`build.sh`) — stamps a build timestamp and service worker cache version at deploy time
- Cloudflare Pages with Wrangler for deployment

## Local dev

```bash
npx serve public
# or
npx wrangler dev
```

The `__BUILD_TIME__`, `__BUILD_NUM__`, and `__CACHE_VER__` placeholders in `index.html` and `sw.js` are only replaced during a Cloudflare build — locally they show as-is, which is fine for development.

## Deploy to Cloudflare Pages

### First-time setup

1. Install Wrangler: `npm install -g wrangler`
2. Log in: `wrangler login`
3. Create the project:
   ```bash
   wrangler pages project create weather-report
   ```
4. In the Cloudflare dashboard → Workers & Pages → your project → **Settings → Build & Deploy**, set:
   - **Build command:** `sh build.sh`
   - **Build output directory:** *(leave as `/` — Wrangler reads the assets directory from `wrangler.toml`)*
5. Connect your GitHub repo under **Settings → Git integration** → branch `main`.

Every push to `main` triggers an automatic build and deploy.

### What `build.sh` does

Before Wrangler uploads the files, `build.sh` runs two `sed` replacements:

- Stamps the current UTC time into `__BUILD_TIME__` in `public/index.html` — visible in the page footer.
- Stamps the git commit count into `__BUILD_NUM__` — auto-incrementing build number shown in the footer as `v42`.
- Writes a unique timestamp-based version into `__CACHE_VER__` in `public/sw.js` — causes the service worker to invalidate its old cache on every deploy so users always receive the latest files.

### Manual deploy

```bash
sh build.sh          # stamp placeholders first
wrangler pages deploy public
```

### Sunset-quality API key

The Worker needs a Sunsethue key as a secret; without it `/api/sunset` returns 503 and the page simply omits the sunset rating.

```bash
npx wrangler secret put SUNSETHUE_KEY      # production
echo 'SUNSETHUE_KEY=...' > .dev.vars        # local dev with `npx wrangler dev` (gitignored)
```

## Native apps

`macos-widget/` builds a macOS desktop widget and a native iPhone app (with a widget that also shows in CarPlay on iOS 26+). The iPhone app mirrors the web app, minus the radar. Build, install and CarPlay notes are in [`macos-widget/README.md`](macos-widget/README.md).

Free Apple ID builds expire after 7 days. `scripts/refresh-ios.sh` rebuilds and reinstalls the iPhone app over Wi-Fi, and can be run on a schedule with a launchd agent (setup is described in the native-app README).

## Testing flags

Append query params to the URL to test UI states without needing real data:

| Flag | Effect |
|------|--------|
| `?alerts=1` | Injects a fake Tornado Warning, Flash Flood Watch, and Dense Fog Advisory so all three alert severity styles (red/orange/yellow) and the expandable detail text can be inspected |

## Refresh tide station list

`stations.json` is a static snapshot of NOAA tide stations. To regenerate it:

```bash
./scripts/refresh-stations.sh
```

Commit and push — no cache bump needed.

## Refresh cruise schedule

`public/cruise-newport.json` is a hand-transcribed copy of the Newport Harbormaster's Perrotti Park schedule PDF (via Discover Newport). To see whether a newer one has been published:

```bash
./scripts/check-cruise.sh   # exit 0 = current, 1 = newer PDF published, 2 = couldn't check
```

If it reports a change, open the PDF it prints, update `calls` (one `{date, ship}` per row, add `"cancelled": true` for struck-through rows — the strikethrough isn't in the PDF's text layer, so check the rendered page), and set `pdfUrl` and `updated`. Commit and push — no cache bump needed (the iPhone app picks up the new copy from the site; rebuilding it bundles the same file). The PDF has no times and doesn't cover the South Alofsin Pier at Fort Adams (small ships such as American Cruise Lines); the card's footnote says so.

The extra detail comes from a separate hand-compiled layer in the same file: `ships` maps each ship name to `{line, passengers}` (double occupancy), and each call can carry `itinerary` (ordered `{port, date?, arrive?, depart?}` stops; Newport's times are also copied to the call's `arrive`/`depart`) plus `itinerariesUpdated` for the file. Cruise itineraries belong to one sailing, so they're good only for that season: at the start of each season, look up each Newport call's sailing on the cruise line's site or a travel agent listing and fill in `itinerary`. Calls without one still show the line and passengers.

CruiseMapper has arrival/departure times and cruise lines for Newport, but its terms prohibit scraping without written consent. Permission was requested on 2026-10-07; until they agree in writing, the app doesn't use their data. Background and the offered usage limits are in [`docs/cruise-ships-spec.md`](docs/cruise-ships-spec.md). The cruise card is in the web app and the iPhone app (which bundles the JSON and prefers the site's copy when newer); the widgets don't show it.

## Project structure

```
public/
  index.html            Main SPA (all HTML, CSS, JS inline)
  manifest.json         PWA manifest
  sw.js                 Service worker (app shell cache; version stamped at build)
  _headers              Cloudflare HTTP headers
  stations.json         Bundled NOAA tide station list (~3,450 stations)
  cruise-newport.json   Bundled Newport, RI cruise schedule snapshot (hand-refreshed)
  favicon.ico           Tab icon (16/32/48 px)
  icons/
    icon.svg            Source art for the app icons ("Sunset tide")
    favicon.svg         Simplified source art for tab icons
    icon-192.png, icon-512.png, apple-touch-icon.png, favicon-32.png
worker/
  index.js              Sunsethue proxy (/api/sunset), the only code that runs server-side
macos-widget/           macOS widget + iPhone app (SwiftUI/WidgetKit); see its README
scripts/
  refresh-stations.sh   Re-downloads stations.json from NOAA
  check-cruise.sh       Reports whether Discover Newport has published a newer cruise schedule PDF
  refresh-ios.sh        Rebuilds and reinstalls the iPhone app (beats the 7-day free-signing expiry)
docs/
  cruise-ships-spec.md  Design notes for the Newport cruise card, data-source comparison, CruiseMapper permission status
build.sh                Stamps build timestamp + SW cache version before deploy
wrangler.toml           Cloudflare config (assets directory ./public; Worker runs for /api/*)
```
