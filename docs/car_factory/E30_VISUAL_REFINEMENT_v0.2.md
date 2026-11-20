# E30 Blessed — Visual Refinement Pass v0.2 (test build v0.1.26)

Owner brief: review of the v0.1.24 E30 on the phone (garage screenshots + two recordings). Same model, same pipeline
(Blender Python -> GLB -> Godot), same dimensions, wheelbase, wheel pivots and paint UVs. Handling, audio, scoring and
the other cars are unchanged. **Status: NOT APPROVED — waiting for the owner's review on the phone.**

Evidence (our renders only; the NIGHTRIDE photos are third-party and stay outside the repo):
`docs/car_factory/e30_v02/` — `e30_v02_views.jpg` (front 3/4, side, rear 3/4, top, front, rear; garage studio,
BEFORE top row / AFTER bottom row), `e30_v02_closeups.jpg` (bonnet, A-pillar, grille, headlamps, wheel, tail lamp),
`e30_v02_race.jpg` (race top-down + chase, BEFORE / AFTER), `e30_v02_photo_cameras.jpg` (v0.1 vs v0.2 rendered with
the cameras solved from the three NIGHTRIDE photos). The photo / v0.1 / v0.2 triptych was shown to the owner in the
session (not committed).

## Changes

| # | Brief item | What changed | Where |
|---|---|---|---|
| P0.1 | Bonnet | rounder nose (lip radius 30 -> 44 mm), longitudinal profile rises faster then flattens, more transverse crown (+6-8 mm), softer front corners in plan (radius 65 -> 85 mm), two soft creases bounding a raised centre panel (4 mm), and a separate **shark-nose visor** that leans ~22-32 mm forward over the grille (slightly pointed in plan). The lofted body no longer leans: its leaning end cap was what pushed yellow wedges into the grille | `build_e30_blessed.py`: `top_z`, `crown`, `half_width`, `lip_drop`, `section.top`, `build_nose_visor` |
| P0.2 | A-pillars | the windscreen / rear-window openings now leave 16 mm more body-coloured pillar; the cut walls of those openings are paint (were rubber black); the screen seal is 15 mm instead of 22 mm. Side window frames, B-pillar plates and mirror sails stay black as on the car | `ws_half`, `prism_xy` default key, windscreen seal strip |
| P0.3 | Paint | new factory-car paint shader `nitro_car_paint.gdshader` (the Lada / RYU-32 keep `diecast_paint`): panel light / shadow from the car's own surface orientation (up-facing panels full colour, sides 27 % deeper, warm shift in the shade), paint depth at grazing angles, crisper clear-coat soft-box highlights and a much thinner fresnel film (the old shader added a milky white layer). Signature colour **#F2C40C -> #EFBA0D** (deeper, warmer); saved choices with the old hex are mapped to the new one (`paint_aliases`). The garage and race lights were NOT changed | `nitro_car_paint.gdshader`, `glb_car.gd`, `cars/e30_blessed.json`, `car_cosmetics.gd` |
| P1.4 | Front bumper | new profile: rounded top, moulded groove, straight face, lower lip kicking forward to a softened bottom edge; corner radius 110 -> 130 mm (rear bumper shares the profile) | `_bumper` |
| P1.5 | Grille + headlamps | black grille panel reaches up under the bonnet lip (no yellow showing between the slats); lamps: black housing cup, thin chrome trim ring (was a wide bright bezel), lens set back inside the ring; outer = low beam (vertical flutes, lower prisms), inner = high beam (concentric Fresnel rings), silver reflector and dark bulb shield behind; only a faint glow (no white discs) | `build_front`, `draw_regions` (`tex_headlight`, new `tex_headlight_hi` atlas region) |
| P1.6 | Tail lamps | black frame proud of the lens, slightly convex lens 5 mm inside it, three segments (inner clear reverse 22 %, tail / brake red, outer deeper red) with black divider bars and horizontal optic ribs | `build_rear`, `tex_tail` |
| P1.7 | Signature wheels | wide flat polished step lip that dives into a polished, slightly conical dish (~7 cm deep), concave silver face, eight vent pockets with real 22 mm depth (dark tunnels, polished edge rings), domed centre with 4 nuts and a polished cap. Same tyre size, rim size, hub pivot and outer offset. Exact design still not confirmed by the owner (photos are low-res) | `build_wheels.py: rim_signature` |
| P1.8 | Joints | side rubbing strips end in tapered rounded ends (were flat cut ends); bonnet / grille / visor junction redone (above). Arch lips, door gaps and handles unchanged — no sharp artefacts found there in the close-ups | `build_details` |
| P2.9 | Glass | darker tint, opacity 0.52 -> 0.64; cage and seats stay subtly visible | `nitro_car_glass.gdshader` (factory cars only) |
| P2.10 | Garage size | E30 shown 18 % larger (lens 36 deg -> 30.8 deg, per-car `presentation.garage_zoom`), other cars unchanged; checked on the real mesh over a full turn at phone size (smallest margin to the card edge 1.6 %) | `garage.gd`, `cars/e30_blessed.json`, `e30_factory_car_test` |

## Measurements

| | v0.1 (v0.1.24) | v0.2 (v0.1.26) |
|---|---|---|
| body triangles | 28 666 | 29 510 |
| Signature wheel triangles (x4) | 2 400 | 2 944 |
| car total (body + 4 wheels, measured in Godot) | 38 266 | 41 288 (+7.9 %, budget 42 000) |
| draw calls (body 3 + 4 wheels + shadow) | 8 | 8 |
| `e30_blessed.glb` | 1 026 648 B | 1 060 232 B |
| `wheel_signature_e30.glb` | 91 732 B | 108 536 B |
| materials on the body | paint / atlas / glass | paint / atlas / glass |
| dimensions (body vertex bounds) | 4.331 x 1.791 (mirrors) x 1.199 m | unchanged |

Triangles were held in budget by simplifying flat or hidden parts: planar side glass 8x5 -> 6x3 rows, windscreen
grid 10x12 -> 8x10, wheel-well cylinders 72 -> 56 segments, lamp lathes 36 -> 32 segments, Signature tyre 40 -> 36
segments, vent tunnels 12 -> 10 segments.

## Verification

| Check | Result |
|---|---|
| `tools/run_godot_checks.sh` (import + 29 tests) incl. `e30_factory_car_test` (budget, 3 body materials, dimensions, wheel clearance, cosmetics, garage = race car, new garage-fit check) and `car_profiles_test` (Lada / RYU-32 physics bit-identical) | PASS (local) |
| GLB import | PASS (no import errors) |
| identical BEFORE / AFTER views + close-ups + race cameras | DONE (Xvfb, llvmpipe) |
| comparison with the three NIGHTRIDE photos (solved photo cameras, v0.1 vs v0.2) | DONE; better: black grille panel, body-coloured A-pillars, warmer paint, lamp detail, segmented tail lamps, deep polished dish |
| phone look (screen, brightness, real GPU) | NOT RUN — owner |
| CI Web + Android builds | see docs/QA_MATRIX.md (v0.1.26) |

## Still different from the photos / not done

- The real car's headlamps are switched on in two photos; ours are shown unlit (per the brief: no glowing discs).
- Wheel face design is still an approximation; the photos do not resolve the spoke / vent pattern.
- No badges, plates or stickers are reproduced (policy).
- Bonnet creases are deliberately subtle (4 mm); a stronger version caused uneven reflections on the 8 mm-scale
  mesh.

Revert: this pass is one commit; `git revert <sha>` restores v0.1 of the car (GLBs, shaders, profile and tools).
