#!/usr/bin/env bash
set -euo pipefail

if ! command -v socat >/dev/null 2>&1; then
  cat >&2 <<'MSG'
socat is required for virtual serial testing.

Install it with:
  brew install socat
MSG
  exit 1
fi

APP_PORT="/tmp/macmobaxterm-serial-app"
PEER_PORT="/tmp/macmobaxterm-serial-peer"

rm -f "$APP_PORT" "$PEER_PORT"

echo "Starting a virtual serial pair."
echo "Use this path in MacMobaXterm:"
echo "  $APP_PORT"
echo
echo "Use this path in Terminal:"
echo "  screen $PEER_PORT 115200"
echo
echo "Keep this process running while testing. Press Ctrl-C to stop."
echo

exec socat -d -d \
  "pty,raw,echo=0,link=$APP_PORT" \
  "pty,raw,echo=0,link=$PEER_PORT"
