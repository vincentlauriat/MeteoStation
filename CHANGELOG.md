# Changelog

## 1.0.0 — 2026-08-06

First public release.

- Local HTTP listener (Weather Underground upload format, configurable port, default 8642) — the station pushes directly to the app, fully local, no cloud.
- Console-style UI mirroring the Bresser 7-in-1 device: 3×3 layout, DSEG 7-segment font, pills, wind compass with Beaufort scale, pressure graph, trend arrows, comfort smiley.
- Outdoor/indoor temperature & humidity, dew point, feels-like, wind (direction/speed/gust), rain, UV index, solar radiation, pressure with 24 h graph and trend forecast.
- Moon phase, clock with seconds, date, sunrise/sunset computed locally (NOAA algorithm, configurable location).
- Bezel buttons: HISTORY (graph + sensor band), MAX/MIN (today stats), CHANNEL (extra sensor cycling).
- 7-day local history (JSON), metric/imperial units.
- Signed (Developer ID), notarized, auto-updates via Sparkle.
