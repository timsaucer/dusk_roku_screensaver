#!/usr/bin/env bash
# Usage: tools/grade.sh <in.png> <out.png> [exposure-EV]
# Late-dusk grade with PhotoCraft: pull exposure down, sink the mids, cool the shadows.
set -euo pipefail
ev="${3:--0.6}"
~/.local/bin/photocraft-cli run "$1" \
  --cmd image.adjustments.exposure --params "{\"exposure\":$ev}" \
  --cmd image.adjustments.curves --params '{"points":[[0,0],[64,52],[128,112],[255,250]],"blue":[[0,0],[48,56],[255,255]]}' \
  --out "$2" > /dev/null
