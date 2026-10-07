# TODO

## Features

- **Humidity in forecast rows** — Open-Meteo doesn't have a daily humidity field. Add `relative_humidity_2m` to the hourly request and aggregate (average or midday value) per day to show in the 7-day forecast rows.
- **AQI / air quality** — Open-Meteo Air Quality API (free, no key) returns PM2.5, PM10, US AQI, and pollen counts. Same connection pattern as the existing weather fetch.
- **Moonrise/moonset times** — already have the moon phase card; rise/set times are available from Open-Meteo daily fields.
- **Offline indicator** — service worker caches the shell, but if data fails to load there's no "you're offline, showing last data" message.
- **Tablet/desktop two-column layout** — attempted and reverted (broke data display); needs more careful debugging. Left col: hero, hourly, conditions. Right col: forecast, radar, sun, moon, tides.
- **"Feels like" on hourly chips** — apparent temperature is already fetched; could replace or supplement the raw temp on the chip.
- **Precipitation type in forecast** — snow vs rain vs mix is buried in condition labels; could be more prominent in winter months.
- **Alert end countdown** — show "ends in 45m" instead of an absolute "until" time; more immediately useful.
- **More `?flag=1` test modes** — e.g. `?offline=1` to simulate stale/no data, `?night=1` to force night-time gradient, for easier UI testing without real conditions.
- **Cruise card: CruiseMapper times** — if CruiseMapper replies yes (asked 2026-10-07), rebuild a Worker scraper within the limits we offered (Newport page only, cache 24h+, clear user agent, credit link) to add arrival/departure times and cruise lines. Don't scrape until they agree in writing. See `docs/cruise-ships-spec.md`.
- **Cruise card: Fort Adams ships** — the Harbormaster's South Alofsin Pier schedule (small ships like American Cruise Lines) wasn't published as of 9/24/26; check `./scripts/check-cruise.sh` (it flags extra PDFs) and add those calls when it appears.
- **Cruise card: automate the freshness check** — `scripts/check-cruise.sh` is manual; could run weekly as a GitHub Action that opens an issue when a newer schedule PDF is posted.
- **Cruise card: widgets** — the card is in the web and iPhone apps; the iOS and macOS widgets don't show cruise ships (little room; could be a line on the large widget).

## Done

- ~~**Cruise card in the iPhone app**~~ — same schedule, bundled with the app and refreshed from the site when newer.
- ~~**Cruise ships in port (Newport, RI)**~~ — web card within 20 miles of Newport from the Harbormaster's schedule, bundled as `public/cruise-newport.json` with a manual freshness check (v1.2).
- ~~**Tide next high/low summary**~~ — the Tides card now opens with a "next tide" summary and where you are in the cycle.
- ~~**Precip probability number on hourly chip**~~ — chips show a small "40%" label under the fill bar whenever the chance is above 0.
