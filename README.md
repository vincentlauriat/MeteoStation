# MeteoStation

macOS app that mirrors a Bresser Weather Center 7-in-1 console — all station data, live, on your Mac, fully local.

The Bresser station (configured with the WSLink app) pushes its readings over WiFi to a small HTTP server embedded in the app (Weather Underground upload format, extra sensor channels included). No cloud dependency.

## Features

| Feature | Status |
|---|---|
| Local HTTP listener (WU format, configurable port) | ✅ |
| Outdoor temp/humidity, dew point, wind chill | ✅ |
| Wind compass (direction, speed, gust) | ✅ |
| Rain (rate, day, week, month, total) | ✅ |
| UV index & solar radiation | ✅ |
| Pressure + 24 h graph + trend forecast | ✅ |
| Indoor temp/humidity | ✅ |
| Extra sensor channels (CH1…, soil…) | ✅ |
| Moon phase, clock (with seconds), date | ✅ |
| Console-style UI (true 3×3 layout, DSEG 7-segment font, pills) | ✅ |
| Sunrise/sunset (local NOAA computation, configurable location) | ✅ |
| Beaufort scale, trend arrows, comfort smiley | ✅ |
| Bezel buttons: HISTORY, MAX/MIN (today stats), CHANNEL cycling | ✅ |
| Custom app icon | ✅ |
| Metric/imperial units | ✅ |

## Setup

1. Build & launch the app (see below). The status bar shows your Mac's IP and listening port.
2. In the **WSLink** app, add a **custom weather service**: server = your Mac's IP, port = the app's port (default `8642`), path = `/weatherstation/updateweatherstation.php`, protocol = Weather Underground.
3. Readings appear within one upload interval.

## Build

```bash
xcodegen generate
xcodebuild -scheme MeteoStation -configuration Debug build
```

Requires Xcode 16+ (macOS 14 deployment target) and [xcodegen](https://github.com/yonaskolb/XcodeGen).

## Project layout

```
MeteoStation/
├── project.yml              # xcodegen definition
└── MeteoStation/
    ├── MeteoStationApp.swift
    ├── Models/              # WeatherReading (WU parsing, unit conversion)
    ├── Services/            # StationListener (HTTP server), HistoryStore
    ├── ViewModels/          # StationViewModel
    ├── Views/               # ConsoleView + console components
    └── Helpers/             # network info, moon phase, formatters
```

## Roadmap

- [x] v1 — local listener + console UI
- [x] Custom app icon
- [ ] Menu bar extra
- [ ] Threshold notifications
- [ ] CSV export

## Credits

Seven-segment rendering uses the [DSEG fonts](https://github.com/keshikan/DSEG) by Keshikan, bundled under the SIL Open Font License (see `MeteoStation/Fonts/DSEG-LICENSE.txt`).
