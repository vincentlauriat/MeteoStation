#!/usr/bin/env python3
"""MeteoStation relay — receives Bresser console uploads on the LAN and serves
them to MeteoStation over Tailscale.

The console pushes in the Weather Underground format (GET query, or POST form /
JSON on some firmwares). Every upload is stored as-is (raw params + server
receive time) in SQLite for 7 days; parsing stays in the app.

Read API (Tailscale / localhost clients; LAN too with METEORELAY_READ_LAN=1):
    GET /health
    GET /readings?after_id=<id>&limit=<n>&step=<seconds>
    GET /readings?since=<unix ts>&limit=<n>&step=<seconds>
        -> {"readings": [{"id": <int>, "t": <unix ts>, "p": {...}}], "more": bool, "now": <unix ts>}
        Readings after the cursor, in arrival order. Clients page with `after_id`
        (immune to clock jumps and float rounding); `since` is only for the first
        request. `step` > 0 keeps the last reading of each `step`-second bucket
        (catch-up after a gap).

Any other request carrying weather fields is stored as a station upload and
answered `success`.

Standard library only. Configuration through environment variables:
    METEORELAY_PORT (8650), METEORELAY_DB (~/.local/share/meteorelay/readings.db),
    METEORELAY_RETENTION_DAYS (7), METEORELAY_READ_LAN (0),
    METEORELAY_STATION_ID (unset: any station ID accepted)
"""

from __future__ import annotations

import ipaddress
import json
import logging
import os
import re
import socket
import sqlite3
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qsl, urlsplit

PORT = int(os.environ.get("METEORELAY_PORT", "8650"))
DB_PATH = os.path.expanduser(
    os.environ.get("METEORELAY_DB", "~/.local/share/meteorelay/readings.db")
)
RETENTION = float(os.environ.get("METEORELAY_RETENTION_DAYS", "7")) * 86400
READ_LAN = os.environ.get("METEORELAY_READ_LAN", "0") == "1"
STATION_ID = os.environ.get("METEORELAY_STATION_ID", "").strip()
MAX_LIMIT = 5000
MAX_BODY = 64 * 1024
# Credentials the console sends with every upload; never re-served.
DROPPED_KEYS = {"password", "pass", "passkey", "key"}
# An upload must carry at least one weather field to be stored.
WEATHER_KEY = re.compile(
    r"^(tempf|humidity|dewptf|baromin|absbaromin|windspeedmph|windgustmph|winddir|rainin"
    r"|dailyrainin|uv|solarradiation|indoortempf|indoorhumidity|temp\d+f|humidity\d+"
    r"|soiltemp\d*f|soilmoist(ure)?\d*)$"
)
READ_NETWORKS = [
    ipaddress.ip_network("100.64.0.0/10"),  # Tailscale IPv4
    ipaddress.ip_network("fd7a:115c:a1e0::/48"),  # Tailscale IPv6
    ipaddress.ip_network("127.0.0.0/8"),
    ipaddress.ip_network("::1/128"),
]
LAN_NETWORKS = [
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("fe80::/10"),
    ipaddress.ip_network("fc00::/7"),
]

log = logging.getLogger("meteorelay")


class Store:
    def __init__(self, path: str) -> None:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        self._db = sqlite3.connect(path, check_same_thread=False)
        self._lock = threading.Lock()
        self._last_prune = 0.0
        with self._lock:
            self._db.execute("PRAGMA journal_mode=WAL")
            self._db.execute(
                "CREATE TABLE IF NOT EXISTS readings ("
                " id INTEGER PRIMARY KEY, received_at REAL NOT NULL, params TEXT NOT NULL)"
            )
            self._db.execute(
                "CREATE INDEX IF NOT EXISTS readings_received_at ON readings(received_at)"
            )
            self._db.commit()

    def add(self, received_at: float, params: dict[str, str]) -> None:
        with self._lock:
            self._db.execute(
                "INSERT INTO readings(received_at, params) VALUES (?, ?)",
                (received_at, json.dumps(params, separators=(",", ":"))),
            )
            if received_at - self._last_prune > 3600:
                self._db.execute(
                    "DELETE FROM readings WHERE received_at < ?", (received_at - RETENTION,)
                )
                self._last_prune = received_at
            self._db.commit()

    def page(
        self, after_id: int | None, since: float, limit: int, step: int
    ) -> tuple[list[dict], bool]:
        if after_id is not None:
            where, arg = "id > ?", after_id
        else:
            where, arg = "received_at > ?", since
        if step > 0:
            query = (
                "SELECT id, received_at, params FROM readings WHERE id IN ("
                f" SELECT MAX(id) FROM readings WHERE {where}"
                " GROUP BY CAST(received_at / ? AS INTEGER))"
                " ORDER BY id LIMIT ?"
            )
            args: tuple = (arg, step, limit + 1)
        else:
            query = (
                f"SELECT id, received_at, params FROM readings WHERE {where}"
                " ORDER BY id LIMIT ?"
            )
            args = (arg, limit + 1)
        with self._lock:
            rows = self._db.execute(query, args).fetchall()
        more = len(rows) > limit
        return [{"id": i, "t": t, "p": json.loads(p)} for i, t, p in rows[:limit]], more

    def count(self) -> tuple[int, float | None]:
        with self._lock:
            n, last = self._db.execute(
                "SELECT COUNT(*), MAX(received_at) FROM readings"
            ).fetchone()
        return n, last


