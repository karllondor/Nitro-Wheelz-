# RYU-32 coupe — Car Factory migration (stage 3, test build v0.1.31)

Owner brief, section 11, stage 3: a Blender model from the approved CLEAN and LIVERY renders + original photos: body
kit, stance, deep wheels, front bumper, lamps, arches, rear wing; blue paint + yellow-red livery; CLEAN and LIVERY share
one GLB and differ only in textures / materials; the Toyota 1UZ-FE V8 on ITBs is visible identically in the garage and
the race; never replace the V8 with an R6; physics and audio unchanged.
**Status: TEST MODEL, NOT APPROVED.** The procedural RYU-32 (`coupe_lowpoly.gd`) stays the default; the new one shows
with DEVELOPER > CAR FACTORY TEST MODELS: ON. DEVELOPER > RYU-32 TEST LOOK switches CLEAN / LIVERY.

## Sources and what was missing

| Source | Used for |
|---|---|
| Owner's "3D MODELING REFERENCE SHEET – CLEAN BLUE VERSION (HOOD REMOVED / ENGINE VISIBLE)" (chat upload, not committed) | orthographic side / front / rear / top views: height 1.29 m, overhangs (front 1.04 / rear 0.89 m), greenhouse, door, lamps, kit, wing, wheel size, engine bay layout |
| gameplay catalog | length 4.545, wheelbase 2.615, width 1.90 m (collisions) |
| car profile `ryu32_v8.json` | 4.0 V8 ITB, 350 HP / 400 Nm (sound + handling, untouched) |
| **LIVERY render** | **NOT RECEIVED.** The yellow / red livery is a **provisional** design drawn by `draw_livery()` in `build_ryu32.py`; it only proves the pipeline. Send the LIVERY render and it replaces this texture without touching the GLB. |
| original photos of the real car | not received in this session; nothing taken from photos |

Conflicts resolved:
- **Engine:** the sheet draws an inline engine with six trumpets; the brief and the car's spec say 1UZ-FE-style V8 on
  ITBs. The model has a V8: block, two heads at 32°, cam covers, eight polished trumpets in the valley (two rows of
  four), headers to both sides, fuel rails, strut brace, battery, catch can.
- **Width:** the sheet lists 1.76 m; the kit here is 1.87 m (mirrors 1.88 m) so the car fills the unchanged 1.90 m
  gameplay footprint.

## Comparison method

Orthographic views were added to `tests/capture_car_views.gd` (`ortho_side`, `ortho_front`, `ortho_rear`): the garage's
16° perspective camera made the roof look longer and the body taller than on the blueprint-style sheet. Overlaying the
orthographic side render on the sheet's side view at the same scale (wheel centres + ground aligned) showed the roof,
windscreen, rear window, door cuts, wheel size, wheelbase and bumpers matching within a few centimetres; the remaining
differences were in the front lamp area (a wide black band, fixed: the lamps now sit in the body-coloured nose), the
wing (now a thick cambered blade with a kicked trailing edge and large end plates) and the exhaust (now a big tip in a
dark bumper cut-out). The overlay images contain the owner's sheet and stay out of the repository.

## Measurements

| | procedural RYU-32 | factory CLEAN | factory LIVERY |
|---|---|---|---|
| triangles incl. 4 wheels + shadow | (procedural) | 38 550 | 38 550 (same mesh) |
| draw calls | many surfaces | 8 | 8 |
| body GLB | — | 1.18 MB | same file |
| livery texture | — | — | 1024² PNG, about 7 KB (provisional) |
| wheels | procedural | `wheel_ryu_5spoke` 2 522 tris (20 in rim look, 0.33 m tyre) | same |
| bounds (L x W x H) | — | 4.553 x 1.885 x 1.294 m (the exhaust tip 8 mm past the bumper) | same |
| handling / V8 sound | ryu32_v8 | identical (test) | identical (test) |

## Verification

| Check | Result |
|---|---|
| `factory_models_test`: switch OFF = procedural coupe; ON = factory GLB; CLEAN and LIVERY use the same GLB, LIVERY sets the paint's livery texture, CLEAN has none; budget, footprint, wheelbase 2.615 m; RYU-32 handling + 8-cylinder engine profile identical on / off | PASS (local) |
| BEFORE / CLEAN / LIVERY from identical garage cameras (7 views) | `ryu32/ryu32_views_before_after.jpg` |
| garage, race top-down, race chase (BEFORE / CLEAN / LIVERY) | `ryu32/ryu32_garage_race_before_after.jpg` |
| close-ups: engine bay, A-pillar, lamps + grille, wheel, rear bumper, tail lamp | `ryu32/ryu32_closeups.jpg` |
| orthographic side / front / rear | `ryu32/ryu32_orthographic.jpg` |
| phone look, frame time | NOT RUN — owner |

## Still different / unconfirmed

- LIVERY design: provisional (no reference).
- The sheet's engine is inline; ours is the V8 the brief requires.
- Interior: bucket seats, dash (right-hand drive), cage with the X behind the seats (sheet); simplified.
- Lamp lenses are textures on flat lenses (two projector rings per side); no lit look.
- Body shading reads slab-sided in the flat garage light compared with the sheet's studio render; geometry matches in
  the orthographic overlay.

## Rebuild

```
python tools/car_factory/blender/build_ryu32.py --out game/assets/cars/ryu32
python tools/car_factory/blender/build_wheels.py --only wheel_ryu_5spoke
xvfb-run ... --script res://tests/capture_car_views.gd -- <out> blue race factory clean|livery
```
