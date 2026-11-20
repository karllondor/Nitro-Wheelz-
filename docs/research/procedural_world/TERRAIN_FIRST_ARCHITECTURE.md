# Terrain-first Track Builder — architecture (v0.1.25)

Written 2026-11-20 after auditing branch `ccr-91dad981-53kkbi` at 427644f (v0.1.24) against
`CLAUDE_MASTER_BUILD_BRIEF_2026-11-20.md` (controlling) and `TERRAIN_FIRST_TOWNSCAPER_TRACK_BUILDER_SPEC.md`.

## Audit findings (current code)

| Area | Today | Consequence |
|---|---|---|
| Track DNA (`track_dna.gd`) | schema 1, **closed loops only**, Catmull-Rom 12 samples/knot, fail-closed validation (radius, self-intersection, corridor overlap) | open routes need an open-chain compile path; validation stays authoritative |
| Road + walls (`drift_track.gd`) | 2D samples, every mesh at one Y; analytic 2D wall/body contact | height can be added to the meshes without touching contact (roads never cross, so plan-view contact stays exact) |
| Physics (`drive_model.gd`) | planar arcade model, 240 Hz, golden flat trace in `car_profiles_test` | grade force must be an additive, default-zero term |
| Race (`race.gd`) | car at y = 0, cameras at fixed heights, laps by progress wrap (3 laps) | needs road height / pitch / roll, camera terrain clearance, an open-route finish |
| Builder (`track_builder.gd`, `track_grid.gd`) | 56 m tile grid, strokes, UNDO, pinch/pan, FIT, Phase A town | grid + stroke logic reused; Phase A houses are not used by the new builder |
| Phase A world | rejected art (roadside houses) | kept only so old saved Phase A tracks still load unchanged |
| Reference PNGs | hosted on Google Drive | **not accessible from this environment** (all 14 links need a Google sign-in, no Drive connector); art direction taken from the written briefs |

## Data model (saved track, schema 1 + new optional blocks)

```
closed: bool                  # false = point-to-point (new)
topology: "closed" | "open"
world: {kind: "terrain", version, country, archetype, terrain_seed, scenery_seed,
        event_mode: practice|club|pro, light_weather}
elevation: {version, knot_heights: [m per control point], max_grade}
builder: {cols, rows, cell_m, tiles}      # tile order (unchanged meaning)
```
Legacy tracks (no `world.kind == "terrain"`, no `elevation`) load exactly as before: flat, same physics.
Terrain deformation, structures and scenery are **derived** deterministically from (archetype, seeds, road),
so they are not stored. `physics_dev` lives in the local settings file, never in the track.

## Modules

| Module | Role |
|---|---|
| `world/terrain/terrain_catalog.gd` | 3 countries × 8 archetypes: grade targets, relief recipe, water, rock, vegetation, venue rules, light/sky presets |
| `world/terrain/terrain_field.gd` | deterministic height + masks (water, cliff, rock, forest, snow, petals) from `(archetype, terrain_seed)`; baked 8 m grid; per-tile buildability (green / amber / red + reason) |
| `world/terrain/road_profile.gd` | height-aware road: terrain sampling across the full width, periodic (loop) or open smoothing, per-archetype max grade, closed-loop height + grade continuity; per-sample engineering class (on grade / cut / fill / retaining wall / bridge / unbuildable) |
| `world/terrain/terrain_world.gd` | chunked terrain mesh (stable chunk ids), local cut/fill deformation only in the road corridor, cliff faces, sea, horizon ring, lighting; rebuilds only dirty chunks |
| `world/terrain/terrain_scenery.gd` | zoning: road safety footprint (hard exclusion) → natural edges → one paddock pad (or none) → event assets → landmarks/distant settlements; MultiMesh vegetation per species |
| `world/drift_track.gd` | road, kerbs, lines, barriers and start/finish built from the same samples **with heights**; open-route end barriers; `height_at()` for the car |
| `race/physics_dev.gd` | Developer Mode: grade force 0/25/50/75/100 %, camera pitch, banking, grounding, suspension, traction-load, telemetry; switch live in the race |
| `ui/terrain_builder.gd` | Country → Location → GENERATE TERRAIN → draw tiles on the terrain (ghost + buildability colours) → CLOSE LOOP / OPEN ROUTE → UNDO/REDO, ERASE, CLEAR, TRACK (auto), VIEW (top / 3D), FIT, SAVE, DRIVE |

## Key rules

- Terrain first: the builder generates the landscape before any road; GENERATE TERRAIN keeps the drawn road
  (re-solved on the new terrain) and never erases it.
- Buildability by construction: every archetype shapes its play area so a 24 m road + 3.6 m verges + barrier
  margin fits on many tiles; dramatic relief (peaks, cliffs, sea, canyon walls) sits at the edges or crosses
  the area as a feature the road can follow (cliff crest, valley floor, shelves). Tests generate tracks
  automatically on every seed to prove it.
- Road heights come from one solver used by builder and race; closed loops satisfy h(0) = h(L) and matching
  grade; open routes keep different start/finish heights.
- Physics stays planar (exact analytic barrier contact); height only adds visuals and an optional
  longitudinal gravity term `-g·grade·scale` (default 0 %, flat golden trace untouched).
- Scenery never enters the road safety footprint; buildings only in one paddock pad, event zones,
  distant settlements or (Japan City) the urban blocks between streets.
