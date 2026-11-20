# NITRO WHEELZ — TERRAIN-FIRST TOWNSCAPER TRACK BUILDER
**Full integrated implementation brief — 20 November 2026**

## Executive decision (locked)

Build ONE integrated terrain-first procedural 3D track-builder system for **Japan, Poland and Ireland**, each with selectable environment subclasses. No "A/B/C" feature phasing or a country left as a placeholder. Incremental internal commits are fine, but acceptance is for the COMPLETE integrated feature.

**Workflow:** Select country > select biome/subclass > **GENERATE a new deterministic 3D landscape** > draw/edit roads intuitively directly ON that landscape (Townscaper-like interaction) > auto-fit road and nearby terrain > construct region-appropriate scenery and venue facilities > **DRIVE** test. Terrain and the saved track must look identical in builder and race. Generate Terrain must NOT silently replace or generate the road; keep "Generate Track" as a distinct action. Support closed loops **and** point-to-point courses.

Visual direction: gorgeous stylized real-world-inspired terrain; forests, mountains, water and cliffs dominate; track facilities belong in a logically chosen paddock; **never automatically place rows of homes along road barriers**. Traditional Japanese buildings can appear sparingly in appropriate distant settlements and urban buildings in Japan City. No unrelated architectural stereotypes.

This is a development directive, NOT a claim that it is implemented. Full QA / Android testing required before calling done.

## Source baseline and compatibility

Reference branch: `ccr-91dad981-53kkbi`, v0.1.23 Phase A report: `docs/research/procedural_world/PHASE_A_REPORT.md`.

Observed Godot project baseline:
- `game/scripts/ui/track_builder.gd`: `NitroTrackGrid.new(8,12)`; 56 m grid cells; 2-finger pan/pinch and FIT; 8 builder buttons; planar click picking; existing GENERATE creates a loop.
- `game/scripts/world/track_grid.gd`: road-grid / track DNA mapping (inspect before changes).
- `game/scripts/world/drift_track.gd`: nominal half-road width 12 m (thus 24 m full), verge 3.6 m, road/barrier geometry currently extruded at a common Y and planar analytic wall contacts.
- `game/scripts/world/scenery_rules.gd`: 14 m scenery subcells, 2x2-tile scenery chunks; current flat distance-to-road adjacency and buildings.
- `game/scripts/world/procedural_world.gd`: deterministic region scenery/chunk updates shared between builder and race.
- `game/scripts/world/track_dna.gd`: validated Track DNA; ensure compatibility, do not bypass geometry validation.
- Physics is deliberately **planar arcade** and uses validated analytic contacts, not a realistic 3D vehicle simulation. Adding height must not inadvertently change controls, scoring or handling.

Do not rewrite the game blindly. Inspect the actual latest development branch and tests before coding, then migrate carefully. Preserve old saved flat tracks (missing elevation => 0 m) and original flat physics golden trace, camera options, controls and UI.

## World catalogue — all included in initial integrated deliverable

A `country` has several `terrain_archetype` variants, independently from `event_mode` and `road_topology`.

| Region + archetype | Typical target longitudinal road gradient | Surroundings / allowed landmarks |
|---|---|---|
| Japan / Sakura Circuit | 0–3% | sakura petals, mixed Japanese cedar and pine forest, spring hillside, distant village, a small realistic paddock |
| Japan / Forest Drift Park (Ebisu-type) | 0–4% | forested ridges, service roads, compact garages/paddock only, retaining slopes |
| Japan / Touge Mountain | 3–7% | climbing/downhill tight hairpins, stone retaining walls, mirrors, reflectors, cut slopes, sparse distant traditional buildings |
| Japan / City Track | 0–3% | safe closed urban street course, high-rises, rail/expressway structures, konbini/shops, fencing, stands, city garages; no cliff/forest dependence |
| Poland / Ojcow Canyon | 0–4% | golden autumn, deciduous forest, distinctive limestone outcrops, valley, historic structures in the distance |
| Poland / Tatry Mountain | 2–6% | high-alpine slopes, granite rock, dwarf pine/forest bands, retaining walls, mountain outlooks |
| Ireland / Coastal Cliffs | 0–3% | steep Atlantic cliffs, sea at fixed datum, heather/gorse, stone walls, pasture, mist, lighthouse/ruins well away from barriers |
| Ireland / Green Hills | 0–4% | rolling fields, hedgerows, rural terrain, rocky cuttings, distant coastline/ruins |

