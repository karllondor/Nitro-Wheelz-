# Nitro Wheelz — v0.1.13 die-cast car / approved HUD / night park (not released)

MODEL: Claude Code agent (model identifier intentionally not recorded in the repository; reported in chat). Date: 2026-11-19.
BRANCH: ccr-91dad981-53kkbi, fast-forwarded from agent/nitro-v0.1.12-car-garage-audio (55cf1e1). main is still v0.1.6.

## FILES
- Car: game/scripts/vehicles/lada_lowpoly.gd (rewritten), game/scripts/vehicles/mesh_kit.gd (new), game/assets/shaders/diecast_paint.gdshader, soft_shadow.gdshader.
- HUD/controls: game/scripts/ui/hud_style.gd (new), race_hud.gd, race_touch.gd (draw rewritten, input logic unchanged), race_pause.gd, race_results.gd, boot.gd, garage.gd, track_editor.gd (style + logo overlap fix), game/assets/fonts/ (Exo 2, OFL).
- Track art: game/scripts/world/drift_track.gd (kerbs, verge, scenery, lighting; barrier/collision geometry unchanged), game/assets/surfaces/{grass_night,dirt_verge}.webp, {flower_cluster,blossom_leaf}.png, tools/generate_surface_textures.py, game/assets/shaders/night_vignette.gdshader.
- Race: game/scripts/race/race.gd (closer camera constants, portrait framing offset, tyre smoke, vignette layer, HUD target/track id, softer skids).
- Tests/tools: game/tests/visual_identity_test.gd (registered), game/tests/capture_visuals.gd (manual stills), brand_pause_surface_test.gd (grass wording).
- Builder: game/scripts/world/track_grid.gd (tile model, loop detection, generator, Track DNA export), game/scripts/ui/track_builder.gd + game/scenes/track_builder.tscn, drift_track.gd build_from_samples(), boot menu entry.
- Scoring: game/scripts/race/drift_scorer.gd, race.gd wiring, HUD callouts, results breakdown.
- Audio: game/scripts/audio/engine_synth.gd, drive_audio.gd (synth layer always on; recorded clips override squeal/impact).
- New tests: track_builder_test.gd, drift_scoring_test.gd, engine_audio_test.gd (registered).
- Version 0.1.13 / Android versionCode 13; workflows also trigger on this branch.

## TESTS
- PASS (local, Godot 4.7.2 headless): import + smoke, input, driving, mobile_visual, track_dna, benchmark_track, generated_track, editor_results, brand_pause_surface, garage_audio, dynamic_camera, visual_identity, track_builder, drift_scoring, engine_audio. check_project.py PASS.
- PASS: negative controls — tree clearance gate off -> visual_identity FAIL; wall penalty off -> drift_scoring FAIL; 2 pulses/rev -> engine_audio FAIL.
- NOTE: editor_results_test appends to user://nitro_local_runs.json and expects exactly two QA runs, so a second local run fails until that file is deleted (pre-existing; CI starts clean).
- RENDERED (not device): stills of race top-down/chase, garage red/white, menu, editor via Xvfb + Mesa llvmpipe.
- NOT RUN: Android install/look/FPS/thermals, touch feel, Xbox hardware, CI for this push (check Actions by commit SHA).

## APPROVED ART
No file in assets/references/approved was changed or added. The owner's chat references (HUD mock-up, close-up render, red and white Lada sheets) are described in docs/ART_DIRECTION.md; locking them needs the owner (tools/lock_asset.py).

## GAPS AGAINST THE MASTER BRIEF (after this pass)
- P0: track geometry and collisions are validated; driving feel and speed perception still need handset review (closer camera now makes speed more visible but is a tuning constant).
- P1: chain scoring now rewards angle sweet spot, speed, duration, kerb proximity and transitions and punishes wall hits/spins. Not yet: an explicit authored racing line or per-corner clipping points; thresholds need tuning on real laps.
- P1 audio: procedural inline-six engine now plays in every build; the 17 recorded OGG clips are still not in the repository.
- P2: car/HUD/environment now follow the owner targets; only one car model exists.
- Editor: BUILD TRACK • 3D implements tap-to-build on a tile grid with live scenery (inspired by the owner's reference video; the video itself could not be viewed). Tiles are 56 m because the uniform spline tightens S-bends ~35%; smaller tiles would require a different spline or relaxing the 16 m rule (not done).

## OWNER FEEDBACK PASS (same v0.1.13 candidate)
- Editor pan/pinch/FIT (editor_results_test extended), cars restyled to the two reference sheets, camera base 60 + race car x1.15 (visual only), golden-hour sky + cloud shadows (visual_identity_test extended). Full Godot suite PASS locally.
- Android signing: debug APKs now use the NITRO_DEBUG_KEYSTORE_B64 secret when present (see docs/BUILD_RELEASE.md); until the owner adds it, every CI APK still needs an uninstall before install.

## NEXT ACTION
1. Owner installs the v0.1.13 debug APK from CI and compares in-race look and camera distance with the reference; tune OVERHEAD_BASE_PORTRAIT if needed.
2. Owner tries BUILD TRACK • 3D on the phone (tap/drag feel, preview rebuild time) and drives a built loop.
3. Tune score thresholds and synth engine mix on real laps; add the recorded OGG pack to the repository; second car model.
