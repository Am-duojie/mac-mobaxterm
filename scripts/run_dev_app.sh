#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacMobaXterm"
VERSION="${1:-dev}"

"$ROOT_DIR/scripts/package_release.sh" "$VERSION" >/dev/null

pkill -x "$APP_NAME" 2>/dev/null || true
open "$ROOT_DIR/dist/$APP_NAME.app"

echo "Opened $ROOT_DIR/dist/$APP_NAME.app"
