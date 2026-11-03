#!/usr/bin/env bash
# Usage: tools/sideload.sh <app-dir>   — zips the app and installs it on the dev Roku.
set -euo pipefail
cd "$(dirname "$0")/.."
source .env
app="${1:?app dir}"
zip="build/$(basename "$app").zip"
mkdir -p build && rm -f "$zip"
(cd "$app" && zip -qr -X "../../$zip" . -x '.*')
curl -sS --digest -u "rokudev:$ROKU_DEV_PASSWORD" \
  -F "mysubmit=Install" -F "archive=@$zip" \
  "http://$ROKU_IP/plugin_install" | grep -oE '"text":"[^"]*"' | cut -d\" -f4
