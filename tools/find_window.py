"""Usage: python tools/find_window.py <plate> <scene.json>

Finds the brightest warm light in the plate (the lit window) and writes its normalized
position into the scene JSON "window" x/y, using build_scene's 16:9 center crop.
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
y, x = np.unravel_index(np.argmax(warm), warm.shape)
p = sys.argv[2]
cfg = json.load(open(p))
cfg["window"].update({"x": round(x / rgb.shape[1], 4), "y": round(y / rgb.shape[0], 4)})
json.dump(cfg, open(p, "w"), indent=4)
print(f"window at {x},{y} -> {cfg['window']}")
