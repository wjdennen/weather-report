# Weather Report

A PWA weather app for current conditions, hourly forecasts, 7-day outlook, tides, and sun info — built by [Clam Code](https://github.com/wjdennen). Deployed on Cloudflare Pages.

## Features

- **Compact hero** — condition label + icon on the left, current temperature on the right; feels-like and hi/lo below
- **Hourly scroll** — 24-hour horizontal chip strip with animated TODAY/TOMORROW/day-name label; precip probability shown as a fill bar (width = probability, color intensity = expected amount)
- **Weather alerts** — active NWS warnings/watches/advisories shown as color-coded banners (red=warning, orange=watch, yellow=advisory); tap to expand full NWS alert text; US locations only, silently absent elsewhere
- **NWS detailed forecast** — paragraph-form text forecast from NOAA NWS for the current period (US locations only; silently skipped otherwise)
- **Conditions grid** — wind, humidity, UV index, visibility
- **7-day forecast** — condition icons, temperature range bars, NWS condition label, expandable NWS detail per day
- **Radar** — animated tile-based radar map centered on user location; ESRI World Dark Gray base map (zoom 8) with RainViewer radar overlay (zoom 6, last ~60 min, 6 frames); works globally
- **Moon phase** — phase name, illumination %, and day in lunar cycle; calculated locally with no API call; new moon shown as an outlined circle (visible on dark background)
- **Sun** — sunrise, sunset, daylight duration, solar noon arc
- **Tides** — nearest NOAA tide station (within 150 mi); today's tide curve as a smooth SVG chart; chronological high/low tide list with Today/Tomorrow day labels; stations with only hi/lo data get sinusoidal interpolation for the chart
- **Atmospheric background** — gradient shifts dynamically based on weather condition and time of day
- **Location search** — tap the location name or `+` button to search by city name or US zip code; save multiple locations; persistent in localStorage
- **Geolocation** — defaults to browser GPS with reverse geocoding; skips geolocation on return visits if a saved location exists (loads instantly)
- **Build version** — footer shows auto-incrementing build number (git commit count) and exact deploy timestamp
- **PWA** — installable on iOS and Android; service worker caches the app shell and auto-busts the cache on every deploy
- **E-ink devkit endpoint** — `/api/eink-weather` renders a 400x300 4-color PNG for the ZECTRIX NOTE4C e-paper devkit; see [below](#e-ink-devkit-endpoint-apieink-weather)

## Layout

Single full-screen scroll — no bottom navigation bar. Everything is on one page in this order:

1. Weather alerts (US only, when active)
2. Compact weather hero
3. Hourly scroll (with precip probability bars)
4. NWS detailed forecast
5. Conditions grid (wind, humidity, UV, visibility)
6. 7-day forecast
7. Radar (animated tile map)
8. Sun info
9. Moon phase
10. Tides

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
| Animated radar overlay | [RainViewer](https://www.rainviewer.com/api.html) |
| Base map tiles | [ESRI](https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer) World Dark Gray (free, no key) |
| Tide station list | Bundled `public/stations.json` (~3,450 NOAA stations) |

## Stack

- Vanilla HTML/CSS/JS — no framework, all code in `public/index.html`
- Minimal build step (`build.sh`) — stamps a build timestamp and service worker cache version at deploy time
- Deployed as a **Cloudflare Worker with static assets** (not classic Cloudflare Pages, despite the project name — see [Deploy](#deploy) below), with Wrangler for local dev and deployment
- `src/worker.js` handles server-side routes (currently just `/api/eink-weather`); everything else is served directly from `public/` as a static asset

## Local dev

```bash
npx serve public
# or
npx wrangler dev
```

The `__BUILD_TIME__`, `__BUILD_NUM__`, and `__CACHE_VER__` placeholders in `index.html` and `sw.js` are only replaced during a Cloudflare build — locally they show as-is, which is fine for development.

`wrangler dev` also runs `src/worker.js`, so `/api/eink-weather` works locally too — see [E-ink devkit endpoint](#e-ink-devkit-endpoint-apieink-weather) below.

## Deploy

This project is a **Cloudflare Worker with static assets**, configured via `wrangler.toml`'s `main` (the Worker script) and `[assets]` (the `public/` directory) — it is *not* a classic Cloudflare Pages project, even though it lives under the "Workers & Pages" dashboard section and started life with Pages-style tooling. That distinction matters: the classic Pages `functions/` directory convention does **not** work here — server-side routes must be added to `src/worker.js` instead.

### First-time setup

1. Install Wrangler: `npm install -g wrangler`
2. Log in: `wrangler login`
3. In the Cloudflare dashboard → **Workers & Pages** → your project → **Settings → Builds**, set:
   - **Build command:** `sh build.sh`
   - **Deploy command:** `npx wrangler deploy`
   - **Version command** (used for preview builds on non-production branches): `npx wrangler versions upload`
4. Connect your GitHub repo under the same **Builds** settings → branch `main` as production, with **Builds for non-production branches** enabled for preview builds.
5. Under **Settings → Domains**, enable the **Preview** toggle (`*-weather-report.<subdomain>.workers.dev`) if you want non-`main` branches to get a reachable preview URL — it's off by default and separate from whether preview *builds* are enabled.

Every push to `main` deploys to production; every push to another branch uploads a new version reachable at `https://<branch-name>-weather-report.<subdomain>.workers.dev` (once the Preview toggle above is on).

### What `build.sh` does

Before Wrangler uploads the files, `build.sh` runs two `sed` replacements:

- Stamps the current UTC time into `__BUILD_TIME__` in `public/index.html` — visible in the page footer.
- Stamps the git commit count into `__BUILD_NUM__` — auto-incrementing build number shown in the footer as `v42`.
- Writes a unique timestamp-based version into `__CACHE_VER__` in `public/sw.js` — causes the service worker to invalidate its old cache on every deploy so users always receive the latest files.

### Manual deploy

```bash
sh build.sh          # stamp placeholders first
npx wrangler deploy
```

## Testing flags

Append query params to the URL to test UI states without needing real data:

| Flag | Effect |
|------|--------|
| `?alerts=1` | Injects a fake Tornado Warning, Flash Flood Watch, and Dense Fog Advisory so all three alert severity styles (red/orange/yellow) and the expandable detail text can be inspected |

## E-ink devkit endpoint (`/api/eink-weather`)

Renders current conditions as a 400x300, 4-color (black/white/red/yellow) indexed PNG — the native panel format of the [ZECTRIX NOTE4C Devkit](https://shop.zectrixlab.com/products/note4c-devkit), an ESP32-S3 e-paper devkit. Built for polling by that device's firmware (or a bridge script), independent of the main PWA above.

```
GET /api/eink-weather?lat=<LAT>&lon=<LON>&name=<Optional+Label>
```

- `lat`, `lon` — required, decimal degrees
- `name` — optional label shown in the footer (e.g. a town name)
- Returns `image/png`, `Cache-Control: public, max-age=600`
- 400 on missing/invalid `lat`/`lon`; 502 if the upstream Open-Meteo request fails

Implementation lives in `lib/eink/` (font, drawing primitives, WMO icon/label mapping, weather fetch, PNG encoder — all zero-dependency, built on Web-standard APIs like `CompressionStream`) and is wired up as a route in `src/worker.js`. See `TODO.md` for planned additions (alerts, tides, a rotating second screen).

## Refresh tide station list

`stations.json` is a static snapshot of NOAA tide stations. To regenerate it:

```bash
./scripts/refresh-stations.sh
```

Commit and push — no cache bump needed.

## Project structure

```
public/
  index.html            Main SPA (all HTML, CSS, JS inline)
  manifest.json         PWA manifest
  sw.js                 Service worker (app shell cache; version stamped at build)
  _headers              Cloudflare Pages HTTP headers
  stations.json         Bundled NOAA tide station list (~3,450 stations)
src/
  worker.js             Worker entry point — routes /api/eink-weather, otherwise 404s
                         (static assets in public/ are served automatically and never
                         reach this script — see Deploy below)
lib/eink/
  weather.js             Server-side Open-Meteo fetch for the e-ink renderer
  wmo.js                 WMO weather-code -> icon/label mapping
  render.js              Composes the 400x300 4-color framebuffer
  draw.js                Pixel-buffer drawing primitives (text, lines, shapes)
  font5x7.js             Minimal 5x7 bitmap font
  png.js                 Zero-dependency indexed PNG encoder
scripts/
  refresh-stations.sh   Re-downloads stations.json from NOAA
build.sh                Stamps build timestamp + SW cache version before deploy
wrangler.toml           Worker config: main = src/worker.js, assets directory = ./public
```
