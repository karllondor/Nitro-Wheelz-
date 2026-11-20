# Nitro Wheelz v0.1.25 — Terrain-first Track Builder: report

Brief: [CLAUDE_MASTER_BUILD_BRIEF_2026-11-20.md](../research/procedural_world/CLAUDE_MASTER_BUILD_BRIEF_2026-11-20.md) (takes precedence),
[TERRAIN_FIRST_TOWNSCAPER_TRACK_BUILDER_SPEC.md](../research/procedural_world/TERRAIN_FIRST_TOWNSCAPER_TRACK_BUILDER_SPEC.md).
Architecture: [TERRAIN_FIRST_ARCHITECTURE.md](../research/procedural_world/TERRAIN_FIRST_ARCHITECTURE.md).
Evidence images: [captures/](captures/) (our renders only; the owner's reference images are NOT committed — see "References").

Status: **TEST BUILD for owner review.** Every result below is marked PASS, FAIL or NOT RUN. Nothing marked PASS
was claimed without running the named test or capture in this container (Godot 4.7.2 stable, GL Compatibility,
Linux x86_64, Mesa llvmpipe software rendering for captures).

## 1. What the player gets

`MAIN MENU > TRACK BUILDER > TERRAIN BUILDER`

1. **COUNTRY**: JAPAN / POLAND / IRELAND.
2. **LANDSCAPE**: Japan SAKURA, FOREST, TOUGE, CITY · Poland OJCÓW, TATRY · Ireland COAST, HILLS.
3. **EVENT**: PRACTICE / CLUB EVENT / PRO EVENT (venue size; does not change the terrain).
4. **GENERATE TERRAIN** — builds the landscape for that selection; pressing it again (NEW LANDSCAPE ↻) rolls a new seed.
   Drag to orbit, pinch to zoom, two fingers to pan / twist-rotate, VIEW = 3D / TOP / LOW.
5. **DRAW ROAD ▶** — 12 x 16 tiles of 56 m draped on the terrain; each tile has a dot:
   green = on grade, amber = cut / fill / retaining walls / short bridge / cliff shelf, red = refused, with the reason
   shown in the status line (e.g. `NOT BUILDABLE: SEA / WATER`, `CLIFF EDGE: ROAD + VERGE + BARRIER NEED 21 m`).
6. When a stroke ends the road is solved on the terrain and the **terrain adapts** (cuts, fills, walls, bridges,
   cliff walls) — only near the road. The status line shows the length, max grade and the works needed.
7. **LOOP / ROUTE**, **CLOSE** (connect the ends over buildable tiles), **AUTO** (random buildable loop / route),
   **DRAW / ERASE / ↶ UNDO / ↷ REDO / CLEAR**, **FIT**, **SAVE** (MY TRACKS), **DRIVE**.
8. The race loads the saved descriptor + road and rebuilds the same world. `EDIT` (DRIVE list or results screen)
   reopens a terrain track in this builder.

`DEVELOPER > ELEVATION PHYSICS`: GRADE FORCE 0 / 25 / 50 / 75 / 100 %, CAMERA PITCH, BANKING / BODY ROLL,
GROUNDING SNAP / SMOOTH, SUSPENSION (visual), TELEMETRY overlay. Local setting; never stored in tracks; switchable any
time without regenerating anything. 0 % is the default and gives exactly the flat handling.

## 2. Implementation map

| Module | File | Role |
|---|---|---|
| Catalog | `game/scripts/world/terrain/terrain_catalog.gd` | 3 countries, 8 archetypes as data: relief recipe, max grade, palette, geology, species, tint, water, landmarks, venue, sky, kerb / run-off colours; descriptor `{kind:"terrain", version, country, archetype, terrain_seed, scenery_seed, event_mode, light_weather}` |
| Terrain field | `terrain_field.gd` | deterministic height field (8 m grid, 1120 x 1344 m), masks (water, rock, forest, tint, snow), coast line, canyon stream, tile buildability with reasons |
| Road profile | `road_profile.gd` | full-width terrain target, max-grade (Lipschitz) projection balancing cut and fill, periodic on loops, per-sample engineering classes, knot heights save / expand |
| Track glue | `terrain_track.gd` | tiles -> control points -> Track DNA -> heights -> saved `elevation`; loop / route generators on buildable tiles; CLOSE LOOP path search; canonical loop order |
| World | `terrain_world.gd` | 30 terrain chunks with stable ids + horizon ring + sea + stream + cliff face; local deformation (flat bench 15 m, cut 1.25-1.6:1, fill 0.75:1, walls); dirty-chunk rebuilds; retaining walls, bridges + piers, cliff walls; lighting |
| Scenery | `terrain_scenery.gd` | per-chunk MultiMesh vegetation (15 species), rocks / limestone pillars, hedgerows / dry-stone walls, city blocks, landmarks outside the play area, one venue by event mode, safety exclusion, race draw range |
| Builder | `game/scripts/ui/terrain_builder.gd`, `game/scenes/terrain_builder.tscn` | the UI above |
| Race | `drift_track.gd` (heights, open routes, end caps, region kerbs, terrain world), `race.gd` (car height / pitch, cameras, open finish, telemetry), `drive_model.gd` (`external_accel`) | |
| Physics settings | `physics_dev.gd`, `boot.gd` (ELEVATION PHYSICS page) | |
| Track DNA | `track_dna.gd` | `topology: "open"` routes; broad-phase pair candidates (same results, ~13x faster on long tracks) |

Saved track (schema 1, backward compatible): the old fields plus `topology`, `world` (descriptor) and
`elevation {version, max_grade, knot_heights}`. Derived data (deformation, structures, scenery) is never stored;
it is rebuilt deterministically. Legacy flat tracks have no `world`/`elevation` and load exactly as before.

## 3. Verification

### Automated tests (registered in `tools/run_godot_checks.sh`)

| Test | What it proves | Result |
|---|---|---|
| `terrain_world_test` | 8 archetypes x 10 fixed seeds: same seed = same terrain, 10 seeds = 10 different terrains; worst-seed buildable tiles per archetype (SAKURA 192, FOREST 191, TOUGE 192, CITY 192, OJCÓW 141, TATRY 177, COAST 127, HILLS 192 of 192); a generated loop on every archetype with max grade vs target (SAKURA 3.2/3 %, FOREST 4.2/4 %, TOUGE 7.2/7 %, CITY 1.2/3 %, OJCÓW 4.1/4 %, TATRY 6.4/6 %, COAST 3.2/3 %, HILLS 4.3/4 %); no height step anywhere incl. the closing joint (loops periodic); Tatry / Touge really climb; open routes in Japan, Poland, Ireland; **Irish cliff edge**: a 300 m road whose centre line is 24 m from the drop keeps the full 24 m road + 3.6 m verge on land (verge edge 8.4 m from the drop), gets the CLIFF BARRIER class and 307 m of stone cliff wall; tiles closer than 21 m refused | PASS |
| `terrain_scenery_test` | terrain changes only within 98 m of the road; 4 of 30 chunks rebuilt for a touge loop; removing the road restores the generated terrain bit-exactly; walls / bridges on the pass; nothing solid within verge + barrier strip + 6 m (14.0 m) of the road on all 8 archetypes; exactly one venue per world, practice < club <= pro; city blocks; Irish dry-stone walls; Track DNA broad phase == the former O(n^2) scan (same first error) on 32 tracks incl. 16 deliberately broken; legacy tracks stay flat; a terrain track without knot heights gets heights re-solved (max 0.16 m from the saved profile) | PASS |
| `terrain_builder_test` | 3 countries / 8 landscape buttons / 3 events; GENERATE builds the selection, again = new seed; red tile refused with its reason; drawing adapts the terrain; UNDO / REDO / ERASE / CLEAR restore road **and** terrain exactly; pinch + twist change zoom / yaw and never paint; AUTO loop; CLOSE LOOP reconnects an opened loop; SAVE -> race world identical to the builder world (terrain height hash, structures, scenery counts, road samples + heights, length); EDIT reopens the same road on the same terrain; ROUTE mode + DRIVE file compiles as an open route | PASS |
| `terrain_physics_test` | grade force maths (g*sin(atan(grade)) x preset); car parked on a 6.3 % slope, 2 s, no input: 0 / 25 / 50 / 75 / 100 % -> 0.00 / 0.00 / 0.00 / 0.04 / 0.30 m/s (two runs identical) (monotonic; the model's 0.45 m/s² rolling resistance holds the low presets); full throttle uphill 3 s: 15.8 m/s at 0 % vs 15.0 m/s at 100 %; flat benchmark oval: 100 % grade force = bit-identical trace; snap grounding; nose up when facing uphill; chase camera never inside the terrain; telemetry lists every diagnostic; open route: one lap, finish line ends the run, start / end caps hold the car | PASS |
| `car_profiles_test` (existing golden trace) | Lada baseline physics bit-identical after adding `external_accel` | PASS |
| whole suite `tools/run_godot_checks.sh` (import + 29 tests: 25 existing + 4 new) | no regressions in the existing tests (Track DNA, builder, editor, procedural world, physics golden, HUD, audio, E30) | PASS (local, 2026-11-20) |

### Captures (`tests/capture_terrain.gd`, `tests/capture_terrain_seeds.gd`)

| Evidence | Files | Result |
|---|---|---|
| 8 archetypes x 10 seeds, generated landscape before any road (label: green / amber / red tiles, build ms) | `captures/seeds_<archetype>.jpg`, `captures/terrain_seeds.json` | PASS (rendered, llvmpipe). Note: seeds change meanders, relief detail, tile buildability and scenery; the macro form of each archetype (e.g. the Ojców canyon, the Tatry bowl) stays the same family by design |
| per archetype: builder overview before the road, builder with the road (terrain adapted), paddock close-up, race top-down, race chase on the SAME saved track | `captures/<archetype>_1_terrain.jpg` ... `_5_race_chase.jpg` | PASS (rendered, llvmpipe) |
| visual comparison with the owner's references | section 5 (text; reference images are not redistributed) | done as a written comparison; owner approval NOT RUN |

### Measurements (Linux container, llvmpipe; not a phone)

| Archetype | generate (ms) | adapt road (ms) | race load (ms) | whole-world triangles | draw calls (whole world, before culling) | trees | walls cut / fill / bridge / cliff (m) |
|---|---|---|---|---|---|---|---|
| SAKURA | 446 | 390 | 655 | 364 532 | 182 | 2 837 | 0 / 0 / 0 / 0 |
| FOREST | 786 | 387 | 716 | 239 744 | 183 | 3 798 | 651 / 541 / 41 / 0 |
| TOUGE | 810 | 372 | 670 | 172 178 | 176 | 2 781 | 960 / 477 / 215 / 0 |
| CITY | 745 | 371 | 848 | 156 792 | 147 | 348 | 0 / 0 / 0 / 0 |
| OJCÓW | 792 | 350 | 724 | 379 318 | 209 | 3 148 | 90 / 0 / 71 / 0 |
| TATRY | 761 | 338 | 623 | 165 074 | 151 | 788 | 414 / 775 / 36 / 0 |
| COAST | 900 | 492 | 777 | 118 220 | 150 | 296 | 0 / 0 / 0 / 0 |
| HILLS | 891 | 441 | 802 | 281 812 | 154 | 5 286 | 444 / 194 / 0 / 0 |

Draw calls and triangles are for the whole 1.1 x 1.3 km world; vegetation and rocks are one MultiMesh per chunk and
species, so the frustum culls whole chunks, and in the race they stop drawing beyond 650 m from the camera
(`visibility_range_end`). Track DNA validation of a 900-sample loop: 756 ms -> 56 ms.

| Not measured | Result |
|---|---|
| Android phone frame rate, memory, thermal | NOT RUN (no device in this container) |
| Web browser frame rate | NOT RUN |
| Desktop GPU frame rate | NOT RUN (software renderer only) |

## 4. Rules implemented from the brief

- Road nominal 24 m + 3.6 m verges + 4.4 m barrier / maintenance strip; flat bench to 15 m from the road edge;
  cut slopes 1.25:1 (1.6:1 in rock), fill 0.75:1; retaining walls when a cut exceeds 7 m or a fill 4.5 m; bridge when
  the drop under the road exceeds 12 m or water is under it (canyon stream); refused (red) when the drop exceeds 42 m,
  a cutting 32 m, the road edge is over the sea / cliff, or water is under the road outside the canyon.
- Coast: tiles whose centre is closer than 21 m to the drop are red; 21-40 m amber (cliff shelf); every road sample
  is checked again (road edge + verge + barrier strip must stay on land); near the drop a stone cliff wall is built.
- Vertical cliffs: terrain vertices snapped to the cliff line + a dedicated jittered rock face mesh down to the sea.
- Only the affected area is rebuilt; distant terrain is never flattened; no buildings on road tiles, no rows of
  generic houses beside the track, one venue only, landmarks outside the play area.
- Max grade per archetype is a generator target (Sakura 3 %, Forest 4 %, Touge 7 %, City 3 %, Ojców 4 %,
  Tatry 6 %, Coast 3 %, Hills 4 %); measured max grades stay within +10 %.

## 5. References (owner's Drive library)

Access: the project folder `1H7X-yXy61SczcEWz9ESTj5nYTSjmfwoo` and the Claude Packs folder
`1Dtrh0Rm59azqvKqwoeJ41gsKkPGBrFBc` were publicly readable (HTTP 200, no sign-in) on 2026-11-20. All 12 ZIP packs and
`PACK_INDEX.json` were downloaded; **12 / 12 SHA-256 match** the index; 49 PNG + 6 index JPG, as declared.
The images were kept in the session scratch space only (third-party AI concept art; not committed, per
docs/LICENSE_AND_SOURCES.md).

Inspected individually: Sakura 01 Drift Park Circuit, Sakura 02 Mountain Drift Paddock, Touge 01 Autumn Mountain Road
Overlook, Touge 02 Sunrise Touge Serpentines, City 03 Daylight Urban Circuit Triptych, Ojców 01 Golden Autumn Drift
Circuit, Ojców Concept Board 01 (annotated), Tatry 01 Mountain Event Circuit, Ireland 01 Coastal Drift Circuit,
Ireland 04 Cliffside Circuit Overlook. Inspected only as thumbnails on the index sheets: the other Japan, Poland and
Ireland images (INDEX_JAPAN / INDEX_POLAND / INDEX_IRELAND). Not inspected: Wales (out of scope), Overview / World
Concepts and the asset catalogue sheets beyond their thumbnails.

What was taken from them in this build:

| Reference feature | Implemented |
|---|---|
| kerb colours per region (Sakura / Touge / Tatry blue-white with teal run-off, Ojców and City red-white, Ireland green-white) | yes (`kerb`, `runoff` per archetype) |
| compact pit building with 3 numbered bays + race-control tower, tents, ambulance + fire engine on standby, flags, start gantry, grandstand (pro) | yes, simplified low-poly |
| Japan: snow-capped volcano on the horizon, cedar forests, sakura | yes (generic stratovolcano silhouette, not a replica) |
| Touge: stone / concrete retaining walls on the outside of hairpins, guard-railed serpentines | retaining walls + barriers yes; guard-rail style NOT done (concrete barrier kept) |
| Ojców: white limestone pillars and crags, castle on a crag, autumn colours | yes (generic castle, not a replica of Pieskowa Skała) |
| Tatry: granite peaks with snow, spruce belts, wooden mountain hut with stone base | yes |
| Ireland: dry-stone walls along the road, heather / gorse, tower-house ruin, lighthouse, Atlantic cliffs | yes |
| City: concrete walls with red-white barriers, elevated expressway, mid-rise blocks | partly (red-white kerbs, expressway, blocks; the barrier is still the standard concrete wall) |
| footbridge over the track, spectator crowds, banners / sponsor boards, guard rails, chevron signs, shrines / torii | NOT done |
| photoreal lighting / wet asphalt / volumetric mist of the renders | NOT attempted (mobile GL Compatibility, stylised die-cast look) |

## 6. Whole suite and builds

Local: `tools/run_godot_checks.sh` PASS (import + 29 Godot tests). CI runs (Godot checks, Android debug APK, Web,
desktop) and their conclusions are recorded in docs/QA_MATRIX.md (v0.1.25 section) after the push.

## 7. Known limits / next steps

- The tile grid (56 m) decides where a road can run; a cliff-hugging road needs the coast to pass close to a tile
  centre (the 24 m test road is built from control points, not tiles).
- Physics stays planar: no jumps or airtime, no banking in the road surface (roads are level across), grade force
  only along the road. Rolling resistance (0.45 m/s²) holds a parked car below ~4.6 % grade.
- Builder adaptation runs on the main thread (~0.35-0.5 s per edit here); on phones it will be slower — NOT measured.
- Horizon ring is untextured low-poly terrain without trees.
- Several reference elements listed as NOT done above.
