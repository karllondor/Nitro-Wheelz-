# Terrain Builder — Visual & Track Builder Refinement (test build v0.1.27)

Base: v0.1.25 terrain-first builder (generator, 8 landscapes, tests) + v0.1.26 E30 pass. Nothing was rebuilt from
scratch: physics, scoring, the 8 regions, track saving, open routes / loops, Developer Mode and every existing test
are kept. **Status: TEST BUILD — not approved until the owner plays it on the phone.**

Inputs actually used: the owner's v0.1.25 brief (8 items) and the screenshots / messages sent in chat on
2026-11-20 (Tatry / Touge / Ojców / Ireland builder and race screenshots, the pause-menu screenshot, the Polish
bridge photos, the NW icon). **The two phone recordings and the Tatry builder screenshot named in the brief were
NOT received** in this session; the Tatry occlusion and the other items were reproduced from code and our own
renders, not from those recordings. Reference photos (bridges) are third-party and are not committed.

## What changed

| # | Request | Result | Where |
|---|---|---|---|
| 1 | Camera FIT / Tatry snow & rock masses hiding the builder | the builder camera checks the line of sight to the target and four points around it and raises its pitch until nothing occludes them (the old 40° view sat behind the 380 m Tatry rim); near plane scales with distance; no haze in the overview; the pitch now changes smoothly | `terrain_builder.gd` `_clear_pitch`, `_apply_camera` |
| 2 | Landscape quality in all 8 regions | faceted rocks by geology (boulder, granite slab, limestone pillar / ostaniec, basalt columns) instead of one blob; trees with own proportions, lean and two crown variants per species; rock strata on steep faces in the ground shader (limestone / granite / basalt), slope darkening, softer snow; roadside band (below) | `terrain_scenery.gd`, `terrain_ground.gdshader` |
| 3 | Japan City | street grid painted by the ground shader (asphalt, sidewalks + kerbs, centre / lane lines, zebra crossings, stop lines; rotated and spaced per seed) and filled block by block by zone: downtown towers with podium + setback + aviation lights, office pairs, department store with rooftop billboard and banners; mid ring mansions with balcony bands, offices and shop rows; outer shotengai shop rows with awnings, fascia and vertical signs, convenience stores with forecourt bays, car parks; parks with small shrines (torii + hall); utility poles with wires on side streets, street trees on avenues, traffic signals at avenue crossings. Facades (windows, shopfronts, ribbon glazing, curtain walls) are drawn by a shader, so there is no window geometry. Street-circuit concrete shoulder instead of the dirt verge | `terrain_scenery.gd` `_city_district`, `city_facade.gdshader`, `terrain_ground.gdshader`, `terrain_field.gd` `city_grid` |
| 4 | Ireland coastal cliffs | taller cliffs (54-70 m by seed) with a headland rise, a dedicated rock face with basalt strata and ledges, white surf line, 4-7 sea stacks; the full-width-road-on-the-shelf rule (road + verge + barrier stay on land, 20 m refusal) is unchanged and still tested | `terrain_field.gd`, `terrain_world.gd` `_build_cliff_face` |
| 5 | Seed variants must differ in their main landforms | per seed: mirrored macro frame, macro parameters (canyon meander / width, coast line and bays, alpine rim and tilt, crag level, touge tilt / ridge, terraces) and 2-4 large hills / hollows; still deterministic (same seed = same terrain) | `terrain_field.gd` `_setup_noise` |
| 6 | 56 m grid evaluation + smoother drawing | **evaluated, not implemented** (see below). Drawing got MOVE mode, auto-scroll at the map edge, smooth pan / pinch | — |
| 7 | Region change showing the old terrain | "<LANDSCAPE> SELECTED • NOT GENERATED" card over a dimmed map, DRAW ROAD disabled until generated; generation now shows a loading card | `terrain_builder.gd` |
| 8 | Driving view: speed feel, car vs road | chase camera closer and lower (13.5-19 m back, 7-9.5 m up), lens widens with speed (75.5 -> 83.5°); black / white delineator posts every 20 m on both sides; roadside planting in the top-down view; colour pass (below). The car scale stays x1.15 (approved earlier; it is also the collision footprint) | `race.gd`, `terrain_scenery.gd` |

Owner requests added in chat during the pass:

