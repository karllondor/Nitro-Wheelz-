# Nitro Wheelz — v0.1.13 die-cast car / approved HUD / night park (not released)

MODEL: Claude Code agent (model identifier intentionally not recorded in the repository; reported in chat). Date: 2026-11-19.
BRANCH: ccr-91dad981-53kkbi, fast-forwarded from agent/nitro-v0.1.12-car-garage-audio (55cf1e1). main is still v0.1.6.

## FILES
- Car: game/scripts/vehicles/lada_lowpoly.gd (rewritten), game/scripts/vehicles/mesh_kit.gd (new), game/assets/shaders/diecast_paint.gdshader, soft_shadow.gdshader.
- HUD/controls: game/scripts/ui/hud_style.gd (new), race_hud.gd, race_touch.gd (draw rewritten, input logic unchanged), race_pause.gd, race_results.gd, boot.gd, garage.gd, track_editor.gd (style + logo overlap fix), game/assets/fonts/ (Exo 2, OFL).
- Track art: game/scripts/world/drift_track.gd (kerbs, verge, scenery, lighting; barrier/collision geometry unchanged), game/assets/surfaces/{grass_night,dirt_verge}.webp, {flower_cluster,blossom_leaf}.png, tools/generate_surface_textures.py, game/assets/shaders/night_vignette.gdshader.
- Race: game/scripts/race/race.gd (closer camera constants, portrait framing offset, tyre smoke, vignette layer, HUD target/track id, softer skids).
- Tests/tools: game/tests/visual_identity_test.gd (registered), game/tests/capture_visuals.gd (manual stills), brand_pause_surface_test.gd (grass wording).
- Version 0.1.13 / Android versionCode 13; workflows also trigger on this branch.

## TESTS
- PASS (local, Godot 4.7.2 headless): import + smoke, input, driving, mobile_visual, track_dna, benchmark_track, generated_track, editor_results, brand_pause_surface, garage_audio, dynamic_camera, visual_identity. check_project.py PASS.
- PASS: negative control — disabling the tree road-clearance gate makes visual_identity_test FAIL.
- RENDERED (not device): stills of race top-down/chase, garage red/white, menu, editor via Xvfb + Mesa llvmpipe.
- NOT RUN: Android install/look/FPS/thermals, touch feel, Xbox hardware, CI for this push (check Actions by commit SHA).

## APPROVED ART
No file in assets/references/approved was changed or added. The owner's chat references (HUD mock-up, close-up render, red and white Lada sheets) are described in docs/ART_DIRECTION.md; locking them needs the owner (tools/lock_asset.py).

## GAPS AGAINST THE MASTER BRIEF (after this pass)
- P0: track geometry and collisions are validated; driving feel and speed perception still need handset review (closer camera now makes speed more visible but is a tuning constant).
- P1: three laps, timing, results exist; drift scoring is still speed x angle x combo only — no line/clipping zones, transitions or collision penalties (brief section 3). The new kerb/gap/barrier layering gives the geometry those zones need.
- P1 audio: 17-clip mixer exists but the OGG files are still not in the repository; no single continuous engine loop.
- P2: car/HUD/environment now follow the owner targets; only one car model exists.
- Editor: the current editor drags spline knots on a 2D canvas. The owner wants a visual "click where the road goes and the road plus surroundings appear" builder (reference video "How One Guy FIXED Procedural Generation", Game Dev Buddies — likely Townscaper-style click-to-build). Not started.

## NEXT ACTION
1. Owner installs the v0.1.13 debug APK from CI and compares in-race look and camera distance with the reference; tune OVERHEAD_BASE_PORTRAIT if needed.
2. Visual track builder: 3D top-down editor view that rebuilds the real NitroDriftTrack (road, kerbs, verge, trees) live on every valid tap/drag via rebuild_from_data(); tap-to-extend, auto-close, invalid segments shown red; same Track DNA validator.
3. P3 scoring zones on kerbs/outer gap; then engine audio.
