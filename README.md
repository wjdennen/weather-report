# Weather Report!

A PWA weather app for current conditions, 7-day forecasts, tides, and sun info — built by [Clam Code](https://github.com/wjdennen). Deployable on Cloudflare Pages.

## Features

- **Current conditions** — temperature, feels like, hi/lo, condition icon, hourly 24-hour scroll, wind, humidity, UV index, visibility
- **Atmospheric background** — gradient shifts dynamically based on weather condition and time of day
- **Detailed forecast** — NWS paragraph-form forecast for the current period on the Home tab (e.g. "This Afternoon: Mostly cloudy, with a high near 87…"); tap any day row on the Forecast tab to expand its full NWS text; US locations only, silently skipped otherwise
- **7-day forecast** — condition icons, temperature range bars, sunrise/sunset times per day, auto-generated outlook summary, and a Planner's View best-day picker
- **Tides** — nearest NOAA tide station (within 150 mi), today's tide curve as a smooth SVG chart, high/low tide times and heights; stations that only have hi/lo data get sinusoidal interpolation for the chart
- **Sun** — sunrise, sunset, daylight duration, solar noon arc, UV index
- **Location search** — search by city name or US zip code, save multiple locations, persistent in localStorage
- **Geolocation** — defaults to your current location via browser GPS with reverse geocoding
- **PWA** — installable on iOS and Android, service worker for offline app shell

## Data sources (all free, no API key)

| What | Source |
|------|--------|
| Weather (current, hourly, daily), UV index, sunrise/sunset | [Open-Meteo](https://open-meteo.com/) |
| Tide predictions | [NOAA CO-OPS API](https://tidesandcurrents.noaa.gov/api/) |
| City/location search | [Open-Meteo Geocoding](https://geocoding-api.open-meteo.com/) |
| US zip code lookup | [Zippopotam.us](https://api.zippopotam.us/) |
| Reverse geocoding (GPS → city name) | [BigDataCloud](https://api.bigdatacloud.net/) |
| Detailed text forecasts (US only) | [NOAA NWS API](https://api.weather.gov/) |
| Tide station list | Bundled `public/stations.json` (~3,450 NOAA stations) |

## Stack

- Vanilla HTML/CSS/JS — no framework, no build step
- Cloudflare Pages (static assets via `wrangler.toml`)

## Local dev

```bash
npx serve public
# or
npx vite public
```

## Deploy to Cloudflare Pages

### First-time setup

1. Install Wrangler: `npm install -g wrangler`
2. Log in: `wrangler login`
3. Create the project:
   ```bash
   wrangler pages project create weather-report
   ```
4. Connect your GitHub repo in the Cloudflare dashboard → Workers & Pages → your project → Settings → Git integration → connect to `wjdennen/weather-report`, branch `main`.

After that, every push to `main` triggers an automatic deploy.

### Manual deploy

```bash
wrangler pages deploy public
```

## Refresh tide station list

`stations.json` is a static snapshot of NOAA tide stations. To update it:

```bash
./scripts/refresh-stations.sh
```

Then commit and push — no service worker cache bump needed.

## Project structure

```
public/
  index.html        Main SPA (all HTML, CSS, and JS inline)
  manifest.json     PWA manifest
  sw.js             Service worker (app shell cache)
  _headers          Cloudflare Pages HTTP headers
  stations.json     Bundled NOAA tide station list
scripts/
  refresh-stations.sh   Re-downloads stations.json from NOAA
wrangler.toml       Cloudflare Pages config
```
