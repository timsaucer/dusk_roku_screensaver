# Credits

Every image that ships in `roku/dusk/images/` must have a row here.

## Images

All plates are AI-generated locally; no third-party photographs are used.
Sprites (fireflies, stars, snow, aurora, petals, ripples, glows) are drawn procedurally by `tools/build_scene.py`.

| Shipped asset | Source | Generator / license | Prompt | Retrieved |
|---|---|---|---|---|
| `fireflies_bg.jpg`, `fireflies_fg.png` | `gen/drafts/zit_fireflies_s13.png`, graded and split into layers | Z-Image-Turbo (Tongyi-MAI), Apache 2.0 | `gen/prompts/fireflies.txt` (seed 13) | 2026-11-03 |
| `snow_bg.jpg`, `snow_fg.png`, `snow_land.png`, `snow_ground.png` | `gen/drafts/zit_snow_s3.png`, graded and split into layers | Z-Image-Turbo (Tongyi-MAI), Apache 2.0 | `gen/prompts/snow.txt` (seed 3) | 2026-11-03 |
| `blossoms_bg.jpg`, `blossoms_fg.png` | `gen/drafts/zit_blossoms_s21.png`, split into layers | Z-Image-Turbo (Tongyi-MAI), Apache 2.0 | `gen/prompts/blossoms.txt` (seed 21) | 2026-11-03 |
| `glow_*`, `star_*`, `winglow`, `aurora_*`, `snowtile_*`, `flake_*`, `petal_*`, `ripple` | procedural | this project | n/a | n/a |

## Tools used to make the assets (not shipped)

| Tool | Use | License |
|---|---|---|
| [Z-Image-Turbo](https://huggingface.co/Tongyi-MAI/Z-Image-Turbo) via [mflux](https://github.com/filipstrand/mflux) | plate generation | Apache 2.0 (model), MIT (mflux) |
| [Depth Anything V2 Small](https://huggingface.co/depth-anything/Depth-Anything-V2-Small-hf) | depth maps for layer splits | Apache 2.0 |
| [libimagequant](https://pngquant.org/lib/) via `imagequant` | palette PNG quantization | GPL v3 (build-time only; outputs are not covered) |
| PhotoCraft | color grading | user's own tool |
| OpenCV, Pillow, NumPy | image processing | Apache 2.0 / HPND / BSD |
