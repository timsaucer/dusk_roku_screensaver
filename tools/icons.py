"""Usage: python tools/icons.py <plate>

Writes the channel icons (roku/dusk/images/icon_{fhd,hd,sd}.jpg) from a full plate, with the
title set in Georgia (a macOS system font; rendered into the image, not shipped as a font).
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent.parent / "roku/dusk/images"
src = Image.open(sys.argv[1]).convert("RGB")
font = "/System/Library/Fonts/Supplemental/Georgia.ttf"
for name, (w, h) in {"icon_fhd.jpg": (540, 405), "icon_hd.jpg": (290, 218), "icon_sd.jpg": (246, 140)}.items():
    # Cover-crop a little tighter than the plate, biased slightly below center (the house).
    s = max(w / src.width, h / src.height) * 1.15
    im = src.resize((int(src.width * s), int(src.height * s)), Image.LANCZOS)
    x, y = (im.width - w) // 2, int((im.height - h) * 0.55)
    im = im.crop((x, y, x + w, y + h))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(font, int(h * 0.2))
    tw = d.textlength("Dusk", font=f)
    d.text(((w - tw) / 2 + 2, h * 0.06 + 2), "Dusk", font=f, fill=(0, 0, 0))
    d.text(((w - tw) / 2, h * 0.06), "Dusk", font=f, fill=(242, 230, 208))
    im.save(OUT / name, quality=90)
