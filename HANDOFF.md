## LAN reliability and Park multiplayer

## Park multiplayer review

See the [Park multiplayer handoff](docs/dev/handoffs/park-multiplayer.md) for the combined baseline, reusable world-event interfaces, automated evidence and the two-phone checklist.

The two-game regression, protocol changes, performance measurements and two-phone checklist are in the [multiplayer handoff](docs/dev/handoffs/issue-31-multiplayer-reliability-v2.md).

# Nitro Wheelz — v0.1.33 AI-body test car (RYU-32 FLAME) on top of the mobile QA fixes (v0.1.32) and the Car Factory migration (v0.1.29–31)

## Park 2.0 feature preview

See the [Park 2.0 handoff](docs/dev/handoffs/nitro-wheelz-park-v2.md) for the provisional zone layout, spawn, ramps, repair trigger and evidence.

## AI BODY TEST CAR (v0.1.33)
- docs/car_factory/AI_BODY_PROTOTYPE.md. Fifth car FLAME = AI-generated body (free-plan asset, NOT FOR RELEASE) + wheel library wheels, RYU-32 physics / V8. Next if the owner likes it: buy the paid plan, regenerate, patch the roof, remove text / plate, make CLEAN + LIVERY, apply the same pipeline to the Lada.

## MOBILE QA (v0.1.32)
- Read docs/MOBILE_QA_v0.1.32.md: fixed causes (builder camera during gestures, dead strip, busy pill, shared record ids, tile-marker carpet), not reproduced (rear-wheel steering, road pieces during rebuild), open (minimap readability, unified editors, live handling sliders).
- Phone results come only from the owner; ask them to run the checklist with DEVELOPER > TOUCH DIAGNOSTICS on.
- Developer settings live in user://nitro_dev.cfg (dev_settings.gd); never write them to nitro_settings.cfg.

## CAR FACTORY STANDARD (stage 4)
- docs/car_factory/CAR_FACTORY_STANDARD.md is the entry point (+ REFERENCE_PACKAGE, MATERIALS_AND_PAINT, WHEEL_LIBRARY, QUALITY_CHECKLIST); CAR_FACTORY_MIGRATION_QA.md lists the status of every car and how to review on the phone.

## CAR FACTORY MIGRATION — RYU-32 (v0.1.31)
- Read docs/car_factory/RYU32_FACTORY.md. TEST model behind the same DEVELOPER switch; RYU-32 TEST LOOK picks CLEAN / LIVERY. The LIVERY texture is provisional until the owner sends the LIVERY render.