The numbers are default GENERATOR TARGETS for normal segments, not universal laws; enforce curvature-aware per-segment maximums and smooth transitions; reject or repair unsafe proposals. Allow event states: `practice`, `club_event`, `pro_event` (different crowd/paddock density). A biome can have multiple deterministic visual/weather/lighting presets.

## Terrain-first generation — the non-negotiable buildability rule

A beautiful landscape with nowhere to draw is a failure.

Generate a deterministic `TerrainProfile` from `country`, `archetype`, `seed`, `variant`:
- Terrain heightfield / regional massing for hills, ridges, valleys, highlands;
- Signed-distance or region-mask-driven coastline/cliff edges, ocean mesh at a fixed level and true cliff-face meshes where heightfields alone cannot represent nearly vertical faces;
- Buildable shelf and platform mask, slope/aspect map, geological/vegetation/erosion masks;
- Distributed corridors extending along cliff edges and contours and connective traversable routes over the map. DON'T put one narrow shelf only at a predetermined road location.
- Keep smooth visual variation and large natural-looking blank landmasses to make creative track placement possible.

The preview must visibly indicate constructability before placement, without filling the screen with a hard grid: valid road preview, amber preview for substantial automatic cut/fill or an engineered structure, red only for genuinely impossible geometry. User may see the proposed road shelf and wall BEFORE committing.

**Full paved width must fit, not just the centreline.** Current default road is ~24 m wide, verge ~3.6 m per side, plus barrier/maintenance/collision margin. As first tunable design constraint, protect at least ~40–48 m workable cross-section, preferably 48–56 m in cliffside road corridors. Near a cliff edge the road centre should normally be at least ~20–24 m from the drop before protective work (exact distance derived from track width, local shoulder and barrier geometry). Tight hairpins require a much larger *swept footprint* determined by actual curvature and both inside and outside offset curves, not by a straight-width heuristic.

Where the player draws on a steep slope or along the edge:
1. Attempt locally levelled/graded road bed and **cut-and-fill** (uphill cutting and downhill embankment), preserving the validated road silhouette and safely supporting shoulders/barriers.
2. Add retaining walls, gabions, rockfall nets and embankments when needed.
3. For steep/high/over-water obstacles offer/auto-select bridges or viaducts and properly engineered transitions; tunnels for enclosed crossings where valid.
4. If nothing can be built within configured geometry limits, show a reason and a nearby alternative/drag preview. Never silently collapse a cliff, clip mesh into road, create unsupported asphalt, or produce an abrupt vertical road kink.

This means **terrain is generated before track, then terrain locally adapts to track edits**. Do NOT globally regenerate random terrain whenever a road tile changes: preserve seed and untouched terrain; rebuild only dirty corridor tiles + appropriate neighbors.

Don't interpret "draw anywhere" as demanding a physically viable asphalt road on a literally vertical rock wall without engineering. It means user has broad creative freedom and the system proactively creates viable routes rather than constraining them to one predesigned loop.

## Track and topological design

- Road graph / Track DNA stores 2D footprint geometry + elevation profile, bank/camber profile, width profile and topology.
- Represent centreline spatially as P(s)=(x(s), h(s), z(s)) sampled by distance along road. Geometry and physics collision use the same sample set and road normal; kerbs, verges and barrier foundations follow it.
- Distinguish **longitudinal grade** (up/down), **crossfall / camber** (across road) and **surrounding terrain**. Large cliffs may coexist with a level road.
- For closed loops enforce matching elevation AND tangent/grade at connection (h(0)=h(L), grade(0)=grade(L)); no height seam. For open `point_to_point`, start and finish can be at different heights; don't auto-close or auto-wrap checkpoint/lap code.
- Smooth grade transitions and vertical curvature, especially before hairpins; no discontinuous bumps, car jumps or collider gaps. Support uphill and downhill routes.
- Generator must apply geometry checks using the **true buffered road footprint** including corner sweeps, intersections, barried clearances and other sections. Keep barriers, safety zones and paddocks valid.
- Preserve current 24 m width where appropriate for existing game/drift park tracks, but add **configurable** narrower touge widths as their own validated rules/profiles; never shrink existing layouts unexpectedly.
- Terrain geometry should be chunked with LOD/frustum culling; nearby collidable surfaces accurately match display geometry; ocean and far vistas have separate cheap render paths.

