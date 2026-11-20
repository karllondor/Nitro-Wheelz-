# CLAUDE CODE — NITRO WHEELZ MASTER BUILD BRIEF
## Owner-approved decisions and implementation request — 20 November 2026

**Working repository:** `karllondor/Nitro-Wheelz-`
**Start from development branch:** `ccr-91dad981-53kkbi` (v0.1.23 Phase A). Do not start from stale `main`. Inspect current HEAD and reconcile any newer work before editing.
**Goal:** **Choose a country and scenery subclass → GENERATE a beautiful deterministic procedural 3D landscape → intuitively draw a track over that landscape with Townscaper-like automatic local adaptation → DRIVE it immediately.**
**Scope:** One complete integrated implementation for **JAPAN, POLAND and IRELAND**, all eight subclasses listed below, including closed loops, point-to-point courses, height-aware terrain/road and developer slope-physics options. Do not present a Japan-only prototype, a flat terrain-only experiment, or a visual mock-up as the final delivery. You can use sensible internal commits and verification order; there are NO A/B/C-scope approvals.

## 0. FIRST ACTION — audit references, branch state and older documents

Read IN FULL:
- `docs/research/procedural_world/TERRAIN_FIRST_TOWNSCAPER_TRACK_BUILDER_SPEC.md` (newer controlling technical specification);
- `docs/research/procedural_world/NITRO_WHEELZ_WORLD_RESEARCH_v1.md` (research and geographic environment references);
- `docs/references/drift_tracks/README.md` (source-controlled index of 49 original concept PNGs **HOSTED ON GOOGLE DRIVE**, 12 Claude-safe ZIP packs all under 19 MB, SHA-256 manifest in the repo, and direct file links);
- `docs/references/drift_tracks/MANIFEST.csv` and `docs/references/drift_tracks/{japan,poland,ireland,Overview}/README.md`;
- `docs/research/procedural_world/NITRO_PROCEDURAL_WORLD_BIBLE.md` (algorithms and original diagrams, but old Phase A-only scope and generic town proposals superseded);
- `docs/research/procedural_world/video_frames/README.md` with its 20 teaching-video frames;
- `docs/research/procedural_world/PHASE_A_REPORT.md`, `docs/ART_DIRECTION.md`, `README.md`, `CHANGELOG.md`, `HANDOFF.md` and actual code/tests.