| Request | Result |
|---|---|
| Map hard to zoom / pan / zoom out; can't move the view while drawing | ✋ MOVE button (one finger pans while building), two fingers always pan / pinch, panning on a fixed ground plane (no jumps over mountains), fling, rotation only after a clear 12° twist, auto-scroll when a stroke reaches the map edge; setup: one finger pans (was orbit) |
| "Looks frozen" while generating / smoothing / loading | loading card: dim + title + 8 spinning dots + chequered progress strip. Terrain generation, road fitting, AUTO, track loading in the builder and the terrain build when a race starts now run in frame slices (the animation keeps moving); AUTO-SMOOTH in the node editor and menu -> race / builder show the card before the work |
| Road destroyed the river; should build a bridge | the stream channel (±11 m) is never filled or cut; a road over it is a bridge; the water runs on under the deck |
| Road "driven into the ground" (2 PIECES) | preview pieces the terrain is not fitted to yet are laid ON the ground (max height across the road width, smoothed) instead of a graded profile that sank into hills |
| Buildability squares look submerged | they are now painted by the terrain shader, so they always lie on the ground (answer: it was a display problem, not real) |
| Same track on another landscape breaks into pieces | NEW LANDSCAPE keeps the whole road, re-fits it and reports red tiles ("ERASE THEM OR CLEAR") instead of silently cutting them out |
| Bridges instead of fills (Polish stone bridges / viaducts) | more than 6 m of fill becomes a bridge (was 12 m); Poland and Ireland get masonry arch bridges whose span and rise follow the valley (low stream bridges = flat arches; deep valleys = round arches on tall battered piers, like a viaduct), spandrels, arch barrels, string courses, parapets with coping; Japan keeps concrete slabs on wall piers |
| Top-down view grey and empty | roadside band behind the barrier: per-region shrubs / flowers / ferns / heather / gorse / dwarf pine / young spruce and small stones 0.9-6 m beyond the verge, plus a forest-edge tree row at the safety strip where it is wooded (trees, boulders and buildings keep the full 14 m strip) |
| Desaturated colours vs the classic tracks | terrain lighting: linear tone mapping (was Filmic), cooler and lower ambient, +12 % saturation, +5 % contrast, DEPTH fog from 220 m (the top-down camera and the road are never hazed) |
| SAVE without a name; can't edit in the editors; no list | SAVE asks for a name (SAVE / SAVE AS NEW when editing); MY TRACKS list in the builder setup opens any saved terrain track; terrain tracks opened from the node editor are redirected to the Terrain Builder; EDIT from DRIVE > MY TRACKS / results already opened them there |
| No way back to editing from pause; pause hard to read | pause: big ▶ RESUME, RESTART + ✎ EDIT TRACK side by side, GARAGE / MENU, settings folded under SOUND & STYLE, darker backdrop |
| Open route start / end look cut off; start lights | staging paddock behind the start (team vans with gazebos, competitor cars in bays, start banner for practice) and a parc fermé after the finish (cars in bays, marshal cabin, chequered flag posts, cones); paved pads on the road's line and height, terrain cut / filled for them; start light pole with four green lamps just before the start line (every event) |
| City: buildings should stand right at the road (street circuit) | a frontage row of shops (awnings, signs), mansions (balconies) and low offices faces the race road on both sides, facades on the sidewalk 5.4-6 m from the asphalt edge (verge 3.6 m + 2.4 m sidewalk), gaps where grid streets reach the circuit, none over bridges / at the venue; capped heights so the top-down view stays clear; the grid blocks, poles and trees stay behind it; the chase camera rises over a building instead of entering it. Facade windows now start at each face's own edge (no cut windows on road-aligned buildings). Test: terrain_scenery_test (>= 20 frontage buildings, nearest facade between verge + 1 m and 6 m) |
| Game icon | the owner's NW crown icon: full-bleed 1024 px (white corners filled), Android 192 px + adaptive foreground with the art in the safe zone + background layer, project icon for Web / desktop. Readable down to 48 px; the crown's thin strokes blur at 32 px |

## 56 m grid — evaluation (item 6, not implemented)

- The grid makes buildability, terrain rules, undo and saving simple and robust (one state per tile, deterministic
  `load_grid`), and the shapes are smoothed by the Catmull-Rom centreline; that is why it stays for now.
- Limits seen on the phone: 56 m tiles force wide hairpins and rectangular-looking layouts; diagonal roads need
  staircases of tiles; fine shape control is impossible.
