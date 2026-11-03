#!/usr/bin/env bash
# Usage: tools/gen_drafts.sh <scene> <seed>...  — one Z-Image-Turbo draft per seed, run serially.
set -euo pipefail
cd "$(dirname "$0")/.."
scene=$1; shift
for s in "$@"; do
  .venv/bin/mflux-generate-z-image-turbo -q 8 --low-ram --prompt-file "gen/prompts/$scene.txt" \
    --width "${W:-1344}" --height "${H:-768}" --seed "$s" --output "gen/drafts/zit_${scene}_s${s}.png"
done
