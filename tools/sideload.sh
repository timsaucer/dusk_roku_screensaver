#!/usr/bin/env bash
# Usage: tools/sideload.sh <app-dir>   — zips the app and installs it on the dev Roku.
# Exits non-zero unless the device reports a successful (or identical) install.
set -euo pipefail
cd "$(dirname "$0")/.."
source .env
app="${1:?app dir}"
zip="build/$(basename "$app").zip"
mkdir -p build && rm -f "$zip"
(cd "$app" && zip -qr -X "../../$zip" . -x '.*')
msg=$(curl -sS --digest -u "rokudev:$ROKU_DEV_PASSWORD" \
  -F "mysubmit=Install" -F "archive=@$zip" \
  "http://$ROKU_IP/plugin_install" | grep -oE '"text":"[^"]*"' | cut -d\" -f4 || true)
echo "$msg ($(du -h "$zip" | cut -f1) zip)"
grep -qE "Install Success|Identical" <<<"$msg"
