# Screensaver project: handoff to Claude Code

Continuing from a claude.ai chat. This note covers the goal, the decisions made, what exists, what's missing, and how I'd proceed with local tools.

## Goal

A relaxing animated screensaver in the spirit of an aquarium screensaver (serenescreen.com) and the Windows starfield. It runs in a browser first, and I may package it as a real screensaver later (platform undecided).

The original demo looked too cartoonish, so the direction changed to **photoreal plates with procedural animation layered on top**: a photo or photoreal render for the background, with fireflies, snow, aurora, and petals animated over it.

## Decisions so far

| Scene | Decision |
|---|---|
| Fireflies | Rustic house **set back in a clearing**, **blue hour**, not on the horizon and not in the foreground. Dark trunks frame the edges. |
| Snow | **Sparse pine forest, aurora borealis in the sky, one small cabin window** as the only warm light. The lamp post was dropped as out of place. |
| Cherry blossoms | The "lanterns waterfront evening" look: a Japan river or canal at dusk with lanterns. Petals should land on the water. A foreground branch gives parallax. |
| Mood | Slow, continuous motion, no sudden events, restrained palette, light GPU load. |
| Sharing | Not shared unless **every image** has a license that allows it (see Licensing). |

Pending feedback from me on the fireflies plate: is the house the right size and distance, and is it too dark or too bright?

## What exists

Everything is in the output folder.

- `dusk-screensaver.html`: the first demo. Three procedural, cartoonish scenes (fireflies, snow, blossoms) with crossfading, keys 1/2/3, A for auto-cycle, F for fullscreen, and a tunables block named `TUNE`. It was published as a claude.ai artifact, so you can ignore the published copy. **It is superseded by the photoreal direction but has reusable animation code.**
- `plate.js`: `buildScene(mk)` procedurally renders the blue-hour fireflies plate. `mk(w,h)` is a canvas factory, so it works in node-canvas and in the browser. It returns `{ plate, mask, horizon, win:{x,y} }`, where `horizon` and `win` are normalized (0 to 1) to the 2400×1350 plate.
- `render.js`: node-canvas harness that writes `plate.png`, `mask.png`, `composite.png`, and a half-size `preview.png`. Run with `npm i canvas && node render.js`.
- `firefly-scene-plate.png`, `firefly-scene-foreground-mask.png`, and `firefly-scene-composite.png`: the exported renders. The mask is a transparent PNG with the near trunks, limbs, canopy, and undergrowth.

**Not built yet:** the page that loads a plate and mask and animates fireflies over it. Only the design below exists.

## Plate + mask contract

Any real photo should drop into this structure.

- `plate`: the background image, 16:9 preferred, shown cover-fit and centered.
- `mask` (optional): same size and aspect as the plate, transparent PNG of the near foreground. It is drawn **after** the far fireflies, so fireflies pass behind trunks.
- `horizon`: the normalized y of the horizon, which drives the depth model.
- `win`: the normalized position of the main window or light, for an optional flickering glow overlay.
- Fireflies live in screen space, so plate to screen is `s = max(W/pw, H/ph)`, with offset `(W - pw*s)/2`.

## Fireflies page design (to build)

- **Depth:** `d = (y - horizonY) / (H - horizonY)`, clamped. `scale = 0.18 + 1.3*d`. Size, speed, and brightness scale with `d`.
- **Draw order:** plate, window glow (additive, flicker), stars if not baked, far fireflies (`d < .88`), ground mist, **foreground mask**, near bokeh fireflies (`d >= .88`), vignette, animated grain.
- **Flash:** a firefly is lit for 30% of its cycle, 4.2 to 5.6 s per cycle, with `env = sin(PI * u^0.65)^2`, where `u` is the position within the lit part.
- **Sync:** weak Kuramoto coupling between neighbors, `K = 0.03` cycles/s, normalized by `max(neighbors, 3)`. Each firefly's frequency retargets every 3 to 10 s so sync forms and dissolves.
- **Sprites:** the crisp glow has a hot core. Close fireflies use a flat-ish bokeh disc.
- **UI:** a file loader for plate and mask, sliders for horizon, window x/y/size, density, and brightness, and a "show guides" toggle that draws the horizon line and window marker.
- **Hosting limits:** a published claude.ai page can't load remote images, so embed images as `data:` URIs (16 MB cap). Scripts load only from cdnjs, jsdelivr, tailwind, and jquery.

## Snow scene design

- Sparse pine forest plate with open sky, plus **procedural aurora**: layered, slowly moving noise curtains confined to the sky, with a faint green tint on snow and branch undersides.
- I want the **naked-eye look**: dimmer and grayer than long-exposure photos.
- Falling snow in three depth layers (blurred near, crisp mid, fine far), a shared slow breeze, and the cabin window as the single warm light.

## Cherry blossom scene design

- The lantern waterfront plate is the light source. Petals tumble in 3D, with `scaleX = cos(flip)` and a minimum thickness so they never vanish edge-on.
- Petals fall slower when face-on and land on the water with expanding ripples.
- Occasional gusts sweep across as a moving Gaussian wind field. A foreground branch sways slightly and gives parallax.

## Why a procedural plate was built, and its limits

The claude.ai sandbox couldn't download photos or run depth models, so I built a blue-hour plate procedurally. Fixes that helped: **defocusing the distant layers** (a down/upsample trick, because `ctx.filter` and `Path2D` aren't available in node-canvas), blurring the near foliage, baked sensor grain, and haze bands. It's much better than the first demo but **still reads as a rendering**: the conifers are clip-art-ish, the fence floats, and the grass has no real texture. The real-photo route closes that gap.

## Plan in Claude Code

1. **Source photos with license metadata.** Find candidates for each scene (see Licensing), download them, and write a `CREDITS.md` row for each: author, license, source URL, and the date retrieved.
2. **Build masks and depth layers.** Run segmentation and depth estimation locally. The foreground mask separates the near trunks and foliage, and the depth map can drive parallax. Check each model's license before using it.
3. **Grade and composite.** Shift daytime shots to blue hour, remove people or fireflies baked into the photo, and add warm window glow. I have a program called **PhotoCraft** built for agentic workflows. Use it where it's the better tool (see Open questions).
4. **Build the fireflies page** per the design above, load the real plate and mask, then **render frames in a headless browser and review screenshots** to tune glow size, timing, and density. In the claude.ai chat I never saw the animation, only the static plate.
5. Repeat for the snow and blossom scenes.
6. Optionally package as a real screensaver (Electron or WebView2 `.scr` on Windows, or a macOS ScreenSaver bundle).

## Licensing policy

I'll only share this if every image qualifies.

- **OK:** CC0, public domain (including US government photos such as the National Park Service), and CC BY if attribution ships with the app.
- **Awkward:** CC BY-SA forces derived images to be shared under the same license. CC BY-NC limits commercial use.
- **Not OK:** CC BY-ND forbids modification, and we will grade and mask.
- **Check the terms:** Unsplash and Pexels licenses allow modification and use in an app but not redistributing the photos as standalone files. Generated images follow each tool's terms.
- Keep `CREDITS.md` current as images are added, and don't ship any image without a row in it.

## Open questions for me

1. How does PhotoCraft expose itself (command line, MCP server, or scripting API), and what can it do (relighting, sky replacement, inpainting)?
2. Keep the procedural fireflies plate, or replace it with a real photo or generated image?
3. Target platform for the final screensaver: Windows, macOS, Linux, or just a fullscreen browser page?
4. Do I want everything bundled into a single HTML file, or an app with an assets folder?
