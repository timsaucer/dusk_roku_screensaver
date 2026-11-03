"""Usage:
  python tools/water.py grid <plate> <out.jpg>
      writes a 1080p copy of the plate with a labeled 100 px grid, for tracing the water outline
  python tools/water.py set <plate> <scene.json> "x,y x,y ..." [--step 12]
      rasterizes the traced water polygon (1080p screen px, build_scene's 16:9 crop) and writes
      "water": {"top": y0, "step": s, "spans": [[x0, x1], ...]} to the scene JSON, one span per
      `step` rows from `top`; also writes <plate>_water_check.jpg

Automatic detection (flood fill) proved unreliable on dark dusk plates: it either stops at the
lantern reflections or leaks into everything, so the outline is traced by hand per plate.
"""
import json
import sys

import cv2
import numpy as np
from PIL import Image


def load_1080(path):
    rgb = np.array(Image.open(path).convert("RGB"))
    h, w = rgb.shape[:2]
    ch = round(w * 1080 / 1920)
    return cv2.resize(rgb[(h - ch) // 2:(h - ch) // 2 + ch], (1920, 1080), interpolation=cv2.INTER_AREA)


if sys.argv[1] == "grid":
    img = load_1080(sys.argv[2])
    for x in range(0, 1920, 100):
        cv2.line(img, (x, 0), (x, 1079), (0, 255, 255), 1)
        cv2.putText(img, str(x), (x + 3, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
    for y in range(0, 1080, 100):
        cv2.line(img, (0, y), (1919, y), (0, 255, 255), 1)
        cv2.putText(img, str(y), (3, y - 4), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
    Image.fromarray(img).save(sys.argv[3], quality=85)
    sys.exit()

plate, scene, poly = sys.argv[2], sys.argv[3], sys.argv[4]
step = int(sys.argv[sys.argv.index("--step") + 1]) if "--step" in sys.argv else 12
pts = np.array([[int(v) for v in p.split(",")] for p in poly.split()], np.int32)
water = np.zeros((1080, 1920), np.uint8)
cv2.fillPoly(water, [pts], 255)

rows = np.nonzero(water.max(axis=1))[0]
top = int(rows.min())
spans = []
for y in range(top, 1080, step):
    xs = np.nonzero(water[y])[0]
    spans.append([int(xs.min()), int(xs.max())] if len(xs) else [0, 0])

cfg = json.load(open(scene))
cfg["water"] = {"top": top, "step": step, "spans": spans}
json.dump(cfg, open(scene, "w"), indent=4)

chk = load_1080(plate)
over = chk.copy()
over[water > 0] = (0, 200, 255)
chk = cv2.addWeighted(chk, 0.6, over, 0.4, 0)
Image.fromarray(chk).resize((960, 540)).save(plate.rsplit(".", 1)[0] + "_water_check.jpg")
print(f"water top {top}, {len(spans)} spans")
