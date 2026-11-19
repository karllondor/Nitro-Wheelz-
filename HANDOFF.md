# Nitro Wheelz — v0.1.18 editor auto-smooth, separate volumes, player menu (not released)

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
- P1 audio: procedural inline-four ITB engine (v0.1.14) plays in every build; the 17 recorded OGG clips are still not in the repository (checked every branch, release and PR on 2026-11-19).
- P2: car/HUD/environment now follow the owner targets; only one car model exists.
- Editor: BUILD TRACK • 3D implements tap-to-build on a tile grid with live scenery (inspired by the owner's reference video; the video itself could not be viewed). Tiles are 56 m because the uniform spline tightens S-bends ~35%; smaller tiles would require a different spline or relaxing the 16 m rule (not done).

## OWNER FEEDBACK PASS (same v0.1.13 candidate)
- Editor pan/pinch/FIT (editor_results_test extended), cars restyled to the two reference sheets, camera base 60 + race car x1.15 (visual only), golden-hour sky + cloud shadows (visual_identity_test extended). Full Godot suite PASS locally.
- Android signing: debug APKs now use the NITRO_DEBUG_KEYSTORE_B64 secret when present (see docs/BUILD_RELEASE.md); until the owner adds it, every CI APK still needs an uninstall before install.

## OWNER FEEDBACK PASS 2 (v0.1.14)
- HUD v2 (race_hud.gd rewritten, hud_style.gd metrics: header/map/total/chase/score/callout/gauge_centre/gauge_radius/angle), accent + sound settings (hud_style.gd static PINK/PINK_SOFT, set_accent/set_sound/load_settings/save_settings, user://nitro_settings.cfg), pause settings (race_pause.gd), NW handbrake logo (race_touch.gd + assets/brand/nw_initials.png), NW banner removed (lada_lowpoly.gd), garage SubViewport MSAA removed, editor layout/help popup (track_editor.gd), inline-four engine (engine_synth.gd, drive_audio.gd).
- race.gd: hud.best_score from local results, hud.car_screen after each camera update (callouts above the car), ensure_settings at start.
- Tests extended (visual_identity, brand_pause_surface, editor_results, engine_audio); full suite PASS; negative controls FAIL as expected.
- NOT RUN: Android (garage fix, HUD readability, engine on speakers), CI for this push until checked.

## OWNER FEEDBACK PASS 3 (v0.1.15)
- Barrier bug: drift_track.gd resolve_body() (oriented 10-point footprint, BODY_HALF_LENGTH 2.30 / BODY_HALF_WIDTH 1.05 at x1.15 race scale, local centreline search PROBE_WINDOW 24, yaw kick) used by race.gd; resolve_wall() kept for the point tests. New game/tests/wall_body_test.gd registered in tools/run_godot_checks.sh.
- HUD v3: hud_style.metrics() keys dead/map/lap/total_label/total/name/chase/score; race_hud.gd header, minimap rotation + point_at_progress(), framed chain, callouts x0.8; STYLE.glow_arc/fit_size; race_touch.gd engraved NW (nw_initials_mask.png) + joystick glow.
- Garage: studio_backdrop.gdshader on a camera-parented quad, KEEP_WIDTH camera fov 36, floor removed, neutral lights.
- Editor: header (bold white title left, accent name centred), bigger fonts, calmer frame.
- Audio: engine_synth.gd squeal/impact/scrape rewritten; drive_audio.wall_contact(); race.gd feeds wall slide speed.
- NOT RUN: Android check of the camera keep-out on the owner's phone, sounds on speakers.

## OWNER FEEDBACK PASS 4 (v0.1.16)
- race_results.gd rewritten: drawn board (layout() section rects, portrait single column scaled to fit, landscape two columns), static summarize() for the data, sorted_by_score(), points(); save_run() takes optional laps + date. sorted_local() (by time) kept.
- race.gd records lap_splits (time + banked points per lap) and passes stats["laps"].
- race_touch.gd: smaller, subtle NW engraving.
- New game/tests/results_screen_test.gd registered; capture_visuals.gd `results` shot (seeded capture-only history, cleaned up afterwards).

## OWNER FEEDBACK PASS 5 (v0.1.17) — audit plan + new car
- New car: scripts/vehicles/coupe_lowpoly.gd (NitroCoupeLowPoly, same API as the Lada), scripts/vehicles/car_catalog.gd (variants red/white/blue; make(), info(), valid()). race.gd spawns via the catalog and sets track.body_half_length/width; garage.gd has one button per car.
- Scoring: race_hud.gd COMBO box (bank_progress from scorer.idle_time/CHAIN_GRACE), BANKED SCORE label, bank flights + pulse.
- Stars: race_results.gd star_tiers(length_m)/star_count(score,length_m), STAR_RATES; race passes stats["length_m"].
- Remaining from the audit plan (next): editor auto-smooth of tight corners, separate engine/tyre/effects volumes, simplified main menu. Garage collection beyond three cars.

## OWNER FEEDBACK PASS 6 (v0.1.18) — rest of the audit plan
- track_editor.gd: compiled_samples/problem_ranges + red arc, friendly_error(), _auto_smooth() (Laplacian relax of flagged knots and neighbours, max 60 passes, reverts on failure), AUTO-SMOOTH replaces VALIDATE.
- settings_panel.gd (NitroSettingsPanel) shared by race_pause.gd and boot.gd; STYLE.vol_engine/vol_tyres/vol_fx persisted; engine_synth.gd engine_gain/tyre_gain/fx_gain; drive_audio.gd clip_group()/group_gain().
- boot.gd rewritten as paged player menu; new game/tests/main_menu_test.gd registered.
- Still open from the audit: COLLECTION screen / more cars, per-car handling.

## NEXT ACTION
1. Owner installs the v0.1.18 debug APK (new menu, volumes, editor AUTO-SMOOTH, RYU-32 coupe); earlier: v0.1.17 debug APK (RYU-32 coupe in garage + race, COMBO/BANKED, points stars); earlier: v0.1.16 debug APK from CI (finish screen readability); earlier: v0.1.15 debug APK from CI (wall contacts, HUD header around the camera, garage, editor, tyre/impact sound); earlier: v0.1.14 debug APK from CI, checks the garage preview, HUD v2, pause settings, editor, engine sound; then and compares in-race look and camera distance with the reference; tune OVERHEAD_BASE_PORTRAIT if needed.
2. Owner tries BUILD TRACK • 3D on the phone (tap/drag feel, preview rebuild time) and drives a built loop.
3. Tune score thresholds and synth engine mix on real laps; add the recorded OGG pack to the repository; second car model.
