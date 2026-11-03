# Roku Streaming Store listing

Text and assets for the Developer Dashboard (developer.roku.com). Limits are from Roku's
publishing guide; lengths were checked when this was written.

## Listing text

**Name** (16/30): Dusk Screensaver

**On-device description** (247/300):

> Three quiet scenes for your TV: fireflies over a meadow at dusk, snowfall under a faint aurora, and cherry petals drifting onto a lantern-lit canal. Pick one or let them cycle. All art was generated for this screensaver and is free to reuse (CC0).

**Online description** (1263/1500):

```
Dusk turns your TV into a calm window at the end of the day. Three scenes, each a still photoreal plate brought to life with slow, continuous animation:

- Fireflies: a cabin with a porch sits across a meadow at late dusk. Fireflies drift above the grass and blink on and off, while stars come out and the windows glow warm.
- Snowfall: a quiet pine forest at night with one lit cabin window. A faint, naked-eye aurora moves behind the trees as snow falls at three depths and settles into the snow.
- Cherry blossoms: a canal in Kyoto lined with paper lanterns. Petals tumble down, land on the water with a small ripple, float, and fade. Now and then a gust sweeps through.

Choose a scene, or cycle through all three every 5 to 60 minutes (Settings > Theme > Screensavers > Dusk > Change screensaver settings). No ads, no accounts, no network access.

About the art: every image was made for Dusk. The three backgrounds were generated locally with the open Z-Image-Turbo model (Apache 2.0), then color graded and split into depth layers. Everything that moves is drawn procedurally. All of the art is dedicated to the public domain under CC0 1.0, and the code is open source under Apache 2.0. Prompts, seeds and source: github.com/timsaucer/dusk_roku_screensaver
```

## Assets

| Field | File |
|---|---|
| Poster, 540x405 | `store/poster-540x405.jpg` |
| Screenshots, 1920x1080 (up to 6) | `store/screenshots/1-fireflies.jpg`, `2-snow.jpg`, `3-blossoms.jpg`, `4-settings.jpg` |
| Privacy policy URL | https://github.com/timsaucer/dusk_roku_screensaver/blob/main/PRIVACY.md |
| Support | https://github.com/timsaucer/dusk_roku_screensaver/issues |

Suggested settings: monetization **Free**; category **Screensavers** (or Lifestyle, if the
dashboard does not offer a screensaver category); rating: all ages; no deep linking (a screensaver
has no content to deep link to).

## Signed package

The package is signed with the developer key generated on the dev Roku (DevID and password in
the gitignored `.env`; keep a copy in a password manager). Every update must be signed with the
same key; after a factory reset, restore it with "rekey" using a previously signed package and
the password.

```sh
tools/package.sh          # installs the --release build and writes build/dusk-<version>.pkg
```

Bump `build_version` (or `minor_version`) in `roku/dusk/manifest` before each new upload.

## Dashboard checklist (done by the account owner)

Roku now calls channels "apps". There is no screensaver app type at creation; the package's
manifest (`screensaver_title`, `run_screensaver*`) is what makes it a screensaver.

1. Developer Dashboard › **Beta apps** › **Create app** (name, countries, default language).
   Beta apps publish immediately via a private link, which tests the signed package outside
   developer mode and runs Static Analysis without store scheduling. Repeat under **Public apps**
   once the beta is clean. In the profile, choose the closest type (Theme), unless a screensaver
   category is offered.
2. Fill in the listing text and upload the poster and screenshots above.
3. Upload `build/dusk-<version>.pkg` on the App package page.
4. Run Static Analysis and App Behavior Analysis; fix anything flagged.
5. Choose countries, add the privacy policy and support URLs, and submit. Public apps are
   scheduled for the second business day at the earliest (not Fridays or weekends).
