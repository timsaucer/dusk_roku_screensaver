"""Usage: python tools/layers.py <plate> <depth16.png> <out_prefix> [--near 0.62] [--grow 18]

Splits a plate into a parallax pair using its depth map:
  <out_prefix>_fg.png  RGBA near layer (depth - row ground depth >= near), alpha feathered
  <out_prefix>_bg.jpg  plate with the near layer inpainted, so small shifts show no holes
  <out_prefix>_check.jpg  fg over magenta, for review
"""
import argparse

import cv2
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("plate")
ap.add_argument("depth")
ap.add_argument("out")
ap.add_argument("--near", type=float, default=0.15)
ap.add_argument("--grow", type=int, default=3)
a = ap.parse_args()

rgb = np.array(Image.open(a.plate).convert("RGB"))
d = np.array(Image.open(a.depth)).astype(np.float32) / 65535

# Depth is relative, so compare each pixel with the open ground at the same row: the median
# depth across the central band, forced non-decreasing downward. Occluders (trunks, canopy)
# stand clearly nearer than the ground behind them; open meadow does not.
cx0, cx1 = int(d.shape[1] * 0.35), int(d.shape[1] * 0.65)
ground = np.maximum.accumulate(cv2.GaussianBlur(np.median(d[:, cx0:cx1], axis=1)[:, None], (0, 0), 8)[:, 0])
alpha = np.clip((d - ground[:, None] - a.near) / 0.05 + 0.5, 0, 1)
alpha = cv2.GaussianBlur(alpha, (0, 0), 1.2)
a8 = (alpha * 255).astype(np.uint8)
Image.fromarray(np.dstack([rgb, a8])).save(f"{a.out}_fg.png", optimize=True)

# Fill only under the solid core. Semi-transparent edges then sit over the original pixels
# they came from, so they match instead of showing as pale patches over the fill.
hole = (alpha > 0.5).astype(np.uint8) * 255
hole = cv2.dilate(hole, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * a.grow + 1,) * 2))
# Fill each hole pixel with the color of the nearest pixel outside the hole, then soften the
# fill. Only a thin ring of it is ever seen (as wide as the parallax shift), and nearest-color
# keeps sky next to sky and treeline next to treeline instead of smearing them together.
_, labels = cv2.distanceTransformWithLabels((hole == 0).astype(np.uint8) ^ 1, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
ys, xs = np.nonzero(hole == 0)
lut = np.zeros((labels.max() + 1, 3), np.uint8)
lut[labels[ys, xs]] = rgb[ys, xs]
fill = cv2.GaussianBlur(lut[labels], (0, 0), 3)
bg = np.where(hole[..., None] > 0, fill, rgb)
Image.fromarray(bg).save(f"{a.out}_bg.jpg", quality=90)

chk = np.where(alpha[..., None] > 0, rgb * alpha[..., None] + np.array([255, 0, 255]) * (1 - alpha[..., None]), [255, 0, 255])
Image.fromarray(chk.astype(np.uint8)).resize((960, rgb.shape[0] * 960 // rgb.shape[1])).save(f"{a.out}_check.jpg")
