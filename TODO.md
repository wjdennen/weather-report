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

## Done

- ~~**Tide next high/low summary**~~ — the Tides card now opens with a "next tide" summary and where you are in the cycle.
- ~~**Precip probability number on hourly chip**~~ — chips show a small "40%" label under the fill bar whenever the chance is above 0.
