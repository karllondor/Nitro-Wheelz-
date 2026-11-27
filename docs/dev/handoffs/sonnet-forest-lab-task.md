# OWNER-APPROVED PHASE 1 — TOUGE TREE REFINEMENT (27 NOV 2026)

**This section supersedes the older broader rollout below: begin with TOUGE only.** The owner approved the eight-species forest asset illustration and asks Claude Sonnet to prepare and improve the procedural models on a Touge test route first. No replacement of other biomes or merge to `main` before owner Android review.

## Required reference materials
- Approved art: `APPROVED_FOREST_ASSETS_REFERENCE.png` from the conversation (illustrative concept, NOT a Godot screenshot). Aim for recognisable forms rather than claiming identical geometry.
- Prototype source ZIP: `NITRO_WHEELZ_COMPLETE_FOREST_LAB_8_SPECIES.zip`; SHA-256 `908dbd043400e8033f2344f29823ca87d35b80da9f09c38bfdbca0c70f9c1e87`. **Not committed to GitHub**. User must attach to Sonnet session. Contains `nitro_tree_factory.gd`, species gallery/free camera, road demo, scenes and unexecuted source tests. First compile it and repair issues, don't blindly copy.
- Existing production code: `game/scripts/world/scenery_modules.gd`, `game/scripts/world/procedural_world.gd`, `game/scripts/world/scenery_rules.gd`, and `game/scripts/world/terrain/terrain_field.gd`. Identify the live tree renderer for Touge ROUTE and 3D Builder vs Race, and preserve route consistency.
- Work on existing `feat/sonnet-forest-lab` branch, verify HEAD before committing. No edits to #61 track storage or #62 collision/scoring; avoid conflicting work on shared base.

## A — Improve eight models and autumn variations
1. **Pine** broad asymmetric layered needles and trunk; **Fir** taller/narrower layered tiers; **Birch** light airy crown and white bark with dark dash markings; **Oak** wide irregular crown and exposed thick branches.
2. **Sakura** pink spring blossom clusters, not oversized cubes; **Japanese maple** airy low branching with red/orange/gold autumn; **Rowan** smaller lobed crown with visible red berry clusters; **Shrubs** varied green, flowers and autumn red/orange accents.
3. Keep shared faceted opaque polygon meshes, vertex colours, reproducible species seeds, near/far LOD versions; avoid repeated primitive cones. No downloaded photoreal textures or per-leaf geometry on mass forest.
4. Provide real Godot NEAR close-ups, same-scale profile comparisons and spring/summer/golden-orange-red autumn samples next to approved illustration. List compromises candidly.

## B — Simple Tree Designer for owner QA (developer only)
Provide a lightweight editor/preview to choose **species, LOD, season, height/scale, crown width, foliage density and forest density** and see the effect in 3D. Support mouse orbit or free-fly (RMB + WASD, Q/E, Shift, scroll) and export/import presets as JSON. Keep editing tools out of race HUD. Shape changes may trigger mesh regeneration inside preview, not on every gameplay frame.

## C — Touge-only integration
Integrate as opt-in `CLASSIC / FOREST LAB` mode, with CLASSIC default, on **one Touge test route** first. Preserve original trees on all other tracks. Place denser varied woods on hillsides while retaining views of hairpins and lower serpentines from Chase camera. Use terrain height/slope, deterministic seeds, chunked MultiMesh, clearance around roads, walls, bridges, tunnels, water, pits, starts and finishes. No trees floating or growing through driveable geometry. Golden Hour shadow flicker #48 remains unresolved; avoid enabling dynamic shadows on every tree.

## D — QA gate
- Compile all Godot scripts, run and fix `tests_tree_factory.gd` and test 8 species × 2 LOD × seasonal palettes.
- Compare CLASSIC vs FOREST LAB on identical Touge seed, camera, time of day and hardware: median FPS, p95 frame time, draw calls, memory and generation time, plus a 10-minute warm-device test. Offer LOW/MEDIUM/HIGH forest density and measured graceful downgrade if needed.
- Compare Chase and top-down screenshots by DAY/GOLDEN HOUR/NIGHT, test no view obstruction and no vegetation popping. Ensure mobile GL Compatibility plus Web/PC sanity.
- Submit draft PR, exact commit SHA, real in-game captures, comparative table, Android QA APK and handoff. Owner approval is required before adding other maps or merging to main.

**Deferred:** production-wide asset replacement, whole-season gameplay system, complex artist-modeling tool, scoring/track editing, and automatic main merge.

---
# SONNET TASK — Nitro Forest Lab / Issue #54

