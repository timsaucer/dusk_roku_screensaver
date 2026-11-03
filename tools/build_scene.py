"""Usage: python tools/build_scene.py <scene> <bg.jpg> <fg.png> [--land land.png] [--scale 1.025]

Packs one scene's layers into roku/dusk/images/:
  <scene>_bg.jpg, <scene>_fg.png  plate layers cropped to 16:9, then scaled up by --scale so they
                                   can drift for parallax without exposing an edge
  <scene>_land.png                 optional non-sky layer, cropped to the rows it covers; its top
                                   row goes into the scene JSON as "landTop"
Also (re)renders the shared sprites: glow_<px>.png, star_<i>.png, winglow.png, and the snow
scene's aurora_<i>.png, snowtile_<i>.png, flake_<px>.png.
"""
import argparse
import json
from pathlib import Path

import cv2
import imagequant
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


def save_rgba(im, path):
    # 256-color palette PNG with alpha (libimagequant): ~3x smaller than RGBA, visually the same,
    # which keeps the package inside the device's sideload space.
    imagequant.quantize_pil_image(im, dithering_level=1.0, max_colors=256).save(path, optimize=True)


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


def update_scene(scene, **kv):
    p = OUT.parent / "scenes" / f"{scene}.json"
    cfg = json.loads(p.read_text())
    cfg.update(kv)
    p.write_text(json.dumps(cfg, indent=4))


def periodic_noise(w, kmin, kmax, rng):
    # Sum of sines with integer cycle counts across the width, so it tiles horizontally.
    x = np.arange(w) / w
    n = sum(rng.uniform(0.3, 1) / k**0.6 * np.sin(2 * np.pi * k * x + rng.uniform(0, 2 * np.pi)) for k in range(kmin, kmax + 1))
    return (n - n.min()) / (n.max() - n.min())


def aurora(seed, w=1024, h=512):
    # A curtain: bright, ragged lower edge; vertical rays; glow fading upward from green into a
    # faint violet top. Tiles horizontally so it can scroll forever.
    rng = np.random.default_rng(seed)
    edge = h * 0.78 - 70 * periodic_noise(w, 1, 4, rng)
    rays = 0.45 + 0.55 * periodic_noise(w, 10, 48, rng) ** 1.5
    folds = 0.25 + 0.75 * periodic_noise(w, 2, 6, rng) ** 1.3
    y = np.arange(h)[:, None]
    above = np.clip(edge[None, :] - y, 0, None)
    v = np.where(y <= edge[None, :], np.exp(-above / (h * 0.26)), np.exp(-(y - edge[None, :]) / 6))
    a = np.clip(v * rays[None, :] * folds[None, :], 0, 1)
    t = np.clip(above / (h * 0.55), 0, 1)[..., None]
    green, violet = np.array([120, 240, 170]), np.array([150, 120, 200])
    px = np.zeros((h, w, 4), np.uint8)
    px[..., :3] = (green * (1 - t) + violet * t).astype(np.uint8)
    px[..., 3] = (a * 255).astype(np.uint8)
    return Image.fromarray(px, "RGBA")


def snow_tile(seed, count, rmin, rmax, amin, amax, size=512):
    # Tileable field of soft snow dots; dots near an edge wrap to the opposite side.
    rng = np.random.default_rng(seed)
    a = np.zeros((size, size), np.float32)
    y, x = np.mgrid[0:size, 0:size]
    for _ in range(count):
        cx, cy, r, al = rng.uniform(0, size), rng.uniform(0, size), rng.uniform(rmin, rmax), rng.uniform(amin, amax)
        dx = (x - cx + size / 2) % size - size / 2
        dy = (y - cy + size / 2) % size - size / 2
        a = np.maximum(a, al * np.exp(-(dx * dx + dy * dy) / (2 * r * r)))
    px = np.zeros((size, size, 4), np.uint8)
    px[..., :3] = (232, 238, 250)
    px[..., 3] = (np.clip(a, 0, 1) * 255).astype(np.uint8)
    return Image.fromarray(px, "RGBA")


