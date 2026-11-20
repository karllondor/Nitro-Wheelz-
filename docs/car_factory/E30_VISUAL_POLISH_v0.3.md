# E30 Blessed — Final Visual Polish v0.3 (test build v0.1.29)

Owner brief: "E30 BLESSED FINAL VISUAL POLISH v0.3" after reviewing v0.2 on the phone. Same model and pipeline
(Blender Python -> GLB -> Godot), developed from v0.2 (no restart). One car = one model: the same GLB, geometry and
details in the garage and the race, no LOD variants, nothing hidden while driving; paint / wheel / livery swapping
kept. **Status: NOT APPROVED — waiting for the owner's review on the phone.**

Session model: reported to the owner in the chat (model identifiers are not written into repository files). Tools: Blender Python module bpy 5.3.0,
Godot 4.7.2 (GL Compatibility; headless tests, Xvfb + llvmpipe renders), OpenCV camera matching from the v0.1
package tools, Pillow for sheets.

## Audit of v0.2 against the NIGHTRIDE photos (camera-matched, RMS 21-23 px = 2.5 % of the keypoint span)

| Finding (v0.2) | Evidence | Action in v0.3 |
|---|---|---|
| Paint read as a flat plastic colour: one value over a whole panel, no reflections following the curvature | renders: door = (211, 157, 7) everywhere; photos: bright upper panels, darker lower, reflection lines on the shoulder | clear-coat horizon reflection (below) |
| Shaded side looked muddy only in places; hue itself was right | measured: render side hue 44°, sat 0.97; photo shaded side hue 42° | chroma kept in the panel shading (no ochre drift) |
| Polished wheel lip and machined face had the same brightness -> flat wheel | close-ups | roughness-dependent horizon reflection + geometry |
| Front / rear bumpers were single tall black slabs; side wraps too tall at the arches | photo 02 / 03: upper bar with a rubber insert, the lower apron set back, a small front lip; short side wraps | new bumper profiles |
| Kidneys shorter than in the photos | photos: kidneys rise above and below the lamps | +12 mm height |
| Bonnet slightly flat | photos: one gently domed panel | +5 mm transverse crown |
| Tail lamps flat, exhaust tips plain pipes | photo 03 | deeper lamp frame, recessed lens; rolled chrome tips with a sooty bore |
| Garage card: much empty space; fixed 1.18 zoom | owner + screenshots | controlled framing for every car |
| A-pillars, seals, frames, roof-glass joins, cage / seat visibility | close-ups from several angles | checked, **no change** (body-coloured pillars and 15 mm seals from v0.2 are right; glass NOT darkened — the cage and seats remain visible from the side and the front) |

## What changed

| Area | Change | Where |
|---|---|---|
| Paint (all colours / finishes) | the clear coat reflects a world-space studio horizon (bright above, dark floor below; sharpness `horizon_sharp`) instead of a vague view-space dome, so the shoulder crease, bonnet crown, arch lips and bumper corners each show a reflection line that moves with the car; slightly stronger coat at normal incidence; the panel shading keeps its chroma (golden shade, no olive / ochre). Same shader for every paint the garage offers. Lights and scene brightness unchanged | `nitro_car_paint.gdshader` |
| Chrome / metals | the atlas material reflects the same horizon with a sharpness that follows roughness: polished lips, kidney surrounds, lamp rings and exhaust tips show crisp bright-over-dark bands (mirror polish); machined faces a soft gradient | `nitro_car_atlas.gdshader` |
| Signature wheels | step lip 8 mm wider (radial 4.2 cm), dish 1 cm deeper (8 cm), a dark contact-shadow ring where the polished dish meets the face, a more concave face (centre 6-7 mm deeper), vents set into the face. Same tyre, rim size, hub pivot and outer offset | `build_wheels.py: rim_signature` |
| Bumpers | new profiles: pronounced upper bar with a recessed rubber insert band, the lower apron set back 3 cm, a small front lip; side wraps 28 % lower with a straight bottom edge, height growing inside the rounded corner (the earlier sloped edge looked like a fin); front plate moved onto the bar, intake slot into the apron | `build_e30_blessed.py: _bumper, BUMPER_PROFILE_*` |
| Kidney grille | 12 mm taller (rises above / below the lamps as in the photos) | `build_front` |
| Bonnet | +5 mm transverse crown (0.031 -> 0.045 m at the cowl) | `crown()` |
| Tail lamps | frame 2 cm deep (was 1.4), lens recessed inside it, deeper divider bars | `build_rear` |
| Exhausts | rolled, flared chrome tips with a sooty bore on the existing pipes and position | `build_rear` |
| Garage presentation | controlled framing for every car: the lens is fitted to the car's real silhouette (extreme vertices in 24 plan directions x 3 height bands) every frame; the widest angle of a full turn is the floor (never clipped), narrower views zoom in by at most 22 %; camera a little higher (product shot, ~16°). No other garage element changed | `garage.gd` |
| Budget | arch-lip tubes 8 -> 6 sides (invisible change) to pay for the new detail | `arch_lips` |