def parse_upload(target: str, method: str, body: bytes) -> dict[str, str]:
    params = dict(parse_qsl(urlsplit(target).query, keep_blank_values=True))
    if method == "POST" and body:
        text = body.decode("utf-8", errors="replace").strip()
        if text.startswith("{"):
            try:
                obj = json.loads(text)
            except ValueError:
                obj = {}
            if isinstance(obj, dict):
                for k, v in obj.items():
                    if isinstance(v, bool):
                        params[k] = "1" if v else "0"
                    elif isinstance(v, (str, int, float)):
                        params[k] = str(v)
        else:
            params.update(parse_qsl(text, keep_blank_values=True))
    return {k: v for k, v in params.items() if k.lower() not in DROPPED_KEYS}


def is_station_upload(params: dict[str, str]) -> bool:
    if not any(WEATHER_KEY.match(k.lower()) for k in params):
        return False
    if STATION_ID:
        sent = next((v for k, v in params.items() if k.lower() == "id"), "")
        return sent == STATION_ID
    return True


class Handler(BaseHTTPRequestHandler):
    server_version = "MeteoRelay/1.1"
    timeout = 10  # a client announcing more body than it sends must not pin a thread
    store: Store  # set on the class at startup

    def log_message(self, fmt: str, *args) -> None:  # quiet: one upload every 5 s
        log.debug("%s %s", self.address_string(), fmt % args)

    def _client_may_read(self) -> bool:
        try:
            ip = ipaddress.ip_address(self.client_address[0])
        except ValueError:
            return False
        if ip.version == 6 and ip.ipv4_mapped:
            ip = ip.ipv4_mapped
        networks = READ_NETWORKS + LAN_NETWORKS if READ_LAN else READ_NETWORKS
        return any(ip in net for net in networks)

    def _send(self, code: int, body: bytes, ctype: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, code: int, obj) -> None:
        self._send(code, json.dumps(obj, separators=(",", ":")).encode(), "application/json")

    def _handle(self, method: str) -> None:
        path = urlsplit(self.path).path
        if method == "GET" and path in ("/health", "/readings"):
            if not self._client_may_read():
                self._json(403, {"error": "read API is not served to this network"})
                return
            if path == "/health":
                n, last = self.store.count()
                self._json(200, {"ok": True, "count": n, "last": last, "now": time.time()})
                return
            self._readings()
            return

        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            self._send(400, b"bad Content-Length", "text/plain")
            return
        body = self.rfile.read(min(length, MAX_BODY)) if length > 0 else b""
        params = parse_upload(self.path, method, body)
        if is_station_upload(params):
            self.store.add(time.time(), params)
        self._send(200, b"success", "text/plain")

    def _readings(self) -> None:
        query = dict(parse_qsl(urlsplit(self.path).query))
        try:
            after_id = int(query["after_id"]) if "after_id" in query else None
            since = float(query.get("since", "0"))
            limit = max(1, min(int(query.get("limit", "2000")), MAX_LIMIT))
            step = max(0, int(query.get("step", "0")))
        except ValueError:
            self._json(400, {"error": "after_id, since, limit and step must be numbers"})
            return
        readings, more = self.store.page(after_id, since, limit, step)
        self._json(200, {"readings": readings, "more": more, "now": time.time()})

    def do_GET(self) -> None:  # noqa: N802
        self._handle("GET")

    def do_POST(self) -> None:  # noqa: N802
        self._handle("POST")


class DualStackServer(ThreadingHTTPServer):
    daemon_threads = True
    address_family = socket.AF_INET6

    def server_bind(self) -> None:
        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        super().server_bind()


class IPv4Server(ThreadingHTTPServer):
    daemon_threads = True


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    Handler.store = Store(DB_PATH)
    try:
        server: ThreadingHTTPServer = DualStackServer(("::", PORT), Handler)
    except OSError:  # IPv6 disabled on this host
        server = IPv4Server(("0.0.0.0", PORT), Handler)
    log.info(
        "listening on port %d, db %s, LAN reads %s, station ID filter %s",
        PORT, DB_PATH, "on" if READ_LAN else "off", STATION_ID or "off",
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