- Proposed path (Townscaper-like): free stroke -> resample every ~6 m -> smoothing (Chaikin + curvature limit by
  the archetype's minimum radius) -> control points every ~30 m -> the existing Track DNA validation and AUTO-SMOOTH
  repair -> the existing road profile / terrain fit. Tiles would remain as a buildability overlay only. Save format:
  `builder.kind = "stroke"` with the control points (the DNA already stores free control points). Needs its own
  UNDO model (per stroke) and tests (round trip, self-intersection, junction refusal). Estimate: one dedicated pass.

## Measurements (Claude Code cloud container, llvmpipe CPU renderer, 720x1280, seed 1, generated loop)

| Landscape | scene triangles B -> A | scene surfaces B -> A | race top-down frame: draw calls / primitives B -> A | race chase frame: draw calls / primitives B -> A | generate ms B -> A | road fit ms B -> A | race load ms B -> A |
|---|---|---|---|---|---|---|---|
| jp_sakura | 364,532 -> 439,660 | 182 -> 290 | 213 / 93,382 -> 219 / 108,698 | 210 / 159,648 -> 240 / 216,374 | 576 -> 612 | 322 -> 374 | 672 -> 802 |
| jp_forest | 239,744 -> 262,460 | 183 -> 275 | 173 / 95,084 -> 175 / 98,716 | 197 / 123,910 -> 199 / 122,326 | 647 -> 586 | 323 -> 393 | 635 -> 702 |
| jp_touge | 172,178 -> 203,258 | 176 -> 257 | 175 / 97,818 -> 218 / 100,814 | 206 / 109,250 -> 227 / 141,368 | 554 -> 584 | 389 -> 360 | 613 -> 769 |
| jp_city | 156,792 -> 246,078 | 147 -> 178 | 173 / 92,238 -> 175 / 102,470 | 195 / 118,540 -> 199 / 136,078 | 625 -> 833 | 354 -> 433 | 637 -> 1209 |
| pl_ojcow | 379,318 -> 427,542 | 209 -> 347 | 221 / 104,054 -> 229 / 112,256 | 213 / 168,946 -> 243 / 196,608 | 513 -> 738 | 337 -> 406 | 729 -> 861 |
| pl_tatry | 165,074 -> 180,684 | 151 -> 244 | 215 / 97,894 -> 174 / 101,964 | 199 / 122,122 -> 262 / 132,972 | 523 -> 709 | 325 -> 364 | 659 -> 774 |
| ie_coast | 118,220 -> 201,920 | 150 -> 217 | 178 / 106,346 -> 187 / 134,960 | 214 / 134,312 -> 236 / 205,774 | 557 -> 752 | 454 -> 551 | 749 -> 1207 |
| ie_hills | 281,812 -> 327,770 | 154 -> 250 | 177 / 106,352 -> 177 / 117,762 | 201 / 154,598 -> 261 / 180,098 | 548 -> 658 | 400 -> 686 | 733 -> 849 |

Scene triangles / surfaces = everything built (all 30 chunks, before frustum / distance culling). Frame values = what the renderer reported for the captured race frame (Godot RENDERING_INFO). Times = CPU on this container (llvmpipe, desktop CPU); the race load time is the synchronous test path (in the game it now runs in slices behind the loading card).

Phone / browser frame rate, memory and GPU load: **NOT RUN** (no device here). Triangle / draw-call growth comes
from the city district, roadside band (merged into one mesh per chunk) and posts, start lights and bridges; the
race draws scenery chunks only within 650 m (buildings 1040 m).

## Verification

| Check | Result |
|---|---|
| `tools/run_godot_checks.sh` here (import + 29 tests incl. terrain_world / terrain_scenery (city block variety, roadside planting behind the barrier) / terrain_builder / terrain_physics (route start / finish areas + start lights)) | PASS for all 29 tests (PASS lines in the log); the runner itself ended with the timeout code because `terrain_physics_test` did not exit after printing PASS (engine thread spin at exit, container only) |
| Same suite on CI (GitHub Actions, WIP commit 688d87e) | PASS (WIP [godot](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44819502701); v0.1.27 commit aafb14c [godot](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44821411989)); Android APK / Web / desktop BUILT on aafb14c (links in QA_MATRIX) |
| `tools/check_project.py` (structure, SemVer, asset hashes) | PASS |
| Determinism, 8 x 10 seeds distinct, buildability worst seed >= 90 tiles, loops on all 8 within grade, Irish cliff road | PASS (terrain_world_test) |
| BEFORE / AFTER renders for all 8 regions + seeds 1-4, bridges, route ends, UI | DONE (Xvfb, llvmpipe) |
| Performance on a phone / in a mobile browser | NOT RUN |
| Owner review on the phone | NOT RUN |

## Evidence (our renders; `docs/terrain_builder/v0127/`)
- `<archetype>_before_after.jpg` x8: landscape, builder + road, race top-down, race chase; BEFORE v0.1.26 (top) vs
  AFTER v0.1.27 (bottom).
- `<archetype>_seeds.jpg` x8: seeds 1-4 BEFORE vs AFTER (main landform variety).
- `bridges_side.jpg` (Tatry viaduct, Ojców and Ireland stone arches, Japan concrete), `ojcow_stream_bridge.jpg`,
  `route_start_finish.jpg` (Touge / Tatry staging paddock and parc fermé, start lights), `ui_v0127.jpg` (loading
  card full / compact, MOVE, SAVE name, MY TRACKS, pause), `icon_preview.jpg`.
- Tools: `tests/capture_terrain.gd` (+ `ROUTE=1`, bridge side view, frame stats), `tests/capture_terrain_seeds.gd`,
  `tests/capture_bridges.gd`, `tests/capture_ui_v0127.gd`.

## Known limits / not done
- Item 6 free drawing: evaluation only (above).
- Car scale unchanged (x1.15); the road stays 24 m (builder standard).
- Street-circuit catch fencing and rail viaduct for Japan City: not done.
- The headless `terrain_physics_test` can hang at engine exit in this container (an engine thread spins after the
  test printed PASS); it passes in the full suite here and in CI. Recorded, not hidden.
