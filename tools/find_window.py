"""Usage: python tools/find_window.py <plate> <scene.json> [--max 3]

Finds the lit windows (bright warm peaks) in the plate and writes their normalized positions
into the scene JSON "windows" list, using build_scene's 16:9 center crop. Glow size and alpha
carry over from the first existing entry. Peaks inside the scene's traced "water" (reflections)
are skipped, so trace the water first.
"""
import json
import sys

import cv2
import numpy as np
from PIL import Image

rgb = np.array(Image.open(sys.argv[1]).convert("RGB")).astype(np.float32)
h, w = rgb.shape[:2]
ch = round(w * 1080 / 1920)
rgb = rgb[(h - ch) // 2:(h - ch) // 2 + ch]
r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
warm = np.clip(r - b, 0, None) * (r + g) / 510
warm = cv2.GaussianBlur(warm, (0, 0), 6)
limit = int(sys.argv[sys.argv.index("--max") + 1]) if "--max" in sys.argv else 3
p = sys.argv[2]
cfg = json.load(open(p))
template = (cfg.get("windows") or [cfg.get("window", {"size": 0.03, "alpha": 0.5})])[0]
cfg.pop("window", None)
# Skip reflections: zero the warm map inside the traced water, if the scene has it.
wat = cfg.get("water")
if wat:
    for i, (x0, x1) in enumerate(wat["spans"]):
        y = wat["top"] + i * wat["step"]
        warm[y:y + wat["step"], x0:x1 + 1] = 0
peak = warm.max()
wins = []
for _ in range(limit):
    y, x = np.unravel_index(np.argmax(warm), warm.shape)
    if warm[y, x] < peak * 0.5:
        break
    wins.append({"x": round(float(x / rgb.shape[1]), 4), "y": round(float(y / rgb.shape[0]), 4),
                 "size": template["size"], "alpha": template["alpha"]})
    # Suppress this peak before looking for the next one.
    cv2.circle(warm, (int(x), int(y)), 40, 0, -1)
cfg["windows"] = wins
json.dump(cfg, open(p, "w"), indent=4)
print(f"{len(wins)} windows: {wins}")