## CAR FACTORY MIGRATION — LADA (v0.1.30)
- Read docs/car_factory/LADA_2106_FACTORY.md. The new Lada is a TEST model behind DEVELOPER > CAR FACTORY TEST MODELS (default OFF); do not make it the default before the owner accepts it on the phone.
- Variant mask: TEXCOORD_1 / UV2.x (0 shared, n = slot n) collapsed in the car shaders; model data in game/cars/models/*.json; catalog entries point at it with "factory_model".
- Next: stage 3 RYU-32 (CLEAN / LIVERY, V8 ITB), stage 4 integration QA + the five Car Factory standard documents; then the owner's v0.1.28 mobile QA brief (Track Builder touch / camera, rear-wheel steering glitch, world generation, per-track records, Developer Mode).

## E30 FINAL VISUAL POLISH v0.3 (v0.1.29)
- Read docs/car_factory/E30_VISUAL_POLISH_v0.3.md (audit, changes, measurements, lessons learned). One revertable commit. Rebuild: tools/car_factory/blender/build_e30_blessed.py + build_wheels.py (bpy 5.3.0); QA views for any car: tests/capture_car_views.gd -- <out> <variant> [race].
- Next per the owner brief: Car Factory migration of the Lada (RED / WHITE) and RYU-32 (CLEAN / LIVERY), each as its own commit and visual acceptance.
- STOP POINT: owner reviews the E30 v0.3 on the phone; nothing is approved yet.

## TERRAIN BUILDER REFINEMENT (v0.1.27)
- Read docs/terrain_builder/REFINEMENT_v0.1.27.md (all brief items + the owner's chat requests, BEFORE / AFTER sheets in docs/terrain_builder/v0127/, measurements, PASS / FAIL / NOT RUN). The two phone recordings named in the brief were NOT received.
- New code: scripts/world/step_runner.gd (NitroSteps: frame-sliced jobs), scripts/ui/busy_overlay.gd (NitroBusy loading card), assets/shaders/city_facade.gdshader, tests/capture_bridges.gd, tests/capture_ui_v0127.gd. Big edits: terrain_field (macro landforms, city grid), terrain_world (steps API, road_gap street mask, stream channel, arch bridges, end pads, colour pass), terrain_scenery (rocks / trees, city district, roadside band + posts, route ends, start lights), terrain_ground shader (strata, streets, tile markers), terrain_builder (async + loading card, MOVE navigation, named SAVE, MY TRACKS), race.gd (sliced terrain load, pause EDIT TRACK, chase camera), race_pause.gd, drift_track.gd (deferred terrain, concrete shoulder), boot.gd / track_editor.gd (loading card, terrain-track redirect).
- In the game (no test SceneTree script) the builder and the race build terrain in slices behind NitroBusy; tests keep the synchronous API (`ui_async` / `defer_terrain` false).
- NOT DONE: free-draw drawing (evaluation in the report), Japan City catch fencing / rail viaduct.
- STOP POINT: owner plays v0.1.27 on the phone (builder navigation, loading card, MY TRACKS / SAVE name, pause EDIT TRACK, bridges, route ends, colours) before the next pass.

## E30 VISUAL REFINEMENT v0.2 (v0.1.26)
- Read docs/car_factory/E30_VISUAL_REFINEMENT_v0.2.md. One revertable commit. Rebuild: tools/car_factory/blender/build_e30_blessed.py + build_wheels.py (bpy 5.3.0), views: tests/capture_e30_views.gd.
- STOP POINT: owner reviews the E30 on the phone; nothing is approved yet.

## TERRAIN-FIRST TRACK BUILDER (v0.1.25)
- Read docs/terrain_builder/TERRAIN_BUILDER_REPORT.md first (what works, every check as PASS / FAIL / NOT RUN, measurements, reference comparison, limits). Architecture: docs/research/procedural_world/TERRAIN_FIRST_ARCHITECTURE.md.
- Player flow: MAIN MENU > TRACK BUILDER > TERRAIN BUILDER: COUNTRY -> LANDSCAPE -> EVENT -> GENERATE TERRAIN -> DRAW ROAD -> automatic terrain adaptation -> SAVE / DRIVE. DEVELOPER > ELEVATION PHYSICS: grade force 0/25/50/75/100 % + visual / telemetry switches.
- Code: game/scripts/world/terrain/ (terrain_catalog, terrain_field, road_profile, terrain_track, terrain_world, terrain_scenery, physics_dev), game/scripts/ui/terrain_builder.gd + game/scenes/terrain_builder.tscn, drift_track.gd (heights, open routes, end caps, region kerbs, terrain world), race.gd (height / pitch / cameras / open finish / telemetry), drive_model.gd (external_accel, ZERO = baseline), track_dna.gd (open topology, broad phase), boot.gd (menu + ELEVATION PHYSICS page). Shaders terrain_ground / terrain_water / terrain_vegetation.
- Tests (registered): terrain_world_test, terrain_scenery_test, terrain_builder_test, terrain_physics_test. Captures: tests/capture_terrain.gd, tests/capture_terrain_seeds.gd -> docs/terrain_builder/captures/.
- Saved data: schema 1 + `topology`, `world` (descriptor), `elevation.knot_heights`; legacy flat and Phase A tracks unchanged.
- References: the owner's Drive packs are public and were verified (12/12 SHA-256); images are not committed.
- STOP POINT: owner plays the APK (Builder -> SAVE -> DRIVE on all three countries) and reviews the look before further art passes (guard rails, crowds, banners, footbridge, horizon trees, phone performance tuning).


## CAR FACTORY / E30 BLESSED (v0.1.24)
- Read docs/car_factory/E30_BLESSED_PROTOTYPE.md (results, confirmed vs unconfirmed, comparison, performance, decisions) and docs/car_factory/CAR_FACTORY_AUDIT.md (why this pipeline).
- Build: tools/car_factory/README.md (bpy 5.3.0 in a venv; GLBs are committed, CI only imports them).
- Code: game/scripts/vehicles/glb_car.gd (GLB car assembly), car_cosmetics.gd (paint / wheels / signature), car_catalog.gd (variant "e30"), game/cars/e30_blessed.json, game/assets/cars/, shaders nitro_car_atlas / nitro_car_glass, garage.gd (SIGNATURE / PAINT / WHEELS row).
- Tests: e30_factory_car_test.gd (registered). Dev tools: car_perf_probe.gd, car_camera_match_render.gd, tools/car_factory/compare/.
- Reference package: assets/references/drafts/e30_blessed_v0.1/ (DRAFT; photos not committed).
- STOP POINT: owner reviews the E30 before any further cars.

> **2026-11-20 OWNER APPROVAL (still binding):** Phase A's procedural adjacency, local chunks and Builder/Race parity are worth preserving, but its road-adjacent generic village art was rejected. All world work follows [master implementation brief](docs/research/procedural_world/CLAUDE_MASTER_BUILD_BRIEF_2026-11-20.md), [terrain-first spec](docs/research/procedural_world/TERRAIN_FIRST_TOWNSCAPER_TRACK_BUILDER_SPEC.md), [research](docs/research/procedural_world/NITRO_WHEELZ_WORLD_RESEARCH_v1.md) and [Drive-hosted 49-image reference library](docs/references/drift_tracks/README.md). v0.1.25 implements the terrain system as a test build (see above); owner approval is NOT RUN.


## PROCEDURAL WORLD PHASE A (v0.1.23)
- Read docs/research/procedural_world/PHASE_A_REPORT.md first (architecture, evidence, measurements, limits).
- Code: game/scripts/world/scenery_rules.gd, scenery_modules.gd, procedural_world.gd; drift_track.gd (world from saved track, with_props, world_grid()); track_builder.gd (world, compact bar, FIT, occupied-bounds camera, pinch/pan).
- Tests: procedural_world_test.gd (new), track_builder_test.gd (extended). Capture: tests/capture_world.gd.
- STOP POINT: owner reviews the first fragment before Phase B / full town / other themes.

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
- NOTE (fixed in v0.1.24): editor_results_test used to fail on a second local run because it kept appending QA records to user://nitro_local_runs.json; it now clears its own records first.
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

## OWNER FEEDBACK PASS 7 (v0.1.19) — car profiles
- Branches: all work since v0.1.13 is on `ccr-91dad981-53kkbi`. The owner's audio commits on `agent/nitro-v0.1.12-car-garage-audio` (17 OGG + WAV masters) are now merged here (commit 182d929).
- drive_model.gd: constants are the Lada defaults; instance parameters + TUNABLE + baseline() + apply_profile(); new optional engine_brake_decel (0 for Lada).
- engine_synth.gd: instance engine profile (apply_profile, gear_of/rpm_of; static gear_for/rpm_for kept for the baseline), loudness, turbo flag, benchmark().
- game/cars/lada_baseline.json, game/cars/ryu32_v8.json; car_catalog.gd profile()/handling()/engine()/baseline switch; race.gd applies both; drive_audio.gd turbo clips gated by the engine profile.
- coupe_lowpoly.gd: V8 bay. New game/tests/car_profiles_test.gd; docs/CAR_PROFILES.md.

## AUDIO HOTFIX P0 (v0.1.20)
- docs/audio/SFX_AUDIT.md (per-clip findings and decisions); game/assets/audio/sfx_spec.json + tools/build_sfx.py -> game/assets/audio/processed/ (13 cuts).
- drive_audio.gd rewritten: EVENTS / LOOPS tables, trigger() gate, play_count, log + debug_lines(), apply_car_sfx(), modes via [developer] audio_mode; test_mode for headless tests. engine_synth.gd: road_noise layer and crackle switch (defaults keep the baseline fingerprint).
- Car profiles: "sfx" block (turbo_clips, exhaust_pitch). race.gd applies it and adds the debug overlay when enabled.
- scripts/ui/audio_debug_overlay.gd; DEVELOPER toggles in boot.gd.
- tests/sfx_mixer_test.gd (suite); tests/audio_drive_render.gd (Movie Maker listening renders, manual).
- Music: autoload Music (scripts/audio/music_player.gd), assets/music/night_drift.ogg from tools/compose_music.py; STYLE.vol_music + MUSIC slider.
- OPEN: owner listening test on Android for both cars (both audio modes) before approving the audio.

## SYNTH-ONLY AUDIO + REALISTIC ENGINE (v0.1.21)
- Owner: "the recorded SFX are hopeless, remove them all, it was much better before; just make the engine sound more real, less synthetic".
- Removed: game/assets/audio/ (17 OGG, processed/, sfx_spec.json, manifest.json, README), audio_masters/, tools/build_sfx.py, docs/audio/SFX_CATALOG.md, tests/sfx_mixer_test.gd, profile "sfx" blocks + engine "turbo" flag, DEVELOPER audio-mode switch, kerb_event, road-noise layer. docs/audio/SFX_AUDIT.md kept as history.
- drive_audio.gd: thin synth driver (drive_tick, wall_event, wall_contact, reset, silence, debug_lines). audio_debug_overlay.gd shows synth state.
- engine_synth.gd: render loop rewritten with hot state in locals (delay-line arrays are detached from the members while rendering to avoid copy-on-write); _fire() returns the pulse strength and sets bank / tick / next firing. New profile keys documented in docs/CAR_PROFILES.md. Constants MECH_GAIN / JET_GAIN set the new layers.
- car_profiles_test.gd: AUDIO_GOLDEN re-recorded once (reason in the file); physics GOLDEN untouched and passing.
- engine_audio_test.gd: realism checks with in-test negative controls.
- tests/audio_drive_render.gd: synth-only, music muted for the recording, prints engine state.
- OPEN: owner listening test on Android for both cars; DEVELOPER > AUDIO BENCHMARK on the phone (container: 35-39 ms per audio second, was ~25).

## OWNER BRIEF v0.1.21 (P0 audio cleanup, P1 editor / HUD / garage, P2 track selection)
- archive/recorded_sfx/ (17 OGG + 17 WAV + manifest + catalogue, outside game/). tests/audio_regression_test.gd.
- engine_synth.gd: _drive_rpm() (no downshift off the throttle, clutch-in idle near a stop), reset_state(), SQUEAL_GAIN. drive_audio.gd: pause_audio(), reset() -> reset_state(), _exit_tree(). race.gd: pause uses pause_audio; CARS.selected(); results on_edit for user:// tracks.
- car_catalog.gd: selected() / select() (garage + race share it; survives restarts). garage.gd uses them.
- hud_style.gd: MUSIC_DEFAULT 0.45 + one-time migration (audio/mix_rev), gauge position on wide portraits / landscape. race_hud.gd: text_sizes() shared by drawing and tests.
- track_dna.gd: sample_curve() (shared by compile and the editor preview), diagnose() (all problems with exact stretches), repair() (AUTO-SMOOTH core). track_editor.gd: real-road preview, problems list, repair-based AUTO-SMOOTH, hit_radius()/node_radius(), grab offset, pinch -> pan, verified full-precision save.
- boot.gd: DRIVE sections CIRCUITS / MY TRACKS (saved_tracks(), EDIT) / QUICK. race_results.gd: optional EDIT TRACK.
- New tests: audio_regression_test, editor_geometry_test, hud_layout_test; dynamic_camera_test drives both cars; main_menu_test checks the sections.
- Per-car rankings (reviewed only): runs are keyed by track id in user://nitro_local_runs.json; store the car variant in each run and filter by it in RESULTS.track_runs()/sorted_local(), keeping old runs as "any car".
- Owner screenshot feedback: hud_style.metrics() lap slot beside the map (portrait), name/chase/total rects, gauge 0.63 h; race_hud text_sizes() + frameless _draw_chase(); race_touch handbrake base frame (glow_path) + centred NW; race_results GOLD this-run row + TIME; race.gd OVERHEAD_BASE_* x1.2.
- Known limits: validate + diagnose on finger release is ~0.2 s for a 28-node track in the container (more on a phone); a figure-eight must be fixed by hand; landscape HUD is for desktop.

## NEXT ACTION
1. Owner installs the v0.1.21 TEST APK and listens to both cars (idle, launch through the gears, lift-off, limiter, drift); DEVELOPER > AUDIO BENCHMARK on the phone; tuning knobs per car are in game/cars/*.json "engine". Earlier: v0.1.20 TEST APK (audio hotfix; superseded); earlier: v0.1.19 debug APK (drive Lada vs RYU-32 on the same track, DEVELOPER > AUDIO BENCHMARK on phone and Web); earlier: v0.1.18 debug APK (new menu, volumes, editor AUTO-SMOOTH, RYU-32 coupe); earlier: v0.1.17 debug APK (RYU-32 coupe in garage + race, COMBO/BANKED, points stars); earlier: v0.1.16 debug APK from CI (finish screen readability); earlier: v0.1.15 debug APK from CI (wall contacts, HUD header around the camera, garage, editor, tyre/impact sound); earlier: v0.1.14 debug APK from CI, checks the garage preview, HUD v2, pause settings, editor, engine sound; then and compares in-race look and camera distance with the reference; tune OVERHEAD_BASE_PORTRAIT if needed.
2. Owner tries BUILD TRACK • 3D on the phone (tap/drag feel, preview rebuild time) and drives a built loop.
3. Tune score thresholds and synth engine mix on real laps; add the recorded OGG pack to the repository; second car model.

## #29 • Event workshop (GPT-6.2 Astra)
Open BUILD → Terrain Builder → MY TRACKS → EVENT WORKSHOP. Switch the button beside MOVE to compare layouts. Teal is rear/outside, amber is front/clip, pink is a transition, violet is initiation. DRIVE uses the same saved geometry. Outside and clip coverage budget follows forward metres, and hard contact drops the active chain. Public-road stripes remain in Practice. New Builder runs use a separate finish panel. Existing track files only enter event judging when rebuilt/saved through this Builder. Prototype coefficients await phone QA.

The local rolling-entry validator advances both E30 and RYU-32 drive models and tests oriented clearance and sector coverage. It does not certify a continuous reachable entry from the previous corner, an entire layout or a human driver's ease of control. Omitted sectors have a station-specific Builder warning. Source pack and adaptation: docs/judging-source-pack-20261122 @ c0d762a. Drift Masters p8 supplies the long-sector concept. The official DTS Winter 2026/27 PDF (dtseries.pl, September 2026, pp5–6) confirms the four OPEN judging qualities used as inspiration.

## Water clearance review, issue 19
Branch `agent/codex/issue-19-water-integration` starts at Workshop 19f507a. Ojców 621727, generator loop 3: compare the deck edge near world (-15.59, -296.19) in the Terrain Builder and both driving cameras. Android review package is com.karllondor.nitrowheelz.water19. Phone acceptance remains with the owner.