**Library delivery confirmed 2026-11-20:** 49 unique PNGs, six JPG indexes, README and SHA manifest uploaded **as individual files** in a proper country/location hierarchy on Google Drive: [Nitro Wheelz](https://drive.google.com/drive/folders/1H7X-yXy61SczcEWz9ESTj5nYTSjmfwoo) (owned by `karllondor@gmail.com`). 12 **Claude-safe ZIPs** (each under 19 MB) are stored under the same owner's Drive account, with direct file URLs and SHA manifests in `docs/references/drift_tracks/README.md`. Until Drive **General access → Anyone with the link → Viewer** is enabled by the owner, anonymous Claude CLI may encounter authentication errors.

**IMPORTANT:** Do NOT report the visuals as 'missing' or ask the owner to re-upload the 152 MB single ZIP without first testing the GitHub README / Google Drive links. If the Google Drive account cannot access the files, state precisely which permissions need action and continue code work from verified technical guidance. Full PNG bytes are deliberately hosted on Drive, **not committed as binary blobs into GitHub**. Do NOT treat AI-generated image boards as Godot 3D assets or mechanically reliable drawings.

**Source precedence:** current owner decisions in this document > terrain-first spec > Phase A Bible/report. The Phase A technical system may be reused, but its auto-built generic roadside houses and pre-approved visual direction were explicitly rejected. Reconcile older docs rather than allowing contradictory instructions. Inspect actual latest development HEAD and any newer owner commits before changing code.

## 1. APPROVED VISION — landscape FIRST

- Select **country + location/archetype** then generate a **fully procedural 3D terrain seed** BEFORE placing any road.
- Show the generated coast/valley/forest/mountains and enough viable, naturally shaped land to support creative routes. `GENERATE TERRAIN` re-rolls the terrain seed. Keep `GENERATE TRACK` as a separate action if desired. Never erase the user's road without explicit action.
- Player uses touch or mouse to DRAW a spline/road intuitively ON the existing terrain, in the spirit of Townscaper: one simple placement automatically creates coherent corners, verges, slopes, retaining walls, nearby scenery and repaired connections.
- Immediate animated live preview, touch-drag, erase, UNDO/REDO, clear, save and DRIVE. Builder and race reconstruct the same world. Ensure single-finger drawing and two-finger pan/pinch never conflict; FIT and rotate/tilt/overhead view.
- Country, local biome, terrain seed, scenery seed, weather/time-of-day and event intensity must not be conflated. Same seed + saved road = deterministic world across Android, Web and desktop.
- Both **closed circuits** and **open point-to-point routes** are required. Closed loops meet with continuous height and grade; open courses have different start and finish, may climb or descend, with adjusted racing HUD, scoring, minimap and progress logic (no fake laps).

## 2. FULL COUNTRY/LOCATION CATALOGUE IN THE FIRST INTEGRATED BUILD

| Country | Location archetype | Starting grade target, not a universal maximum | Art, atmosphere and distinctive features |
|---|---|---|---|
| Japan | Sakura Circuit | 0–3% | vibrant spring sakura, many pink flowers and fallen pink petals, green hills, Japanese pines and forest, distant authentic village buildings, warm spring light |
| Japan | Forest Drift Park / Ebisu-Gunsai inspired | 0–4% | mountain forest, real cuttings and drops, access roads, sparse garages clustered in paddock, no residential rows |
| Japan | Touge Mountain / Initial D atmosphere | 3–7% | original mountain switchbacks, cedar/pine forest, retaining walls, convex traffic mirrors, signs, natural elevation, remote houses only in context |
| Japan | City Track | 0–3% | dense modern Japanese city: skyscrapers, offices, apartments, train/elevated expressways, konbini, ramen shops, billboards, neon and sakura where realistic, protected closed street course |
| Poland | Ojcow Canyon / Golden Autumn | 0–4% | autumn gold, red and orange broadleaf canopy, scattered leaves, limestone rocks/outcrops and canyon valley, Pieskowa Skala/Ojców scenery inspiration, distant historic landmarks |
| Poland | Tatry Mountain | 2–6% | dramatic high-altitude peaks, granite, steep slopes, alpine forest and dwarf pine, roads on shelves, walls, fog/light beams |
| Ireland | Coastal Cliffs | 0–3% | Atlantic waves, sheer cliffs, green hills, heather, stone walls, mist, lighthouse and castle ruins far from road, wet reflective asphalt |
| Ireland | Green Hills | 0–4% | rolling lush countryside, hedges, pastures, rocky sections, dramatic Irish light and optional distant coastline |

Current production countries: **Japan, Poland, Ireland**. Wales may remain only as an art reference. **USA, Norway, Thailand, New Zealand and Australia** are future candidates, NOT required now; **Germany is not a requested world**. Do not conflate seasons (sakura = Japan spring, golden autumn = Poland, maple foliage for Japan Touge only if specifically selected as an autumn preset).

## 3. ENFORCE BUILDABILITY IN GENERATED TERRAIN

**This is the key constraint.** Terrain generation must provide multiple connected, usable, varied routes on cliffsides, valley floors and mountain contours, not beautiful terrain with insufficient space for the user's own track. Visual guide for buildable surfaces is acceptable, but no ugly pervasive square grid.

Current road nominal full width is **24 m** with **3.6 m verge each side** (~31.2 m before barriers/safety). Start with ~40–48 m engineered/usable track corridors and ~48–56 m preferred cliff-side design space as tunable initial geometry, NOT universal real-world safety standards. Test the true **swept footprint** of the entire curve/hairpin and its outer/inner kerbs, verges, collision barriers and safety areas; a centreline merely fitting is not sufficient.

When drawing along a cliff: locally auto-cut mountainside, construct properly graded road shelf, supporting embankment/retaining wall/gabions/rockfall net, and protective fencing/barrier while preserving cliff panorama. If needed, use a viaduct, raised roadway or tunnel with smooth entrances, not unsupported asphalt. These changes affect only the edited corridor; distant cliffs, forest and coastline must not randomly change. Preview green=valid, amber=requires engineering work, red=unbuildable with an intelligible reason and possible nearby alternative. Do not make one predetermined corridor the only place to build. No world-wide terrain flattening.

Support vertical cliff faces as dedicated mesh geometry rather than abusing a single heightfield. Generate terrain chunks/LODs with seam-safe shading and collision.

## 4. TRUE 3D ROAD AND DEV MODE PHYSICS

Separate **road longitudinal grade**, **road camber/banking**, and **surrounding terrain elevation**. A dramatic 100 m cliff may be beside nearly level asphalt. Build the race surface, edges, kerbs, barriers and collision from one validated height-aware sampled centreline; no seams, holes, overlapping barrier geometry or clipping.

Preserve player-approved **ARCADE DRIFT FUN** rather than forcing realistic hill power loss. Add Developer Mode presets for *longitudinal gravity effect*: `0%, 25%, 50%, 75%, 100%`, switchable on the SAME exact road/terrain without regeneration; 100% means the full longitudinal gravity component only, not a fully realistic vehicle sim. Independently expose camera slope response, grounding, suspension/contact, banking and optional traction/load effects, with fixed-step telemetry and video-friendly diagnostic panel. Start user-facing default at baseline 0% pending the owner's comparison. Benchmark same route using identical input traces and all presets; preserve original flat-track golden physics trace and existing drift scoring. Actual 3D surface collision must remain correct even if grade force = 0%.

Closed-loop joins must match height and vertical tangent; open routes may end at different altitudes. Do not break checkpoint logic, minimap, or lap UI. Preserve HUD and controls including the approved pedal/handbrake layout and camera choices.

## 5. VENUE LOGIC, NOT HOUSE SPAM (Phase A art rejected)

**Technically accepted from Phase A:** deterministic procedural generation, context-sensitive neighbour joining (garage → combined workshop → undo), incremental chunk rebuild, consistent world preview/race, preservation of road DNA/physics, protected road footprint, FIT and multitouch.

**Artistically rejected from Phase A:** boxy generic Polish-village-like houses or residential streets placed next to every Japanese barrier; long, repetitive workshop rows; procedural logic that always spawns a house whenever a road cell is nearby; random countryside neon or Japanese shrines directly on the track.

Core terrain rules: forests, hills, rock formations, cliff coast, mountain background first; infrastructure SECOND, in logically chosen zones. Isolate safety envelope; strategically site **1 or a few** suitable service-paddock pads with garages, pit bays, mechanics' vehicles, parking, trailers, access roads, tents, race control, commentator booth, camera towers, grandstands, pedestrian footbridge, marshals in orange vests, ambulance, fire truck, tyre walls, drainage and real spectator spaces depending on the event. Do not automatically fill every corner with these assets. Crowds may be sparse/animated and clustered; avoid static human pawn rows. Event mode: `practice`, `club`, `pro`.

Traditional Japanese architecture can appear sporadically and plausibly in distant villages at Sakura/Touge; **modern Japanese tall buildings dominate City Track**. Do not insert pagodas/torii at every bend. Limestone for Ojców, granite for Tatry, Atlantic rock and stone walls for Ireland; no cross-country generic reskin.

Keep the stylized die-cast/drift-diorama Nitro Wheelz art language but geographically credible proportions, cohesive materials and attractive time-of-day/weather. Track readability and racing camera are essential. Existing flat road and exact barrier placements are protected, except deliberate validated 3D elevation/width changes.

## 6. INTEGRATION, PERFORMANCE AND TEST ACCEPTANCE

Read actual code first, keep Track DNA validation authoritative; do not 'fix' terrain by modifying the road shape invisibly or dropping collision precision. Version the saved data `world/country/archetype/terrain_seed/scenery_seed/topology/elevation/terrain_deformations/event/physics_dev`. Legacy tracks without height info load as flat and remain playable. Atomic undo/redo of road+terrain+infrastructure; stable chunk IDs; local update not full world regeneration. Maintain Android, Web and desktop builds with identical generation.

**Evidence is mandatory before claiming completion:**
1. 8 archetypes functional with >=10 fixed-seed test examples each, plus local screenshots of real in-engine scenes (NOT AI render substituted as proof).
2. Buildability test: user draws a FULL-WIDTH road on an Irish cliff edge and tight corner, verified road-edge/shoulder/barrier clearance with no mid-air asphalt; verify the generated base supports multiple alternative user placements.
3. Tatry and Touge visible vertical terrain / drivable grades; Ojcow and Sakura milder roads; real coast, forest and city distinction.
4. Loop closure (seamlessly same height/grade) and point-to-point routes (distinct start/finish + progress + scoring).
5. Multi-touch mobile editor can draw, erase, undo, save, regenerate terrain without discarding track, fit and inspect 3D; same terrain and props appear in race.
6. Physics 0/25/50/75/100 grade presets with telemetry; unchanged flat physics golden trace and regression tests of collisions, camera, scoring, HUD.
7. Frame-time, memory, vertex count/draw calls, updates on phone and Web measured; use chunked LOD/instancing, avoid multi-second stutters. Report Android device testing as NOT RUN unless genuinely tested.
8. For every region supply paired builder/race captures, from top-down and chase, paddock and landscape close-ups, before/after terrain fitting, and automated test logs.
9. Deliver source branch/commit, CHANGELOG, QA/HANDOFF, working Android APK, Web and desktop exports, and direct links. **Never claim success without actual build/test evidence.**

If a requirement is blocked, report exactly what is blocked and why; do not silently substitute generic boxes or claim all eight countries are implemented after a single Japan demo. Do not promise an unrun device test.

## 7. CLAUDE EXECUTION ORDER (not separate partial approvals)

1. Audit source, existing tests, docs and actual presence/integrity of the 49-PNG reference pack; reconcile Bible vs newer owner instructions.
2. Write architecture with terrain seed, masks, cliff geometry, buildability solver, road 3D model, topology, scenery zoning and physics dev config.
3. Implement and integrate all eight location archetypes, full editor and game flow; test continuously, no abandoned demo-only modules.
4. Capture and compare visuals AGAINST the imported reference library; repair obvious layout/architecture mismatch.
5. Execute tests, release builds, document measured performance and unverified conditions; report full implementation and missing items explicitly.

**One-line owner acceptance test:** "I select Japan/Poland/Ireland and its location, hit GENERATE to create a stunning procedural 3D landscape, can draw my own viable track along cliffs or hills as effortlessly as Townscaper, and tap DRIVE to play exactly the same world, choosing how much hills affect physics in Developer Mode."

Never copy third-party game source, copyrighted video frames or unlicensed car branding into shipping assets.
