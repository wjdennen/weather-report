# Weather Report

A PWA weather app for current conditions, hourly forecasts, 7-day outlook, tides, and sun info — built by [Clam Code](https://github.com/wjdennen). Deployed on Cloudflare Pages.

## Features

- **Compact hero** — condition label + icon on the left, current temperature on the right; feels-like and hi/lo below
- **Hourly scroll** — 24-hour horizontal chip strip with animated TODAY/TOMORROW/day-name label; precip probability shown as a fill bar (width = probability, color intensity = expected amount)
- **Weather alerts** — active NWS warnings/watches/advisories shown as color-coded banners (red=warning, orange=watch, yellow=advisory); tap to expand full NWS alert text; US locations only, silently absent elsewhere
- **NWS detailed forecast** — paragraph-form text forecast from NOAA NWS for the current period (US locations only; silently skipped otherwise)
- **Conditions grid** — wind, humidity, UV index, visibility
- **7-day forecast** — condition icons, temperature range bars, NWS condition label, expandable NWS detail per day
- **Radar** — animated tile-based radar map centered on user location; CartoDB dark base map (zoom 8) with RainViewer radar overlay (zoom 6, last ~60 min, 6 frames); works globally
- **Moon phase** — phase name, illumination %, and day in lunar cycle; calculated locally with no API call; new moon shown as an outlined circle (visible on dark background)
- **Sun** — sunrise, sunset, daylight duration, solar noon arc
- **Tides** — nearest NOAA tide station (within 150 mi); today's tide curve as a smooth SVG chart; chronological high/low tide list with Today/Tomorrow day labels; stations with only hi/lo data get sinusoidal interpolation for the chart
- **Atmospheric background** — gradient shifts dynamically based on weather condition and time of day
- **Location search** — tap the location name or `+` button to search by city name or US zip code; save multiple locations; persistent in localStorage
- **Geolocation** — defaults to browser GPS with reverse geocoding; skips geolocation on return visits if a saved location exists (loads instantly)
- **Build version** — footer shows auto-incrementing build number (git commit count) and exact deploy timestamp
- **PWA** — installable on iOS and Android; service worker caches the app shell and auto-busts the cache on every deploy

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
| Base map tiles | [CartoDB](https://carto.com/basemaps/) dark matter (no labels) |
| Tide station list | Bundled `public/stations.json` (~3,450 NOAA stations) |

## Stack

- Vanilla HTML/CSS/JS — no framework, all code in `public/index.html`
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

## Project structure

```
public/
  index.html            Main SPA (all HTML, CSS, JS inline)
  manifest.json         PWA manifest
  sw.js                 Service worker (app shell cache; version stamped at build)
  _headers              Cloudflare Pages HTTP headers
  stations.json         Bundled NOAA tide station list (~3,450 stations)
scripts/
  refresh-stations.sh   Re-downloads stations.json from NOAA
build.sh                Stamps build timestamp + SW cache version before deploy
wrangler.toml           Cloudflare Pages config (assets directory: ./public)
```
