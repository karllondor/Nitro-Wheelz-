# Car reference package — standard (v0.1.31)

What a new car (or a new version of a car) needs before modelling starts, how references are stored, and how
confidence is recorded. Based on the E30 Blessed research package (assets/references/drafts/e30_blessed_v0.1), the
Lada concept sheets and the RYU-32 CLEAN sheet.

## 1. What the owner sends

| Item | Why | Lada | RYU-32 | E30 |
|---|---|---|---|---|
| orthographic side, front, rear, top views (one sheet is fine) | proportions, lamp / grille / bumper positions; overlay with `ortho_*` renders | concept sheets (perspective-ish side) | CLEAN sheet (orthographic) | side illustration only |
| a 3/4 view | surfacing, kit, stance | yes | yes | photos |
| real photos (any angle) with the source | details, materials, wheels, stance | none | none | NIGHTRIDE photos (camera-matched) |
| every look as its own render (e.g. CLEAN and LIVERY) | livery texture | RED + WHITE sheets | **LIVERY missing** | — |
| wheel close-up | wheel design, lip, dish depth | from the sheets | from the sheet | photos (face unconfirmed) |
| engine bay close-up if visible | engine layout | sheet | sheet (inline) vs spec (V8) | — |
| key dimensions / spec | length, width, height, wheelbase, track, engine | catalog | sheet table + catalog | owner-manual mirror |

Missing items are never invented silently: the report lists them, the model marks them (e.g. "PROVISIONAL" livery)
and the owner is asked for them.

## 2. Storage and licences

- Owner-provided images and third-party photos stay **out of the repository** unless the owner states they may be
  published; comparisons that contain them are reviewed in the session only. Committed evidence contains our renders.
- Research metadata (manifests, measurement notes, confidence tables) may be committed under
  `assets/references/drafts/<car>_<version>/`. `assets/references/approved/` is changed only by the owner.
- Record every source in the car report and in docs/LICENSE_AND_SOURCES.md when it shaped the asset.

## 3. Confidence levels (use them in every measurement table)

| Level | Meaning | Example |
|---|---|---|
| CONFIRMED | published / owner-stated value | E30 factory length 4.325 m; gameplay footprints |
| VISUAL ESTIMATE | measured on a reference image with a stated scale | Lada roof 1.34 m from the sheet scaled to 4.166 m |
| APPROXIMATION | design that follows a reference without resolving its details | wheel spoke shapes, vent counts |
| PROVISIONAL | stand-in for a missing reference | RYU-32 LIVERY |
| CONFLICT | references disagree; the report says which one wins and why | RYU-32 sheet inline engine vs the V8 spec |

## 4. Measuring a reference (what worked)

1. Crop each view; scale with a known length (catalog length or wheelbase) and the ground line (tyre bottoms).
2. Read positions in metres: overhangs, roof, belt, bonnet line, lamps, grille, bumpers, arches, wheel radius.
3. Scale overhangs so length and wheelbase match the gameplay values exactly.
4. Photos: solve the camera from 7–13 keypoints (E30) and overlay the render; blueprints: render orthographic views
   (`capture_car_views.gd` `ortho_side` / `ortho_front` / `ortho_rear`) and overlay at equal scale.
5. Sample colours on the reference (highlight / mid / shade) instead of guessing; studio tints (e.g. the white sheet's
   lavender) are lighting, not paint.
