# Handoff — issue #20 moving grass / bushes (2026-11-22)

ISSUE / CLAIM / OWNER: #20 (P1) — claimed in the issue by Claude Code, branch `agent/claude/issue-20-vegetation`
MODEL / TOOL VERSIONS: Claude Code (Anthropic); exact serving model id in the owner chat report (not written into repository files). Godot 4.7.2-stable, GL Compatibility (llvmpipe in the container), `--fixed-fps 2` for the 30 s captures. No Android device used.
BASE BRANCH + SHA: `ccr-91dad981-53kkbi` @ `181fb97` (v0.1.33)
WORK BRANCH + HEAD SHA: `agent/claude/issue-20-vegetation` — head SHA in the report
OTHER OPEN PRs REVIEWED: #21 (docs), #15 (no overlap), #9–#14 stale
PATHS TOUCHED: `game/assets/shaders/terrain_vegetation.gdshader`, `game/scripts/world/terrain/terrain_scenery.gd` (`_merge_instances`, `set_wind`, a second vegetation material), `game/scripts/boot.gd` (one DEVELOPER button), `docs/DEVELOPER_MODE.md` (one row), `game/tests/vegetation_stability_test.gd` (new), `game/tests/capture_vegetation_motion.gd` (evidence tool), `tools/run_godot_checks.sh` (one spec), `docs/dev/handoffs/*`
PATHS NOT TOUCHED: tree placement / species / meshes, terrain, roads, physics, HUD, VERSION, CHANGELOG, HANDOFF.md, workflows

USER EVIDENCE: owner reports "ruszające się trawy czy krzaki" on v0.1.33 (Drive folder; the videos themselves are not in the folder, only contact sheets, which cannot show motion). The issue asks to classify: intended wind vs popping / jitter / sliding.

CLASSIFICATION (measured in the real race scene, fixed camera, 30 s, same Ojców loop as the owner's world seed 621727)
1. With the wind OFF nothing in the picture moves: 0 changed pixels in both race cameras. So there is NO jitter, popping, instance teleporting or other animation; the only movement is the shader sway. (Instance transforms are written once in `_multimesh`; no code changes them while a race runs; `vegetation_stability_test` asserts it.)
2. With the wind ON (v0.1.33) two different things move (`evidence/issue-20-vegetation-motion-before-after.jpg`, bright = strong motion):
   a. TREE CROWNS (intended): thin outlines move; amplitude ≈ 0.025 x 0.67 x tree height ≈ 0.2 m at the crown top of a 12 m tree, period 5.7 s. Kept unchanged.
   b. ROADSIDE BUSHES / PLANTING (a defect): the whole bush slides — bright blobs, up to ~0.5 m in the Ojców valley. Cause: the roadside planting of a chunk is merged into ONE mesh (`_merge_instances`) in chunk-local METRES with the chunk centre at y = 0 (`_chunk_centre`), but the vegetation shader computed the sway lever as `VERTEX.y - 0.25`, which is right for the unit-size MultiMesh trees and wrong here: the lever was the ABSOLUTE terrain height. Sway = 0.025 x height: 0.5 m at 20 m, 2.3 m on the Touge mountain, 2.5 m in the Tatry, and the whole chunk's planting moved in phase (phase came from the chunk centre). Isolated in a clean scene a 1.4 m bush with the correct lever does not move at all (0.000 px), a 12 m tree sways ±0.1 m.
IMPLEMENTATION
- `_merge_instances` bakes, per vertex, UV2.x = the plant's own sway lever in metres (`max(mesh_y - 0.25, 0) x UV.x x instance scale`, the same lever the MultiMesh path has) and UV2.y = the phase from the plant's world position. The shader (`baked` uniform) uses them for merged meshes; MultiMesh trees keep the old formula. The merged mesh gets its own material (`_veg_baked_mat`); `set_wind(factor)` drives both.
- DEVELOPER > **VEGETATION WIND** (DEFAULT 1.0 / HALF 0.5 / OFF 0.0, read when a terrain world is set up) so the owner can tell wind from anything else on the phone. The default look of the trees is unchanged (wind is NOT removed or reduced).

TESTS: PASS `vegetation_stability_test` (new, 12 s): on the Ojców valley, the Touge mountain and the Tatry the largest sway of any merged roadside vertex is 0.030 / 0.030 / 0.085 m at the default wind (limit 0.10 m; the v0.1.33 formula gave 0.48 / 2.29 / 2.47 m on the same meshes = the test's control); merged mesh uses the baked material, trees do not; same world + road -> identical planting on a fresh world; edit -> other road -> undo -> identical; nothing changes over 60 frames; `set_wind` / the stored developer option reach both materials. Also PASS: `terrain_scenery_test`, `terrain_builder_test`, `procedural_world_test`, `main_menu_test`, `smoke_test`, `tools/check_project.py`. Full `run_godot_checks.sh` / CI: see the CI result on the branch.
MEASURED RESULT (30 s fixed camera, wind 1.0; share of pixels whose brightness changes by more than 8 levels over the 30 s): top-down 0.56 % -> 0.01 %, chase 0.53 % -> 0.26 % (what remains in the chase view is the intended tree-crown sway). Numbers in the table below.

| camera | v0.1.33 px std>2 / >8 / >20 | this branch |
|---|---|---|
| top-down | 0.93 % / 0.56 % / 0.101 % | 0.03 % / 0.01 % / 0.002 % |
| chase | 1.14 % / 0.53 % / 0.297 % | 0.84 % / 0.26 % / 0.132 % |

ANDROID / DEVICE PROOF: NOT RUN. The mechanism and the fix are measured in the engine; whether this was what the owner saw on the phone must be confirmed by the owner (the video was not available to me). If the owner still sees movement with VEGETATION WIND = OFF, it is not the sway — then it is distance popping (scenery draw range 650 m, `visibility_range_end_margin 40`, fade disabled) or something else, and the next step would be a phone recording at a fixed camera. The issue stays OPEN.
TESTING LIMIT FOUND (not fixed here): in headless mode every MultiMesh instance reads back with origin (0,0,0) (the dummy renderer does not keep the buffer), so tests that read instance transforms headless (`min_item_clearance`, `min_roadside_clearance` for MultiMesh items) measure only chunk centres: on the Ojców loop 15.41 m headless vs 14.98 m with a real renderer. They are weaker than they look; a test that must be exact needs the real renderer (Xvfb) or the placement data before the MultiMesh is filled.
REGRESSION RISKS: the roadside planting no longer sways noticeably (≤ 3 cm); tree crowns sway as before. The merged-mesh sway direction is world X/Z (MultiMesh sways in the instance's rotated frame) — imperceptible at 3 cm.
NEXT SAFE ACTION: build an APK from this branch (workflow_dispatch of `android-debug.yml` on `agent/claude/issue-20-vegetation`) or integrate through the owner's approved PR; ask the owner to compare with DEVELOPER > VEGETATION WIND OFF.
