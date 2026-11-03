"""Usage: python tools/build_scene.py <scene> <bg.jpg> <fg.png> [--scale 1.025]

Packs one scene's layers into roku/dusk/images/:
  <scene>_bg.jpg, <scene>_fg.png  plate layers cropped to 16:9, then scaled up by --scale so they
                                   can drift for parallax without exposing an edge
Also (re)renders the shared sprites: glow_<px>.png, star_<i>.png, winglow.png.
"""
import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "roku/dusk/images"
W, H = 1920, 1080


def fit(im, scale):
    # Center-crop to 16:9, then resize to the scaled 1080p canvas.
    w, h = im.size
    if w / h > W / H:
        cw = round(h * W / H)
        im = im.crop(((w - cw) // 2, 0, (w - cw) // 2 + cw, h))
    else:
        ch = round(w * H / W)
        im = im.crop((0, (h - ch) // 2, w, (h - ch) // 2 + ch))
    return im.resize((round(W * scale), round(H * scale)), Image.LANCZOS)


def radial(size, profile, rgb):
    # profile(r) -> alpha in 0..1, r in 0..1 from center to edge.
    c = (size - 1) / 2
    y, x = np.mgrid[0:size, 0:size]
    r = np.hypot(x - c, y - c) / (size / 2)
    a = np.clip(profile(np.clip(r, 0, 1)), 0, 1) * (r <= 1)
    px = np.zeros((size, size, 4), np.uint8)
    px[..., :3] = rgb
    px[..., 3] = (a * 255).round().astype(np.uint8)
    return Image.fromarray(px, "RGBA")


def sprites():
    lime = (215, 255, 120)
    # Crisp firefly: hot core plus soft halo.
    for s in (8, 12, 17, 24, 34, 48):
        radial(s, lambda r: 0.6 * (1 - r) ** 2.6 + np.clip(1 - r * 3.0, 0, 1) ** 1.2, lime).save(OUT / f"glow_{s}.png")
    radial(256, lambda r: (1 - r) ** 2.2, (255, 190, 110)).save(OUT / "winglow.png")
    # Stars: tiny cool-white points, 3 sizes.
    for i, s in enumerate((3, 5, 7)):
        radial(s, lambda r: np.clip(1.15 - r * 1.1, 0, 1) ** 1.5, (225, 232, 255)).save(OUT / f"star_{i}.png")


def write_fg_tiles(fg, scene, tile=120):
    # Most of the foreground is transparent; list only tiles that hold content so the Roku
    # blends those regions instead of the full frame.
    alpha = np.array(fg)[..., 3]
    tiles = []
    for y in range(0, fg.height, tile):
        for x in range(0, fg.width, tile):
            if alpha[y:y + tile, x:x + tile].max() > 2:
                tiles.append([x, y, min(tile, fg.width - x), min(tile, fg.height - y)])
    p = OUT.parent / "scenes" / f"{scene}.json"
    cfg = json.loads(p.read_text())
    cfg["fgTiles"] = tiles
    p.write_text(json.dumps(cfg, indent=4))
    total = (fg.width // tile + 1) * (fg.height // tile + 1)
    print(f"fg tiles: {len(tiles)} of {total}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("scene")
    ap.add_argument("bg")
    ap.add_argument("fg")
    ap.add_argument("--scale", type=float, default=1.025)
    a = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    fit(Image.open(a.bg).convert("RGB"), a.scale).save(OUT / f"{a.scene}_bg.jpg", quality=88, optimize=True)
    fg = fit(Image.open(a.fg).convert("RGBA"), a.scale)
    fg.save(OUT / f"{a.scene}_fg.png", optimize=True)

    sprites()
    print(sorted(p.name for p in OUT.iterdir()))
