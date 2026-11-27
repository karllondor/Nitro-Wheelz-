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