Status: **HANDOFF ONLY, NOT IMPLEMENTED**. This file is a task specification. This branch was created from verified PR #58 head `73a03ca6c17c36f76186fd8d1c9468adbf6a5316` and remains isolated from `main`.

## Mission
Bring a richer but lightweight stylized forest to Nitro Wheelz, using procedural Godot 4.x meshes and chunked `MultiMeshInstance3D`. The owner liked a visual concept with natural-looking layered crowns and denser woods, **not photorealistic imported foliage**. Preserve the visual identity of a toy/die-cast arcade drift game.

### Source prototype to request from the owner
An experimental standalone local ZIP exists: `NITRO_WHEELZ_FOREST_LAB_GODOT_PROTOTYPE.zip` (produced in ChatGPT). It contains `nitro_tree_factory.gd`, `nitro_forest_demo.gd`, `forest_preview.tscn`, `project.godot`, `README.md` and `NITRO_TREE_CONCEPT.png`.

**Important:** the ZIP is **not** attached to this GitHub repository. Ask the owner to pass it into the Sonnet coding session, or independently recreate the approach below. The concept art was generated separately, **not a screenshot rendered from the scripts**. Prototype was manually reviewed but **not run in Godot**; treat it as reference code requiring compilation, performance and correctness tests.

### Proposed tree species / geometry
- Layered pine: staggered, irregular overlapping foliage tiers; clear dark trunk
- Tall fir: narrower pointed conifer in multiple foliage tiers
- Broadleaf oak: separated asymmetrical rounded low-poly canopy clusters, visible branch forks
- Japanese red maple: branching red-orange crown; use selectively, not every tree
- Low shrubs and bushes; add inexpensive shared rocks using existing terrain assets

Create shared procedural mesh variants **NEAR** and **FAR**. Seeded rotation/scale/color jitter is desired; do not instantiate new mesh/material per tree. Use vertex colours, opaque polygons and low vertex count. Japanese sakura currently has a recognisable blocky stylization; preserve it as a biome variation rather than removing it from all routes.

### Integration points and performance constraints
Inspect current actual code first:
- `game/scripts/world/scenery_modules.gd` already uses simple cone/box tree meshes and `MultiMesh`
- `game/scripts/world/procedural_world.gd` handles scenery chunks
- `game/scripts/world/terrain/terrain_field.gd` has seeded forest density
- `game/scripts/world/scenery_rules.gd` and terrain/road profile for clearances
- Existing vegetation-wind developer setting; preserve OFF/DEFAULT behaviour

Choose one **opt-in experimental** tree generator setting `CLASSIC / FOREST LAB` for internal QA; default CLASSIC so old saves and screenshots remain unchanged. Do not indiscriminately replace all forests.

Use per-chunk/per-style/per-LOD MultiMeshes for frustum culling. Fixed LOD based on camera distance with safe hysteresis, not a one-time distance-to-road approximation. No huge transparent billboards, large alpha overdraw or one draw call/mesh per tree. No per-tree dynamic shadow unless benchmark proves acceptable, especially until known Golden Hour shadow-pulsing issue #48 is resolved. Keep the GL Compatibility mobile renderer path.

Placement must respect ground height/normals and eliminate floating roots; never grow trees on road, bridge, tunnel openings, water, wall tops, spawn/finish zones or important sight lines. Avoid suddenly popping into existence. Increase forest density mostly on adjacent Japanese slopes, keeping curve entry and chase-camera occlusion readable. Keep deterministic seeds so old saved tracks load in identical geometry and gameplay.

### Test matrix / owner review
- QA routes: one Touge + Japan Forest (include narrow and wide road views), one other biome for regression.
- Screenshots: stationary same camera positions pre/post, chase and top-down, DAY and NIGHT. Assess silhouette variety, foliage coverage, road readability, pop-in, tree roots.
- Benchmark **actual baseline vs experiment** on same Android hardware: median FPS / p95 frame time, CPU + GPU draw calls, load time, VRAM/memory footprint if measurable, 10+ minute heat/throttling check. Target no material regression and degrade density/LOD adaptively for low-end phones; do not claim arbitrary instance numbers are free.
- PC/Web compatibility and Godot automated tests for mesh generation, seed determinism, no road intersections, chunk/LOD controls.
- Ensure existing car/physics/HUD/scoring, score records, track saves, multiplayer and weather presets unchanged.

### Deliverables
1. Compiling integrated procedural tree code + opt-in demo switch, all five types and NEAR/FAR.
2. Before/after captures and measured performance table, not just concept art.
3. New branch commits + draft PR, exact SHA, APK review artifact and handoff document.
4. Owner QA approval requested. No merge into `main`.

Avoid modifying `#62` scoring work / `#61` track management. This is an independent developer lane.