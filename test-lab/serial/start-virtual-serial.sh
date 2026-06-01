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

echo "Starting a virtual serial pair."
echo "Use the first /dev/ttys* path in MacMobaXterm."
echo "Use the second /dev/ttys* path with screen, for example:"
echo "  screen /dev/ttysXXX 115200"
echo
echo "Keep this process running while testing. Press Ctrl-C to stop."
echo

exec socat -d -d pty,raw,echo=0 pty,raw,echo=0
