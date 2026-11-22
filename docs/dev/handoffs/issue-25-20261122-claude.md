# Handoff — issue #25 feel + visuals batch, power-to-weight calibration, 13B rotary Lada (v0.1.36, 2026-11-22)

ISSUE / CLAIM / OWNER: #25 — claimed in the issue by Claude Code, branch `agent/claude/feel-visuals-v0.1.36`. Owner request in chat 2026-11-22 (after the driftit.app comparison), delivered as ONE version.
MODEL / TOOL VERSIONS: Claude Code (Anthropic); the serving model id is in the owner chat report (not written into repository files). Godot 4.7.2-stable. bpy 5.3.0 (Blender as a Python module) for the Lada GLB. No Android device.
BASE BRANCH + SHA: `agent/claude/profile-flow-v0.1.35` @ 591083d (v0.1.35 = integration v0.1.34 + issue #24) merged with `ccr-91dad981-53kkbi` @ 2606538 (which now contains PR #21, merged on the owner's explicit instruction).
WORK BRANCH + HEAD SHA: `agent/claude/feel-visuals-v0.1.36` — head SHA in the report.
OTHER OPEN PRs / CLAIMS REVIEWED: #9 – #15 (stale / ported selectively earlier), no other claims on these paths.
PATHS TOUCHED: `game/scripts/ui/race_touch.gd`, `game/scripts/race/race.gd`, `game/scripts/world/drift_track.gd`, `game/assets/shaders/skid_marks.gdshader` (new), `cloud_shadows.gdshader`, `game/assets/brand/road_logo.png`, `game/assets/surfaces/barrier_ads.png`, `concrete_slabs.png` (new), `game/cars/lada_13b.json` (new), `e30_blessed.json`, `ryu32_v8.json`, `game/scripts/vehicles/car_catalog.gd`, `tools/car_factory/blender/build_lada_2106.py` + `game/assets/cars/lada_2106/lada_2106.glb`, `tools/art/*`, tests, docs, version files.
PATHS NOT TOUCHED: scoring maths, stars, record ids, HUD layout (except the gas pedal), the Lada handling numbers, the RYU-32 handling, the camera, controls other than GAS.

OWNER DECISIONS (this session): PR #21 merged (docs only); power-to-weight calibration YES (ADR-010); red Lada = 13B rotary (owner info); one version, no separate updates.

WHAT CHANGED — see `docs/FEEL_VISUALS_v0.1.36.md` (table with every wish, the change, the file, the test) and `docs/CAR_PROFILES.md` (calibration law, table, facts vs estimates).
1. GAS pedal = L-shape with a wing above the brake (draw + touch = one polygon).
2. Tyre marks: soft-edged shader, thinner, lighter opacity.
3. Asphalt lighter (tint 2.1); cloud shadows 64 m patches, strength 0.26.
4. One NITRO WHEELZ inscription per long straight (>= 45 m, max 4, away from the start).
5. Barrier advertising band (one mesh) + concrete slab texture on street-circuit shoulders. Builder quick previews stay plain (`with_decor`).
6. Cars: anchor = Lada 13B (231 PS / 1,150 kg est. = 201 PS/t, 3.29 s / 127.8 km/h, unchanged); E30 slowed to its 154 PS/t (4.29 s / 116.9 km/h); RYU-32 untouched (+9 % vs the target, inside the mass-estimate tolerance). Lada cars = `lada_13b.json` (handling bit-identical + rotary engine sound); the red Lada engine bay is a 13B two-rotor with four trumpets in a row.
7. Not changed (answered in the report): camera (follow camera stays), launcher icon / splash (options mock-up in the evidence; the owner picks).

TESTS (container, headless, Godot 4.7.2): PASS `gas_pedal_shape_test` (new), `track_details_test` (new), `car_performance_test` (new), `car_profiles_test` (updated: rotary + baseline file), `e30_factory_car_test`, `factory_models_test` (red 38,898 of 42,000 triangles), `mobile_visual_test`, `hud_layout_test`, `wheel_smoke_test`, `visual_identity_test`, `tools/check_project.py`; the full suite = CI on the branch (see the report for the result).
EVIDENCE: `evidence/issue-25-screen-before-after.jpg`, `issue-25-pedals-before-after.png`, `issue-25-road-inscription.jpg`, `issue-25-engine-before-after.jpg`, `issue-25-splash-icon-options.png` (container, llvmpipe, 900 x 2000; same capture script on the old and the new code: `tests/capture_feel_v0136.gd`).
ANDROID / DEVICE PROOF: NOT RUN (thumb reach of the L pedal, legibility at speed, evening-light look of the lighter asphalt and the softer clouds, the E30 being slower, the rotary sound is synthesised).
REGRESSION RISKS: E30 slower (use DEVELOPER > BASELINE PHYSICS FOR ALL CARS for the old equal-performance behaviour); star thresholds / records were set with the old E30 pace on some tracks; the white Lada shares the rotary profile (confirm); the rotary sound is sound design; barrier ads and the inscription also appear on terrain tracks (`with_decor`) — not visually checked there; tyre marks look different (softer).
NEXT SAFE ACTION: owner phone test on a fresh install and an upgrade: pedals (thumb), a drift lap on the oval and on Shin-Kawa, the finish screen, the garage (Lada engine bay), engine sound of the Lada vs the RYU-32; choose the icon / splash option.
