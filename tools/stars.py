"""Usage: python tools/stars.py <depth16.png> <scene.json> [--count 70] [--seed 1]

Picks star positions in open sky (farthest depth, away from any tree edge) and writes them to
the scene JSON as "stars": [[x, y, size, phase], ...] in 1080p screen pixels.
"""
import argparse
import json
import random

import cv2
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("depth")
ap.add_argument("scene")
ap.add_argument("--count", type=int, default=70)
ap.add_argument("--seed", type=int, default=1)
a = ap.parse_args()

d = np.array(Image.open(a.depth)).astype(np.float32) / 65535
# Same 16:9 center crop as build_scene, then to 1080p.
h, w = d.shape
ch = round(w * 1080 / 1920)
d = cv2.resize(d[(h - ch) // 2:(h - ch) // 2 + ch], (1920, 1080), interpolation=cv2.INTER_AREA)
sky = (d < np.percentile(d, 2) + 0.02).astype(np.uint8)
# Keep away from leaves and the treeline so parallax never slides a star over them.
sky = cv2.erode(sky, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (41, 41)))
ys, xs = np.nonzero(sky)
rnd = random.Random(a.seed)
stars = []
for i in rnd.sample(range(len(xs)), min(a.count, len(xs))):
    # Fainter toward the horizon, like real sky glow washing them out.
    stars.append([int(xs[i]), int(ys[i]), rnd.choice([0, 0, 0, 1, 1, 2]), round(rnd.random(), 3)])
cfg = json.load(open(a.scene))
cfg["stars"] = stars
json.dump(cfg, open(a.scene, "w"), indent=4)
print(f"{len(stars)} stars from {len(xs)} sky px")
