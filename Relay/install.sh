#!/usr/bin/env bash
# Install or update the MeteoStation relay on a Raspberry Pi (or any systemd Linux).
# Usage, from the repo root:  Relay/install.sh <ssh-host>     (e.g. Relay/install.sh raspcorse)
set -euo pipefail

host="${1:?usage: Relay/install.sh <ssh-host>}"
here="$(cd "$(dirname "$0")" && pwd)"

scp "$here/meteorelay.py" "$here/meteorelay.service" "$host:/tmp/"
ssh "$host" 'set -e
  sudo install -d /opt/meteorelay
  sudo install -m 755 /tmp/meteorelay.py /opt/meteorelay/meteorelay.py
  sudo install -m 644 /tmp/meteorelay.service /etc/systemd/system/meteorelay.service
  rm -f /tmp/meteorelay.py /tmp/meteorelay.service
  sudo systemctl daemon-reload
  sudo systemctl enable --now meteorelay
  sudo systemctl restart meteorelay
  sleep 1
  systemctl is-active meteorelay
  curl -fsS http://127.0.0.1:8650/health; echo'