## Measurements

| | v0.2 (v0.1.26) | v0.3 (v0.1.29) |
|---|---|---|
| car total in Godot (body + 4 wheels + shadow) | 41 288 | **41 502** (budget 42 000) |
| body triangles (Blender) | 29 510 | 29 436 |
| Signature wheel triangles (x4) | 2 944 | 3 016 |
| draw calls | 8 | **8** |
| `e30_blessed.glb` | 1 060 232 B | 1 054 924 B |
| `wheel_signature_e30.glb` | 108 536 B | 111 272 B |
| garage lens (widest angle) / smallest margin over a full turn | 30.8° / 1.6 % | 26.7° / 5.0 % (car ~15 % larger at the widest angle, up to 22 % more at front / rear views) |
| dimensions, wheelbase, wheel pivots, UV / atlas layout, materials | — | unchanged |

Shader cost: one extra 3x3 transform and two smoothsteps per pixel on the car only. Phone frame time: NOT RUN.

## Verification

| Check | Result |
|---|---|
| `tools/run_godot_checks.sh` (import + 29 tests) incl. `e30_factory_car_test` (budget, 3 body materials, dimensions, wheel clearance, cosmetics, garage = race car, garage framing inside the card at every angle and not leaving > 12 % empty margin) and `car_profiles_test` (Lada / RYU-32 physics bit-identical) | PASS (local) |
| GLB import | PASS |
| BEFORE / AFTER, identical garage cameras: front 3/4, rear 3/4, left, right, front, rear, top, garage screen, race top-down, race chase + close-ups hood, A-pillar, grille + lamps, Signature wheel, rear bumper, tail lamp (`tests/capture_car_views.gd`) | DONE -> `docs/car_factory/e30_v03/` |
| v0.2 vs v0.3 from the three solved NIGHTRIDE photo cameras (our renders only; the photo overlays were reviewed in the session and are not committed) | DONE -> `e30_v03_photo_cameras.jpg` |
| CI (Android / Web / desktop) | see QA_MATRIX for the commit |
| phone look | NOT RUN — owner |

## Still different from the photos / unconfirmed

- Signature wheel face: vent count and spoke pattern are not resolved by the photos (kept as the v0.2 approximation).
- The photos show more rear negative camber and more tyre stretch than the model; not changed (no measurement, and
  the wheel clearance test geometry would change).
- The real car's headlamps are lit in two photos; ours stay unlit (no glowing discs, per the v0.2 brief).
- No badges, roundels, plates or window banners (rights).
- Paint vs photos: the photos are lit by daylight / smoke; our studio is fixed. Colour #EFBA0D unchanged.

Revert: the v0.3 car work is one commit (see CHANGELOG 0.1.29); `git revert <commit>` restores v0.2.

## NITRO WHEELZ CAR FACTORY — LESSONS LEARNED

Make standard for every next car:
1. **Camera-matched comparison first.** Solving the photo cameras from 7-13 keypoints and overlaying the silhouette
   finds the real differences (bumper depth, kidney height) in minutes; eyeballing found the wrong ones (the "ochre"
   paint was in fact the right hue).
2. **Measure before changing colour.** Sampling HSV on photo vs render separated a hue problem (none) from a
   reflection problem (the real one).
3. **Reflections, not brightness, sell the material.** A world-space horizon reflection whose sharpness follows the
   roughness makes paint, chrome and machined metal read differently with zero extra geometry. Never brighten the
   scene to fix a material.
4. **Profiles as data.** Bumpers, sections and lips as `(reach, height)` profile tables lofted along a path are
   easy to compare with photos and to tune without new topology; shared by the front and the rear.
5. **Budget by trading invisible geometry** (tube sides, planar glass rows, cylinder segments) for visible detail.
6. **One QA tool for all cars** (`capture_car_views.gd`: same studio, angles and close-ups relative to the car's
   length / width) so BEFORE / AFTER is always identical.
7. **Presentation computed from the real model** (garage framing from the actual vertices), not per-car constants.

Proved inefficient:
- Fixed per-car garage zoom constants (needed re-tuning per car and still left empty space).
- Leaning lofted end caps for nose shapes (v0.1: triangulated into the grille); separate visor parts work better.
- Darkening glass to hide interior simplicity; the owner wants the cage visible — the interior must be modelled
  instead.
- Judging paint on one angle: the effect of a coat change shows only on curved panels and at a turn.