## Townscaper-like interaction — apply to road building, not architecture

Oskar Stålberg's Townscaper demonstrates a simple player action triggering context-sensitive procedural modules that repair themselves according to neighbors. Adapt the *interaction principle*, not its house-generation or mesh source code.

- Touch or drag: build connected spline/tile road with polished automatic corners; auto-fix neighbor geometry and related shoulders/colliders.
- Draw in context on terrain; show a coherent road segment ghost BEFORE placement and update local terrain/retaining solution.
- Tap to place/extend; drag to draw multiple segments; erase; undo/redo. Maintain existing 2-finger pan/pinch and FIT; do not accidentally draw during pinch.
- Explicit `FINISH OPEN ROUTE` and `CLOSE LOOP` controls, road topology displayed in UI. Make these work in both builder/save/DRIVE, scoring and minimap.
- Keep existing eight critical controls/actions accessible; reorganize only where necessary for small mobile screens with a terrain-country selector.
- Separate `GENERATE TERRAIN` (new landscape seed) and `GENERATE TRACK` (if retained). If a track exists, offer `regenerate scenery only` / `regenerate terrain while preserving track via solver`, never silently erase a track.
- Region/world selector, seed/re-roll, optional weather/time-of-day, lightweight grade view and efficient overhead camera are necessary. A top-down editing mode and angled 3D inspection mode both needed.
- Entire edit transaction is atomic: road, locally adapted terrain, safety structures and scenery undo/redo together.

## Physics Developer Mode — keep the fun, measure it

Physics grading is undecided intentionally; make it a tunable **developer-only** option that can be tested on exactly the same track/seed, without changing the player's road or profile.

- `0%` = visually and collision-accurately elevated road, but no longitudinal gravity effect on drivetrain/acceleration (baseline grade force off).
- `25%`, `50%`, `75%` = scaled longitudinal grade-force response.
- `100%` = full real gravitational **longitudinal component**, NOT a misleading claim of fully realistic complete car dynamics.
- Separate toggles or controls for camera slope pitch behavior, longitudinal downhill acceleration/braking effect, traction/load transfer (if modeled), road banking and vehicle grounding. Do not hide independent changes behind a single slider.
- Default test preset: 0% (protect existing drift feel). Add quick switching without rebuilding terrain/road, and a reset control.
- Display telemetry (grade %, elevation m, speed, drift angle, points, yaw/steering/handbrake state, grounding/wheel contact if represented, FPS, physics frame time) and optionally export a test report of identical drives.
- Preserve deterministic fixed-step inputs, original flat-track `golden trace`, and verify that no new rise or descent causes unwanted airborne car state or barrier escape.
- Evaluate handling by recorded videos and metrics before selecting player-facing defaults; don't assume physical slopes help or hurt fun.

## Procedural placement / asset policies

Zones derived from road/terrain/country/event:
1. Track safety ribbon and free space (strict hard exclusion);
2. natural edges / cliffs / cuts / embankments / forest, terrain buffers;
3. access roads, one or few land parcels for paddock/pit/parking;
4. spectator/event areas (safe, accessible positions, crowd only when needed);
5. distant country-specific scenery and towns.

