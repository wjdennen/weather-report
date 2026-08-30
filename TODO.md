# TODO

## Features

- **Humidity in forecast rows** — Open-Meteo doesn't have a daily humidity field. Add `relative_humidity_2m` to the hourly request and aggregate (average or midday value) per day to show in the 7-day forecast rows.
- **AQI / air quality** — Open-Meteo Air Quality API (free, no key) returns PM2.5, PM10, US AQI, and pollen counts. Same connection pattern as the existing weather fetch.
- **Moonrise/moonset times** — already have the moon phase card; rise/set times are available from Open-Meteo daily fields.
- **Offline indicator** — service worker caches the shell, but if data fails to load there's no "you're offline, showing last data" message.
- **Tablet/desktop two-column layout** — attempted and reverted (broke data display); needs more careful debugging. Left col: hero, hourly, conditions. Right col: forecast, radar, sun, moon, tides.
- **"Feels like" on hourly chips** — apparent temperature is already fetched; could replace or supplement the raw temp on the chip.
- **Tide next high/low summary** — a single "next high tide in 3h 22m" line near the top would surface the most actionable tide info without scrolling.
- **Precipitation type in forecast** — snow vs rain vs mix is buried in condition labels; could be more prominent in winter months.
- **Precip probability number on hourly chip** — currently shown as bar width + color intensity (amount). A small numeric label (e.g. "40%") would make it more readable at a glance.
- **Alert expiry countdown** — show "expires in 45m" instead of an absolute clock time; more immediately useful.
- **More `?flag=1` test modes** — e.g. `?offline=1` to simulate stale/no data, `?night=1` to force night-time gradient, for easier UI testing without real conditions.
