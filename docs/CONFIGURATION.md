# Configuring the Bresser console for MeteoStation

This guide covers the **Bresser Weather Center 7-in-1** with the **WSX3001-generation console** (firmware 2.x). The console is configured through its **built-in web interface** (AP mode) — the WSLink mobile app does **not** work with this generation.

## Prerequisites

- MeteoStation installed and running on your Mac. The status bar at the bottom of the window shows the exact address to use (e.g. `192.168.68.44:8642`).
- Your Mac and the console on the same LAN.
- **Strongly recommended:** a DHCP reservation for your Mac on your router, so its IP never changes. If it does, the console keeps pushing to the old address and the app silently stops receiving.

## Step 1 — Put the console in AP mode

Press and hold the **[SENSOR/WI-FI]** button for **6 seconds**. The console starts broadcasting its own WiFi access point named `PWS-XXXXXX`.

## Step 2 — Open the console's web UI

1. On your Mac or phone, join the `PWS-XXXXXX` WiFi network.
2. Open a browser at **`http://192.168.1.1`**.

## Step 3 — Router section

Make sure your home WiFi network is selected with the correct password — the console reconnects to it once setup is applied.

## Step 4 — Weather server section

The page shows several upload services. The first two (Wunderground, Weathercloud) have fixed destinations — leave them as they are. Use the **third block**, the one with a free **URL** field (pre-filled with `ws.awekas.at`):

| Field | Value |
|---|---|
| URL | your Mac's address, e.g. `192.168.68.44:8642` |
| Station ID | anything, e.g. `MyStation` |
| Station key | anything, e.g. `12345678` |

The console uploads in the Weather Underground format (`GET /weatherstation/updateweatherstation.php?…`, imperial units) — exactly what MeteoStation listens for. No path needs to be entered.

The port is configurable in MeteoStation's settings (default **8642**). If your console firmware refuses a port in the URL field, set the app's port to **80** and enter the bare IP.

## Step 5 — Apply

Click **Apply**. The console leaves AP mode, reconnects to your home WiFi, and starts pushing. With firmware 2.07 the console uploads in **real-time mode, every ~5 seconds**. The app's status bar shows "last received" time; the tiles light up on the first frame.

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| Console says "Configuration complete" but nothing arrives | Your Mac's IP changed since you entered it (no DHCP reservation). Check the app's status bar for the current IP and reconfigure the console. |
| Nothing arrives at all | Verify the app is running and shows "listening" in the status bar; check `lsof -nP -iTCP:8642 -sTCP:LISTEN`; make sure the macOS firewall allows incoming connections for MeteoStation. |
| Port refused in the console URL field | Set the app port to 80 in Settings and enter the bare IP. |
| Extra sensors (CH1…, soil…) missing | The WSX3001 firmware does not transmit extra channels on this upload service — only the main sensor array. The app displays them automatically if a firmware provides them. |

## Data & privacy

Everything stays on your LAN. The app keeps a rolling 7-day history in `~/Library/Application Support/MeteoStation/history.json` (or the sandbox container equivalent). No data leaves your network.