Guarantee facilities are on suitable graded/level pads, accessible by service routes and not randomly repeated by every tile. No homes at trackside. Region modules:
- Japan: sakura, pines/cedars, appropriate cliffs, culturally plausible signage and small rural buildings in distance; **Japan City** must have modern skyscrapers/apartments/shops/expressways, not mountain huts.
- Poland: golden autumn trees; Ojców limestone, Tatry granite/high-alpine rock (do not swap); regional wooden architecture only where contextually valid.
- Ireland: Atlantic water, cliffs/green hills, heather/gorse, stone walls, sheep as distant optional static details, lighthouse/ruins far away.
- Common: proper tyre walls/guardrails, rescue and marshals, tent, parking, pit bays, towers, spectator areas, drainage, banners. Safety first, no props in road corridor.

## Data design and determinism

Suggested versioned track data fields (adapt to existing schema):
- `world: {country, archetype, terrain_seed, terrain_version, event_mode, light_weather, scenery_seed}`
- `builder: {road_graph, topology, grid_layout, width_profile, ...}`
- `elevation: {version, anchors, grade_rules, bank_profile, solver_settings}`
- `terrain: {generator_version, params, local_cut_fill_road_deformations, engineered_structures}`
- `physics_dev: {grade_force_scale, ...}` stored separately from production physics, or only in local dev config.

Use deterministic seeded generation across desktop, Android and Web; same seed and track shape => identical heights, coastline, materials, structures and collisions. Include migration: legacy flat tracks => elevation=0 and retain old scoring/physics unchanged. Keep builder vs race identical. Generate stable chunk IDs and edit scopes. If no matching valid terrain/track reconstruction, fail safely (do not spawn scenery over track).

## Implementation & QA acceptance — integrated release gate

**All of the following must pass before describing complete:**

1. Each of the 3 countries and every listed subclass generates at least 10 different deterministic terrain seeds, with visibly distinct but culturally/geologically correct landscapes.
2. Ireland coastal test: build along cliff crest, around a hairpin and along an inland contour; proof both road edges/shoulders/barriers fit, cliff not flattened globally, no pavement suspended over void.
3. Tatry + Japan Touge: working up-and-down sequences, valid roads and colliders, continuous closed loops, correct open routes with distinct start/finish.
4. Ojcow + Sakura: mainly gentle road grades with independently dramatic rocks/forests; no forced hill climbs.
5. User can draw/drag/erase/undo/redo with Townscaper-like context rebuild; pinch gestures do not paint; local edits don't alter distant terrain.
6. Match preview/race both top-down and chase camera exactly; no environment pop-through, trees or houses over road, safety zones protected.
7. Slopes at 0/25/50/75/100% run on the *same* road without rebuilding; 0% preserves legacy planar arcade feel, frame-by-frame flat golden trace unchanged.
8. Automated geometry tests for corridor width, road self-overlap, open/closed join constraints, steep slope repair, seam stitching, deterministic seed reproduction, save/reload, legacy migration, road/terrain collision sync, undo/redo, generated structures and safety exclusion.
9. Show screenshots: overhead terrain BEFORE road, mid-build cliff edge with footprint preview, full loop, open Touge route, builder/race matched pair for each country, close-up of cliff shelf cross-section, UI on phone.
10. Android and Web builds plus Godot source and CHANGELOG, QA report, real device FPS and spikes, triangle/draw-call/memory numbers. Explicitly mark tests not performed, rather than claim performance.
11. Do not alter approved existing HUD/pedals/handbrake or core scoring unless expressly required by compatible open-route support.

Performance targets to test rather than assert: usable 30+ FPS on target Android, no multi-second blocking when each road cell changes, terrain/props LOD and chunk rebuild within a reasonable interactive latency, no shader overdraw catastrophes. Document device model and settings.

## Documentation/reference

- Townscaper: https://store.steampowered.com/app/1291340/Townscaper/
- Townscaper implementation deep dive: https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making
- Godot Curve3D: https://docs.godotengine.org/en/stable/classes/class_curve3d.html
- Godot VehicleBody3D limitations: https://docs.godotengine.org/en/stable/classes/class_vehiclebody3d.html
- Original Phase A world report: `docs/research/procedural_world/PHASE_A_REPORT.md`

**Developer instruction:** Deliver full system in ONE integrated acceptance scope. You may keep internal commits and tests manageable, but do not present Japan-only or terrain-only as completion. If a part genuinely cannot ship, document its blocker clearly and do not claim completion.