def snow_sprites():
    for i in (0, 1):
        aurora(11 + i).save(OUT / f"aurora_{i}.png", optimize=True)
    # Far snow is one tile layer (a full-screen blend costs ~2.6 ms on a low-end stick), mixing
    # fine and slightly larger dots; the mid flakes provide the depth separation.
    fine = np.array(snow_tile(1, 320, 0.6, 1.1, 0.35, 0.65))
    coarse = np.array(snow_tile(2, 120, 1.0, 1.5, 0.45, 0.75))
    fine[..., 3] = np.maximum(fine[..., 3], coarse[..., 3])
    Image.fromarray(fine).save(OUT / "snowtile_0.png", optimize=True)
    # Flakes: soft Gaussian blobs, not flat discs, so near ones read as out-of-focus snow.
    for s in (6, 9, 13):
        radial(s, lambda r: np.exp(-(r * 2.2) ** 2), (235, 240, 252)).save(OUT / f"flake_{s}.png")
    for s in (24, 36):
        radial(s, lambda r: 0.55 * np.exp(-(r * 1.8) ** 2), (235, 240, 252)).save(OUT / f"flake_{s}.png")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("scene")
    ap.add_argument("bg")
    ap.add_argument("fg")
    ap.add_argument("--land")
    ap.add_argument("--scale", type=float, default=1.025)
    a = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    fit(Image.open(a.bg).convert("RGB"), a.scale).save(OUT / f"{a.scene}_bg.jpg", quality=88, optimize=True)
    fg = fit(Image.open(a.fg).convert("RGBA"), a.scale)
    save_rgba(fg, OUT / f"{a.scene}_fg.png")
    if a.land:
        land = np.array(fit(Image.open(a.land).convert("RGBA"), a.scale))
        cfg = json.loads((OUT.parent / "scenes" / f"{a.scene}.json").read_text())
        # The land layer only has to hide sky effects, so cut it off below the lowest point the
        # aurora reaches (curtain y is its bottom edge, in screen px) ...
        margin_y = (land.shape[0] - H) // 2
        bottom = max(c["y"] for c in cfg["aurora"]["curtains"]) + margin_y + 24
        # ... and clear what the near foreground always covers, even at full parallax drift.
        drift = int(max(cfg["parallax"]["fg"]) + max(cfg["parallax"]["bg"])) + 4
        covered = cv2.erode((np.array(fg)[..., 3] == 255).astype(np.uint8), np.ones((2 * drift + 1,) * 2, np.uint8))
        land[..., 3][covered > 0] = 0
        top = int(np.argmax(land[..., 3].max(axis=1) > 2))
        save_rgba(Image.fromarray(land[top:bottom]), OUT / f"{a.scene}_land.png")
        update_scene(a.scene, land=f"pkg:/images/{a.scene}_land.png", landTop=top)
        if "snow" in cfg:
            # Ground layer: the plate from just above the far snow's ground line down, with a
            # soft alpha ramp on top. Drawn over the far snow, it makes that snow vanish into
            # the ground at the right distance.
            bg = np.array(fit(Image.open(a.bg).convert("RGB"), a.scale))
            horizon = cfg["horizon"] * H
            ground_y = horizon + cfg["snow"]["tile"]["depth"] * (H - horizon) + margin_y
            ramp = 80
            gtop = int(ground_y - ramp)
            alpha = np.clip((np.arange(bg.shape[0] - gtop) / ramp), 0, 1)[:, None] * np.ones(bg.shape[1])
            ground = np.dstack([bg[gtop:], (alpha * 255).astype(np.uint8)])
            save_rgba(Image.fromarray(ground), OUT / f"{a.scene}_ground.png")
            update_scene(a.scene, ground=f"pkg:/images/{a.scene}_ground.png", groundTop=gtop)

    sprites()
    if a.scene == "snow":
        snow_sprites()
    print(sorted(p.name for p in OUT.iterdir()))
