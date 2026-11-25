# Nitro Wheelz Park 2.0 handoff

**Layout status** · PROVISIONAL. The owner supplied a functional sketch. The implemented geometry follows its spatial arrangement. The footprints, widths, sightlines and materials are review choices.

**Base** · `integration/nitro-dev`, `9d3aab09e329bb342529c0ade8743f23339fa678` (v0.1.45). Feature branch `feat/nitro-wheelz-park-v2`.

Open **PARK → FREE DRIVE** from the main menu. **START TUTORIAL** uses the same scene and the existing lesson flow, detectors, cones, ghost and saved progress. Both cameras continue to use the standard controls.

## Site coordinates

Coordinates are metres in Godot's x/z plane. Positive x is east, positive z is south. Use `game/scripts/park/park_site.gd` for the site geometry and `park_layout.gd` for the training layout.

| Interface | Position or dimensions | Behaviour |
| --- | --- | --- |
| Free drive, tutorial, restart and recovery spawn | `(0, 30)`, heading north, logo at `(0, 0)` | Both menu routes spawn at the same pose. Recovery stops the car and gives an on-screen confirmation. |
| Central plaza | 340 × 260 m | Two donuts, a 19 m large-eight lobe radius, 9 m small-eight lobe radius and the existing 314 m flattened-eight lesson. Existing centre artwork and movable cones. |
| Technical circuit | 14 m wide, about 1,394 m round | Hairpins at both ends and two linked S sections on the plaza side. Painted directions are suggested lines. There is continuous free circulation in both directions. |
| Circuit entrance | Plaza approach `(-142, -107)`, merge `(-233, -193)` | West portal. Take it from the plaza toward the circuit. |
| Circuit exit | Split `(225, -175)`, plaza approach `(150, -110)` | East portal. Remain on the loop or follow the exit toward the plaza. |
| Stunt access | Leaves the east forecourt at `(194, -50)`, skirts the east side of the circuit and joins the north slab near `(129, -358)` | Paved access throughout. Marked approaches and landing areas are driveable. The deck barriers stay in place until a jump model is implemented. |
| Cardboard positions | `Rect2(89, -457, 38, 63)` | Reserved painted pad with placement space for future lightweight obstacles. |
| Paddock parking | `Rect2(-315, -41, 116, 121)` | 24 painted bays, parked cars and an open central drift aisle accessed across the west apron. |
| Service forecourt | `Rect2(189, -61, 116, 76)` | Painted approach, canopy, pumps and a workshop. The roofs hide from view near the player in both cameras. |
| Repair trigger | `Rect2(269, -28, 8, 10)`, entry from the south near `(273, -10)` | At or below 1 m/s for at least 0.65 s, the Park controller emits `repair_requested` once and displays **SERVICE COMPLETE**. Leaving and re-entering rearms the trigger. It has no fuel or economy cost. |
| Industrial yard | `Rect2(174, 31, 157, 75)` | Access from the plaza on the west side. Coloured and branded containers, visible fences and cargo signage. |
| Out-of-bounds | `Rect2(-354, -545, 716, 705)` | Traversable verges inside the envelope. Crossing the envelope returns the car to the plaza spawn. |

## Ramp placement

Every ramp runs north. Coordinates below describe the centre of the usable deck at the approach end. The curb side of each visible closure sits 2.55 m south of the deck. The `RAMPS` records have footprint, rise, approach and landing data for a later physics implementation.

| Ramp | Start (x, z) | Width × run | Rise | Approach / landing length |
| --- | --- | --- | --- | --- |
| Small | (-92, -449) | 6 × 7 m | 1.2 m | 85 / 49 m |
| Medium | (-40, -448) | 8 × 10 m | 2.4 m | 91 / 51 m |
| Large | (30, -449) | 10 × 14 m | 3.8 m | 98 / 49 m |

## Environment and future art integration

- `park_environment.gd` creates named zone nodes and named mesh batches. The material on each batch is replaceable. The terrain verge uses `park_verge.gdshader`. Park lighting and sky are built by `park_track.gd` from the standard environment entry point.
- Park foliage uses opaque, rounded blossom volumes and faceted pine geometry. Static props use opaque geometry or cutout logos, and scenery does not cast expensive real-time shadows. The 32 m contact grid limits vehicle contact candidates to nearby visible objects.
- The Park consumes the existing race scene and car model. Its trigger and mesh placement are Park-local. Preserve the same position records when replacing a fixture, or update its visible mesh and matching solid footprint together.
- Owner QA should cover drift lines through both S bends, the readability of the stunt approach, seeing the parked cars at the device's actual screen size, and the moment the repair-bay roof lifts.

## Verification

Pinned Godot 4.7.2. `park_site_test` drives the starter Lada through the normal race physics from the plaza, through two complete laps and out through the east exit. It checks clear connector centre lines, ramp approaches and landings, real industrial fence contact and repeated visits to the repair bay. `park_layout_test` checks the centre logo, all training layouts, cones and recovery. The evidence package includes the in-engine masterplan, zone views and comparable Linux render measurements.

Capture on Linux with a display at 1280 × 720.

```sh
OUT_DIR=/absolute/evidence godot --path game --audio-driver Dummy --resolution 1280x720 \
  --script res://tests/capture_park_v2.gd
```

Repeat with `-- --bench` for 150 measured frames per pose after warm-up. The same script can run the two plaza poses on the pinned base. The sample is for static render comparison. Validate driving FPS and touch on a physical Android device separately.

### Linux rendering sample

Godot 4.7.2, GL Compatibility, Mesa llvmpipe with four worker threads on AMD EPYC Linux, 1280 × 720. The car was stationary and V-Sync was requested off. Values are measured frame intervals. They include the software renderer and display, and are not a phone FPS estimate.

| View | Median | p95 | Peak draw calls | Peak primitives |
| --- | ---: | ---: | ---: | ---: |
| Base plaza Top-down | 34.62 ms | 38.41 ms | 73 | 32,956 |
| Base plaza Chase | 34.98 ms | 40.16 ms | 74 | 36,040 |
| Park 2 plaza Top-down | 17.41 ms | 19.39 ms | 79 | 78,254 |
| Park 2 plaza Chase | 22.49 ms | 25.23 ms | 102 | 96,660 |
| Park 2 circuit Chase | 19.67 ms | 21.52 ms | 107 | 89,379 |
| Park 2 service Chase | 21.15 ms | 24.52 ms | 112 | 89,427 |
| Park 2 stunt Top-down | 13.16 ms | 15.40 ms | 79 | 58,837 |

Time to create the scene in the benchmark process was 76.9 ms baseline and 157.6 ms for Park 2. The scene performs more geometry work and renders more draw calls. These software-rendered timings characterize the tested environment.
