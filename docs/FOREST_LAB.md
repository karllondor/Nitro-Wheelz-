# FOREST LAB — eight procedural tree species, Touge pilot (issue #54)

**Status: CODE_READY on branch `feat/sonnet-forest-lab` (draft PR, NOT merged to `main`). OWNER_QA_PENDING: nobody has looked at it on a phone.**
Default = **CLASSIC**: a build that never touches DEVELOPER > FOREST LAB draws exactly the trees it drew before.
Scope = **TOUGE only** (the `jp_touge` landscape). Every other biome keeps its CLASSIC trees even when the switch is on.

## What is new
| Piece | File | What it does |
|---|---|---|
| Tree factory | `game/scripts/world/forest_lab/nitro_tree_factory.gd` | eight faceted low-poly species, NEAR + FAR meshes (one crown plan), five season palettes, Tree Designer knobs |
| Material | `game/assets/shaders/forest_lab_tree.gdshader` | ONE opaque material for every species / LOD / season; vertex colours = palette, UV.x = foliage mask so only foliage sways (DEVELOPER > VEGETATION WIND) |
| Touge scatter | `game/scripts/world/forest_lab/forest_lab_scatter.gd` | deterministic placement + chunked MultiMeshes + NEAR / FAR visibility ranges |
| Settings / presets | `game/scripts/world/forest_lab/forest_lab_settings.gd` | `user://nitro_dev.cfg` `[forest_lab]` (developer file, never the player's saves) + JSON presets under `user://forest_lab_presets/` |
| Tree Designer | `game/scenes/forest_lab_designer.tscn`, `…/forest_lab_designer.gd`, `…/forest_lab_camera.gd` | developer-only inspection / tuning tool |
| Hook | `game/scripts/world/terrain/terrain_scenery.gd` | one loop bound + one hook in `_build_chunk`, one condition in `_roadside`; the CLASSIC path is untouched when the mode is CLASSIC |
| DEVELOPER page | `game/scripts/boot.gd` | FOREST LAB (CLASSIC / ON), FOREST DENSITY (LOW / MEDIUM / HIGH), TREE DESIGNER |

## The eight species (triangles, summer palette; NEAR / FAR)
Pine 130 / 64 · Fir 166 / 76 · Oak 374 / 82 · Japanese maple 264 / 88 · Shrub 120 / 48 · Birch 268 / 72 · Sakura 282 (422 in spring with blossom puffs) / 74 · Rowan 348 / 80.
Budgets asserted by `forest_lab_factory_test`: NEAR ≤ 520, FAR ≤ 160 (shrub 200 / 70). For comparison the CLASSIC pine is ~90–100 triangles (3 seven-sided cones + a box).
Seasons (spring, summer, autumn gold / orange / red) change **colours only**, never the geometry (roots never move). Pine and fir are evergreen.

### Honest comparison with the approved illustration
`evidence/forest-lab/reference_vs_engine.jpg` shows the approved art next to the real Godot meshes. The species vocabulary, silhouettes, branching and colour logic follow it (layered tiers, white birch with dark marks, a broad oak dome on visible limbs, pink sakura, layered red maple, rowan with red berry clusters, shrubs with flowers / berries). It is **not** the illustration: the illustration has leafy detail that a ~300-triangle opaque mesh cannot carry. Our crowns are fewer, bigger facets. The prototype ZIP's broadleaf trees (thin trunks with small detached bipyramid "umbrellas") were rebuilt from scratch; its conifers were kept as an idea and refined.

## How to try it (5 minutes, no code)
1. Main menu > **DEVELOPER** > **TREE DESIGNER**: pick a species, a season, a view (EDITED / COMPARE / GALLERY / STAND). Drag or one finger = orbit, wheel or pinch = zoom (desktop: hold the right mouse button + W A S D Q E to fly). Move the sliders; **SAVE PRESET** (a name that exists is never overwritten silently), **USE ON TOUGE** selects it for Touge routes, **STOCK GEOMETRY** goes back.
2. DEVELOPER > **FOREST LAB: CLASSIC → ON** (and **FOREST DENSITY**: LOW / MEDIUM / HIGH).
3. Open a **Touge** route (TRACK BUILDER > TOUGE MOUNTAIN, or an existing one such as "MY TOUGE ROUTE") and drive it. Switch back to CLASSIC and compare the same route. Other landscapes never change.
4. Performance on your phone: DEVELOPER > **TOUCH DIAGNOSTICS ON** shows FPS, frame time and draw calls; read them on the same route with CLASSIC and with FOREST LAB (one minute each, plus a 10 minute run for heat).

## Placement on Touge (deterministic)
* Same filters as CLASSIC (water, slope ≤ 1.1, road + barrier + safety strip = 14 m, landmark / venue footprints) **plus** tall trees (> 9 m) stand 4 m further back, and within 30 m of that strip only lower, softer species and heights (×0.78) grow, so hairpins and the lower serpentines stay visible from the Chase camera. Bridges, walls, start and finish sit inside the road / venue clearances.
* Species grow in stands (slow noise, ~100 m): dark conifer stands, mixed deciduous stands (oak / birch / rowan / maple), a rare scenic sakura grove; shrubs as understory. A 112 m cell holds at most three species (one conifer, one deciduous, shrubs) to keep MultiMeshes few.
* Roots are 0.25 m + 0.5 × slope × 0.35 below the terrain: nothing floats. The CLASSIC forest-edge row is replaced as well; roadside planting, rocks and the soft blob shadows stay. No dynamic tree shadows (#48 stays out of this).
* NEAR (0 … `near_distance` = 120 m) and FAR (beyond) are **camera-distance** visibility ranges per 112 m cell with a 15 m hysteresis margin and no fade (GL Compatibility has no dither fade). Because a cell switches as a whole, a FAR tree can stand ≥ ~40 m from the camera.

## Measured cost (container, real race scene, **not a phone**)
Same Touge world (seed 1, route seed 5), same car positions and cameras, 1280 × 720. Draw calls / primitives are the engine's own render info (renderer independent); **milliseconds in a software-GL container are meaningless and are not reported as frame times.**

| DAY (no shadows), chase camera, mean of 3 spots | trees in the world | draw calls | primitives |
|---|---|---|---|
| CLASSIC | 2 933 | 161 | 159 k |
| FOREST LAB LOW | 2 316 | 189 (+28) | 176 k (+11 %) |
| FOREST LAB MEDIUM | 4 083 | 195 (+34) | 209 k (+31 %) |
| FOREST LAB HIGH | 5 648 | 193 (+32) | 239 k (+50 %) |

* Top-down camera (MEDIUM): draw calls unchanged (94–95 vs 95–101), primitives +6–10 %.
* GOLDEN HOUR (the environment turns shadows on; the trees cast none): chase, MEDIUM: 195 / 222 / 234 draw calls vs 171 / 184 / 194 CLASSIC, primitives 302 / 320 / 331 k vs 245 / 272 / 269 k (+21–23 %). NIGHT = DAY numbers.
* Dense hillside from above the road (HIGH): 173 / 180 draw calls, 207 k primitives vs CLASSIC 152 / 161, 134 k / 132 k.
* World rebuild (CPU of the container): CLASSIC 160–177 ms, FOREST LAB 193 (LOW) – 267…330 (MEDIUM) ms; the 80 shared meshes cost 8.4 ms to generate once per process.
* **Reading:** the draw-call cost is mostly fixed (~ +30: one MultiMesh per species per 112 m cell and LOD); the triangle cost grows with density (+11 / +31 / +50 %). Neither is free. LOW keeps the triangle bill small; MEDIUM is the look I would show first; HIGH needs a phone test before anyone relies on it. A phone is not a container: the real numbers are the owner's.
* **NOT MEASURED:** Android FPS (no phone available), memory, heat over 10–15 minutes, pop-in while driving, the Android emulator (a software-GL emulator FPS is not a phone FPS and is not reported).

## Tests
`forest_lab_factory_test` (80 meshes, budgets, determinism, outward normals, Designer knobs, presets), `terrain_forest_lab_test` (CLASSIC byte-stable and default, replaced on Touge only, deterministic, clearances, no floating, NEAR / FAR ranges, density order), `forest_lab_designer_test`. A headless MultiMesh keeps no instance data, so the placement tests read the scatter's own placement record (the data the MultiMeshes are filled from).
Evidence tool: `game/tests/capture_forest_lab.gd` (needs a display; see its header). Images: `docs/dev/handoffs/evidence/forest-lab/`.

## Known limits / follow-ups (nothing hidden)
* Not as detailed as the illustration (see above). FAR sakura has no branches.
* The draw-call floor (~ +30) could be cut by fewer species per cell or by merging the two rarest species; not done, because it needs the phone numbers first.
* No wind per tree on the CPU; the existing shader sway (foliage only) follows DEVELOPER > VEGETATION WIND. Whether the sway of the larger crowns looks right is untested on a phone.
* One shape variant per species per cell (2 variants overall) and season variation per cell for the deciduous species in the autumn palettes; no per-tree variants (that would multiply MultiMeshes).
* Tree Designer: species mix editing is only possible in the preset JSON (`mix`), not with sliders.
* Other biomes (Japan Sakura / Forest, Poland, Ireland) are untouched on purpose; the owner decides after QA.
