# Changelog

## 1.1.0 — unreleased

- Remote access: new relay (`Relay/meteorelay.py`, Python stdlib + SQLite, systemd) to run on an always-on machine on the station's LAN (e.g. a Raspberry Pi). The console pushes to it; MeteoStation reads it over Tailscale.
- New *Source des données* setting: local station or remote relay. Relay mode polls every 5 s and catches up missed history after sleep (sampled per minute beyond 15 min), keeping the relay's receive times.
- Relay status in the status bar and settings.
- The relay pages by reading id (`after_id`); app 1.1.0 needs the 1.1 relay — install/update it with `Relay/install.sh` first.
- Relay can also serve reads to the station's LAN (`METEORELAY_READ_LAN=1`, on in the bundled unit) and filter uploads by station ID (`METEORELAY_STATION_ID`).
- Fix: history is now written synchronously on quit (the background write could be cut short, losing the last minutes).

## 1.0.0 — 2026-08-06

First public release.

- Local HTTP listener (Weather Underground upload format, configurable port, default 8642) — the station pushes directly to the app, fully local, no cloud.
- Console-style UI mirroring the Bresser 7-in-1 device: 3×3 layout, DSEG 7-segment font, pills, wind compass with Beaufort scale, pressure graph, trend arrows, comfort smiley.
- Outdoor/indoor temperature & humidity, dew point, feels-like, wind (direction/speed/gust), rain, UV index, solar radiation, pressure with 24 h graph and trend forecast.
- Moon phase, clock with seconds, date, sunrise/sunset computed locally (NOAA algorithm, configurable location).
- Bezel buttons: HISTORY (graph + sensor band), MAX/MIN (today stats), CHANNEL (extra sensor cycling).
- 7-day local history (JSON), metric/imperial units.
- Signed (Developer ID), notarized, auto-updates via Sparkle.
