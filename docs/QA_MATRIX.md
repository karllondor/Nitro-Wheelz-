# Nitro Wheelz QA evidence — 2026-11-17

PASS only when actually executed. BUILT does not mean played or installed.

| Check | Platform | Status | Evidence |
|---|---|---|---|
| Python structural/approved-art tests | GitHub Actions | PASS | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44152482975 |
| Godot 4.7.2 import and startup | Linux CI headless | PASS | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44152482693 |
| Boot, legacy prototype, input monitor and race scenes | Linux CI headless | PASS | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44152482693 |
| InputMap Xbox mappings and synthetic logical input | Linux CI headless | PASS | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44152482693 |
| Deterministic two-axle drive, acceleration, handbrake and track | Linux CI headless | PASS | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44152482693 |
| Godot Web browser package export | Linux CI | BUILT, NOT PLAYTESTED | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44152482658 |
| Xbox controller USB | Windows | NOT RUN | Physical controller required |
| Xbox controller Bluetooth | Windows / Ubuntu | NOT RUN | Physical controller required |
| Android portrait/multitouch | Physical Android phone | NOT RUN | Installation/browser playtest needed |
| Camera chase/top-down visual comparison | PC / Android | NOT RUN | Real screen recordings needed |
| Drift handling feel compared with DRIFTIT | Same tester/device | NOT RUN | Repeatable drive and video feedback needed |
| Windows/Linux native export | Desktop | NOT RUN | Additional presets required |
| Android APK/AAB export and installation | Android | NOT RUN | Android SDK and signing not configured |
| FPS and thermals | Physical devices | NOT RUN | Profile after first playtest |

The above CI actions validate parse, scene tree startup, synthetic bindings and model numerics. They do not validate rendering quality, handling feel, controller hardware or phone performance.

## v0.1.32 — Mobile QA fixes (Claude Code cloud container, 2026-11-21)
| Area | Result |
|---|---|
| Source of the tested APK | v0.1.28 = add0883 on ccr-91dad981-53kkbi |
| Full suite (import + 33 tests incl. builder_touch_test, wheel_visual_test, track_records_test) | PASS (local, exit 0; terrain_physics_test needed the post-PASS shutdown watchdog once); tests touched by the last changes re-run: PASS |
| Track Builder: dead strip, MOVE drag under the finger (Tatry), no fling, pinch in the strip, no terrain fit while navigating, navigation during UPDATING | PASS (builder_touch_test) |
| Rear wheels never steer, front = physics steering, first drift == after RESTART (7 car models) | PASS (wheel_visual_test); phone symptom NOT reproduced |
| Records per layout, next-star pill, two-tap RESTART / GARAGE | PASS (track_records_test) |
| Evidence | docs/mobile_qa_v0132/ |
| CI at 80b12f4 | all green: [android APK](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44876886564/job/136763437312), [godot](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44876886577/job/136763437276), [web](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44876886633/job/136763437290), [desktop](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44876886571/job/136763437403), [foundation](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44876886627/job/136763437289). A CI-built APK is not a phone test. |
| Phone verification | NOT RUN (owner checklist in docs/MOBILE_QA_v0.1.32.md) |

## Car Factory stage 4 — integration QA + standards (docs only, on v0.1.31; 2026-11-21)
| Area | Result |
|---|---|
| Full suite (import + 30 tests incl. factory_models_test, e30_factory_car_test, car_profiles_test) | PASS (local, exit 0, no shutdown watchdog needed this run) |
| CI a9a2947 (Lada, v0.1.30) | all green: [godot](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44874475267/job/136756024583), [android](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44874475264/job/136756024575), [web](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44874475284/job/136756024501), [desktop](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44874475290/job/136756024602), [foundation](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44874475344/job/136756024693) |
| CI 9419cd7 (RYU-32, v0.1.31) | all green: [godot](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44875240147/job/136758379960), [android](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44875240166/job/136758380032), [web](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44875240201/job/136758380229), [desktop](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44875240204/job/136758380243), [foundation](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44875240238/job/136758380402) |
| Lineup of all looks (E30, Lada RED / WHITE, RYU-32 CLEAN / LIVERY) | docs/car_factory/car_factory_lineup_v0131.jpg |
| Five standard documents | docs/car_factory/CAR_*.md |
| Phone review / owner acceptance of the test models | NOT RUN |

## v0.1.31 — Car Factory stage 3: RYU-32 CLEAN / LIVERY (Claude Code cloud container, 2026-11-21)
| Area | Result |
|---|---|
| factory_models_test (Lada + RYU-32), e30_factory_car_test, car_profiles_test, garage_audio_test, visual_identity_test, main_menu_test | PASS (local); full suite at stage 4 |
| BEFORE / CLEAN / LIVERY renders, orthographic views, close-ups | DONE -> docs/car_factory/ryu32/ |
| Orthographic overlay vs the CLEAN sheet (not committed) | reviewed in the session |
| LIVERY reference | NOT RECEIVED - provisional texture |
| Phone review / owner acceptance | NOT RUN |

## v0.1.30 — Car Factory stage 2: Lada 2106 RED / WHITE (Claude Code cloud container, 2026-11-21)
| Area | Result |
|---|---|
| Godot suite (import + 30 tests) incl. factory_models_test (RED 37 510 / WHITE 31 444 visible tris, 8 draw calls, footprint, handling identical on / off) | PASS (local); terrain_physics_test needed the new post-PASS watchdog once (shutdown hang after PASS, WARNING printed) |
| BEFORE / AFTER renders (7 views, garage, race top-down / chase, 6 close-ups per variant) | DONE -> docs/car_factory/lada_2106/ |
| Sheet comparison (approved concept sheets, not committed) | reviewed in the session |
| CI | see the follow-up docs commit |
| Phone review / owner acceptance | NOT RUN |

## v0.1.29 — E30 Blessed Final Visual Polish v0.3 (Claude Code cloud container, 2026-11-20)
| Area | Result |
|---|---|
| Godot suite (import + 29 tests) incl. e30_factory_car_test (41 502 tris, 8 draw calls, garage framing 5.0 % margin over a full turn) | PASS (local) |
| BEFORE / AFTER renders (7 views, 6 close-ups, garage, race top-down / chase, photo cameras) | DONE -> docs/car_factory/e30_v03/ |
| CI at 11a9522 | android [success](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44832982410/job/136622288872), web [success](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44832982393/job/136622288767), desktop [success](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44832982306/job/136622288513), foundation [success](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44832982362/job/136622288785), godot [**FAILURE**](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44832982389/job/136622288798): every test printed PASS, then terrain_physics_test never exited (exit 124 = runner timeout). Cause: headless engine shutdown hang (gdb: main thread in pthread_join, the Dummy audio-driver thread at 100 % CPU; reproduced locally 2 of 3 runs). Fix in the next commit: tools/run_godot_checks.sh kills a test still alive 20 s after its PASS line and prints a WARNING (an error, a hang before PASS or a non-zero exit still fail) |
| Phone review | NOT RUN |

## v0.1.28 — Japan City street circuit (Claude Code cloud container, 2026-11-20)
| Area | Result |
|---|---|
| terrain_scenery_test (frontage >= 20 buildings, nearest facade 5.4 m), terrain_builder_test, terrain_world_test, dynamic_camera_test (local) | PASS |
| CI on add0883 | Godot suite PASS ([run](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44822723583)), Android debug APK v0.1.28 BUILT ([run](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44822723468)), Web BUILT ([run](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44822723374)), desktop BUILT ([run](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44822723418)), foundation PASS — built, not installed or played |
| Phone review | NOT RUN |

## v0.1.27 local evidence — Terrain Builder visual & track builder refinement (Claude Code cloud container, 2026-11-20)
Report: docs/terrain_builder/REFINEMENT_v0.1.27.md. Godot 4.7.2 headless + Xvfb/llvmpipe.

| Area | Result |
|---|---|
| Godot suite (29 tests) | PASS here (all PASS lines; runner exit = timeout because terrain_physics_test hangs at engine exit in this container after PASS); CI: see below |
| check_project.py | PASS |
| Captures BEFORE / AFTER (8 regions, seeds, bridges, route ends, UI) | DONE -> docs/terrain_builder/v0127/ |
| Frame stats + CPU times BEFORE / AFTER (llvmpipe) | MEASURED (report table) |
| Phone / browser performance, owner review | NOT RUN |
| CI on the v0.1.27 commit aafb14c | Godot suite PASS ([run](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44821411989)), Android debug APK v0.1.27 BUILT ([run](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44821411729)), Web BUILT ([run](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44821412227)), desktop BUILT ([run](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44821411867)), foundation PASS — built, not installed or played |

## v0.1.26 local evidence — E30 visual refinement pass v0.2 (Claude Code cloud container, 2026-11-20)
| Check | Platform | Status | Evidence |
|---|---|---|---|
| tools/run_godot_checks.sh (import + 29 Godot tests) | Linux container, Godot 4.7.2 headless | PASS | local run; CI on push |
| E30: 41 288 triangles (budget 42 000), 8 draw calls, paint / atlas / glass, dimensions unchanged, garage fit over a full turn (min margin 1.6 %) | Linux container | PASS | e30_factory_car_test |
| Lada / RYU-32 physics bit-identical, other cars' shaders untouched | Linux container | PASS | car_profiles_test, visual_identity_test |
| BEFORE / AFTER garage views, close-ups, race top-down + chase, v0.1 vs v0.2 from the 3 solved photo cameras | Xvfb + llvmpipe | DONE | docs/car_factory/e30_v02/ |
| CI on 6e0bb46: Godot import + suite | GitHub Actions Linux | PASS | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44758548860 |
| CI: Android debug APK v0.1.26 (versionCode 26), artifact id 14640406215 | GitHub Actions | BUILT, NOT INSTALLED | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44758549156 |
| CI: Web preview v0.1.26, artifact id 14641265916 | GitHub Actions | BUILT, NOT PLAYTESTED | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44758548916 |
| CI: desktop Linux + Windows, Foundation checks | GitHub Actions | BUILT / PASS | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44758548983 , https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44758549136 |
| **Phone review of the refined E30** | owner | **NOT RUN** | owner |

## v0.1.25 local evidence — Terrain-first Track Builder (Claude Code cloud container, 2026-11-20)
| Check | Platform | Status | Evidence |
|---|---|---|---|
| tools/run_godot_checks.sh (import + 29 Godot tests: 25 existing + terrain_world / terrain_scenery / terrain_builder / terrain_physics) | Linux container, Godot 4.7.2 headless | PASS | local run 2026-11-20; CI on push |
| 8 archetypes x 10 seeds deterministic and distinct; buildable tiles on the worst seed 127-192 of 192 | Linux container | PASS | terrain_world_test |
| generated loop on all 8 archetypes, max grade within +10 % of target, no height step incl. loop closure; open routes JP / PL / IE | Linux container | PASS | terrain_world_test |
| Irish cliff edge: road centre 24 m from the drop, full width + verge on land (verge edge 8.4 m from the drop), cliff wall 307 m; tiles < 21 m refused | Linux container | PASS | terrain_world_test |
| local adaptation (none beyond 98 m), 4 / 30 chunks rebuilt, road removal restores terrain, safety strip 14 m on 8 archetypes, one venue practice < club <= pro | Linux container | PASS | terrain_scenery_test |
| Track DNA broad phase == former O(n^2) scan on 32 tracks (16 invalid); 756 -> 56 ms on 900 samples | Linux container | PASS | terrain_scenery_test |
| legacy flat tracks unchanged; terrain track without knot heights re-solved | Linux container | PASS | terrain_scenery_test |
| builder: countries / landscapes / events, GENERATE + new seed, red tile refused with reason, UNDO / REDO / ERASE / CLEAR restore road + terrain, pinch + twist without painting, AUTO, CLOSE LOOP, SAVE -> race world identical, EDIT, ROUTE + DRIVE | Linux container | PASS | terrain_builder_test |
| grade force 0/25/50/75/100 % monotonic (parked 2 s on 6.3 %: 0 / 0 / 0 / 0.04 / 0.30 m/s), uphill 15.8 -> 15.0 m/s at 100 %, flat track bit-identical at 100 %, Lada golden trace bit-identical, grounding, pitch, chase camera above terrain, telemetry, open-route finish + end caps | Linux container | PASS | terrain_physics_test, car_profiles_test |
| captures: 8 x 10 seed sheets; per archetype builder before / with road, paddock, race top-down + chase on the same saved track | Xvfb + llvmpipe | DONE | docs/terrain_builder/captures/ |
| generate 446-900 ms, road adaptation 338-492 ms, race load 623-848 ms; whole world 118 k-379 k triangles, 147-209 draw calls before culling | Linux container CPU / llvmpipe | MEASURED | docs/terrain_builder/TERRAIN_BUILDER_REPORT.md |
| owner reference packs: 12 / 12 SHA-256 verified, 10 images inspected individually + index sheets | Drive (public) | DONE | report section 5 |
| CI on 6f2b8cf: Godot import + suite (29 tests) | GitHub Actions Linux | PASS | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44753078651 |
| CI: Android debug APK v0.1.25 (versionCode 25), artifact Nitro-Wheelz_v0.1.25_Android-debug (id 14636202383) | GitHub Actions | BUILT, NOT INSTALLED | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44753078638 |
| CI: Web preview | GitHub Actions | BUILT, NOT PLAYTESTED | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44753078696 |
| CI: desktop Linux + Windows | GitHub Actions | BUILT, NOT PLAYTESTED | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44753078957 |
| CI: Foundation checks | GitHub Actions | PASS | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44753078671 |
| **Android / Web FPS, memory, adaptation time on a phone; owner playtest and visual approval** | devices / owner | **NOT RUN** | owner |

## v0.1.24 local evidence — Car Factory prototype E30 Blessed (Claude Code cloud container, 2026-11-20)
| Check | Platform | Status | Evidence |
|---|---|---|---|
| tools/run_godot_checks.sh (import + 24 Godot tests incl. new e30_factory_car_test) | Linux container, Godot 4.7.2 headless | PASS | local run 2026-11-20; CI on push |
| E30 in catalog, Lada / RYU-32 profiles untouched, E30 handling = Lada baseline + wheelbase 2.570 | Linux container | PASS | e30_factory_car_test |
| E30 model: 8 draw calls, 38.3 k triangles with wheels, length 4.331 / width 1.645 (+strips) / roof 1.315 m, wheelbase 2.570 | Linux container | PASS | e30_factory_car_test |
| Cosmetics: SIGNATURE default, PAINT / WHEELS persist, handling unchanged, garage = race car, SIGNATURE resets | Linux container | PASS | e30_factory_car_test |
| I6 synth: 150 Hz firing at 3000 rpm, finite non-silent output | Linux container | PASS | e30_factory_car_test |
| Photo comparison (camera solved from keypoints) | bpy 5.3 + OpenCV + Godot, Xvfb llvmpipe | RMS 21.3 / 21.2 / 23.0 px = 2.4 / 2.6 / 2.5% of keypoint span | tools/car_factory/compare/, docs/car_factory/E30_BLESSED_PROTOTYPE.md |
| Relative render cost (Lada / RYU-32 / E30), race scene | Xvfb + llvmpipe (software) | draw calls 212 / 213 / 188, primitives 108.6 k / 114.2 k / 94.3 k, frame 160.9 / 168.2 / 149.8 ms | tests/car_perf_probe.gd |
| Garage / race top-down / chase screenshots | Xvfb + llvmpipe | DONE | docs/car_factory/e30/ |
| **Android / Web FPS, memory, load time with the E30; steering-lock clearance in motion; owner visual approval** | devices / owner | **NOT RUN** | owner |

## v0.1.23 local evidence — procedural world Phase A (Claude Code cloud container, 2026-11-19)
| Check | Platform | Status | Evidence |
|---|---|---|---|
| tools/run_godot_checks.sh (import + 24 Godot tests incl. new procedural_world_test) | Linux container, Godot 4.7.2 headless | PASS | local run; CI on push |
| Garage joins into 2x1 workshop on road growth, splits on removal / UNDO | Linux container | PASS | procedural_world_test |
| Builder world == race world (saved theme + seed), deterministic, different seed differs | Linux container | PASS | procedural_world_test |
| No scenery within setback of the compiled race road (12 circuits, 3698 items), no building overlaps | Linux container | PASS (min margin +0.19 m) | procedural_world_test |
| Incremental edit: 4 of 14 chunks rebuilt, untouched chunk nodes kept | Linux container | PASS | procedural_world_test |
| Builder: 8 buttons two rows, compact bar, FIT, occupied-bounds framing, pinch without painting | Linux container | PASS | track_builder_test |
| World build / edit time | Linux container CPU | ~225 ms full, ~76 ms one-tile edit; 77.7 k verts / 38.9 k tris (24-tile loop) | procedural_world_test |
| Screenshots BEFORE/AFTER, adjacency, builder vs race same camera | Xvfb + llvmpipe | DONE | docs/research/procedural_world/phase_a/ |
| **Android / Web FPS, spikes, load time, memory with the world** | devices | **NOT RUN** | owner |

## v0.1.21 local evidence (Claude Code cloud container, 2026-11-19)
| Check | Platform | Status | Evidence |
|---|---|---|---|
| tools/run_godot_checks.sh (import + 23 Godot tests incl. new audio_regression, editor_geometry, hud_layout) | Linux container, Godot 4.7.2 headless | PASS | local run after the owner brief; CI on push |
| No recorded SFX inside the game; originals archived outside the export; one synth player per race | Linux container | PASS | audio_regression_test |
| Both engines: idle, accel + shifts, drift, lift, braking to stop, wall impact; no rev flares braking (+0 vs speed map +4305 / +4023 rpm) | Linux container | PASS | audio_regression_test |
| Restart clears transients, pause keeps race + sound state, no carry-over between cars, car choice survives restart | Linux container | PASS | audio_regression_test |
| Music vs engine in game | Xvfb render | music ~-26 LUFS at default; engine idle ~-25, driving -16..-18 LUFS | ebur128 on Movie Maker recordings |
| Editor: complex shapes, 2 hairpins = 2 reports, close sections, figure-eight refused, stacked knots, SAVE AS exact, race road == preview, touch | Linux container | PASS | editor_geometry_test |
| HUD on 11 screens (16:9-21:9 phones, 360x640, tablets, landscape): no overlaps, minimap size, text >= 2.0-2.2% of short side | Linux container | PASS (was 1.6% for BANKED SCORE) | hud_layout_test |
| Same camera for Lada and RYU-32, car in view in both cameras | Linux container | PASS | dynamic_camera_test |
| Android APK / Web build | GitHub Actions | see CI run for the pushed commit | android-debug.yml / web-preview.yml |
| Camera 0 A/B (owner: 20% further out) | Xvfb + llvmpipe, 720x1600 | overhead size x1.2 at every speed (60 -> 72 base); car ~17% smaller on screen; zoom-vs-speed ratios, lead, framing and chase camera unchanged | capture_visuals race_start / race_blue / race_drift before vs after |
| Owner HUD feedback (LAP by the map, bigger name + clock, frameless chase, lower speedometer, handbrake frame + centred NW, yellow this-run on results) | Linux container + Xvfb | PASS layout (hud_layout_test, 11 screens), screenshots reviewed | hud_layout_test, capture_visuals |
| Physics golden trace bit-identical | Linux container | PASS | car_profiles_test |
| Lada JSON == synth defaults (new fingerprint, re-recorded once) | Linux container | PASS | car_profiles_test |
| Realism checks vs feature-off controls (cycle change, V8 burble, overrun misfires, idle tick, stereo) | Linux container | PASS (0.93/0.24, 2.49/0.76, 38/0, x2.96, 0.977) | engine_audio_test |
| Spectral balance vs the owner's real limiter recording (octave bands re max, limiter segment) | Linux container | 1k/2k/4k: before -10.6/-24.6/-30.9 dB, after -7.8/-13.3/-15.9, recording -5.1/-11.3/-15.7 | offline analysis |
| Synth CPU per second of audio | Linux container | 35-39 ms (was ~25) | benchmark() |
| Engine demos before/after + in-game Movie Maker recordings (music muted), both cars | Xvfb + llvmpipe | RECORDED, in-game -17.9 (Lada) / -16.5 (RYU) LUFS, NOT LISTENED BY A HUMAN | tests/audio_drive_render.gd |
| **Listening test on Android, both cars** | Physical Android | **NOT RUN — required before sound approval** | owner |
| Synth CPU on Android / Web | Physical devices | NOT RUN | DEVELOPER > AUDIO BENCHMARK |

## v0.1.20 local evidence (Claude Code cloud container, 2026-11-19)
| Check | Platform | Status | Evidence |
|---|---|---|---|
| tools/run_godot_checks.sh (import + 21 Godot tests incl. new sfx_mixer_test) | Linux container, Godot 4.7.2 headless | PASS | local run; CI pending on push |
| Negative control: v0.1.19 trigger logic | Linux container | PASS (test FAILs: "exhaust_pops played 14") | local run |
| Car profiles bit-identical after audio changes | Linux container | PASS | car_profiles_test |
| 17-clip audit (length, LUFS, clipping, spectrograms, event regions) | Linux container | DONE | docs/audio/SFX_AUDIT.md |
| Real game mix recorded (Movie Maker), Lada + RYU-32 x synth-only / synth+recorded, scripted autopilot drive | Xvfb + llvmpipe | RECORDED, peaks -2.8..-8 dBFS, -19.5..-22 LUFS, NOT LISTENED BY A HUMAN | tests/audio_drive_render.gd |
| Music analysis vs reference profile | Linux container | 120 BPM, A minor, sub/bass/low-mid/mid 22/39/19/19% (ref 32/36/15/14) | tools/compose_music.py |
| **Listening test on Android, both cars** | Physical Android | **NOT RUN — required before audio approval** | owner |

## v0.1.19 local evidence (Claude Code cloud container, 2026-11-19)
| Check | Platform | Status | Evidence |
|---|---|---|---|
| tools/run_godot_checks.sh (import + 19 Godot tests incl. new car_profiles_test) | Linux container, Godot 4.7.2 headless | PASS | local run; CI pending on push |
| Lada physics + engine sound bit-identical to pre-profile code | Linux container | PASS | golden trace + audio fingerprint in car_profiles_test |
| Negative controls: Lada grip 6.15 -> 6.16, RYU braking better than Lada | Linux container | PASS (test FAILs) | local run |
| Lada vs RYU-32 scripted measurements | Linux container | MEASURED | docs/CAR_PROFILES.md |
| Synth CPU, container | Linux container | ~24-30 ms per audio second (2.4-3% of one core) | engine_synth.benchmark |
| Synth CPU on Android / Web | Physical devices / browser | NOT RUN | DEVELOPER > AUDIO BENCHMARK |
| Recorded OGG playback on device | Physical Android | NOT RUN | owner |

## v0.1.18 local evidence (Claude Code cloud container, 2026-11-19)
| Check | Platform | Status | Evidence |
|---|---|---|---|
| tools/run_godot_checks.sh (import + 18 Godot tests incl. new main_menu_test) | Linux container, Godot 4.7.2 headless | PASS | local run; CI pending on push |
| Negative control: AUTO-SMOOTH with smoothing disabled | Linux container | PASS (editor test FAILs) | local run |
| Stills: editor notch before/after AUTO-SMOOTH, menu main/drive/settings, pause with volumes | Xvfb + llvmpipe 720x1600 | RENDERED, NOT DEVICE | scratch captures |
| Volume balance on phone speakers, menu thumb reach | Physical Android | NOT RUN | owner to confirm |

## v0.1.17 local evidence (Claude Code cloud container, 2026-11-19)
| Check | Platform | Status | Evidence |
|---|---|---|---|
| tools/run_godot_checks.sh (import + 17 Godot tests) | Linux container, Godot 4.7.2 headless | PASS | local run; CI pending on push |
| RYU-32 stills: garage 5 angles, race top-down + chase, garage UI with 3 cars | Xvfb + llvmpipe 720x1600 | RENDERED, NOT DEVICE | tests/capture_visuals.gd race_blue / garage_blue |
| COMBO / BANKING / bank flight HUD still | Xvfb + llvmpipe | RENDERED, NOT DEVICE | scratch capture |
| Star thresholds feel on real laps, coupe look on the phone | Physical Android | NOT RUN | owner to confirm |

## v0.1.16 local evidence (Claude Code cloud container, 2026-11-19)
| Check | Platform | Status | Evidence |
|---|---|---|---|
| tools/run_godot_checks.sh (import + 17 Godot tests incl. new results_screen_test) | Linux container, Godot 4.7.2 headless | PASS | local run; CI pending on push |
| Negative controls: rank by time, missing lap splits | Linux container | PASS (test FAILs) | local run |
| Finish screen stills portrait 720x1600 + landscape 1280x720, handbrake close-up | Xvfb + llvmpipe | RENDERED, NOT DEVICE | tests/capture_visuals.gd `results` |
| Finish screen readability on the owner's phone | Physical Android | NOT RUN | owner to confirm |

## v0.1.15 local evidence (Claude Code cloud container, 2026-11-19)
| Check | Platform | Status | Evidence |
|---|---|---|---|
| tools/run_godot_checks.sh (import + 16 Godot tests incl. new wall_body_test) | Linux container, Godot 4.7.2 headless | PASS | local run; CI pending on push |
| Barrier penetration, 60 s random driving x3 tracks, race scene | Linux container | PASS: 0.000 m (old centre-only code: 1.00-1.20 m) | scratch probe, numbers in CHANGELOG |
| Negative controls: centre-only collision, siren squeal, impact without thud | Linux container | PASS (each test FAILs) | local run |
| Stills: HUD v3, garage side-on red / white, editor + help | Xvfb + llvmpipe 720x1600 | RENDERED, NOT DEVICE | tests/capture_visuals.gd |
| Garage cars visible on Android after MSAA removal (v0.1.14) | Owner's phone | PASS (owner screenshots) | chat 2026-11-19 |
| HUD keep-out vs. the owner's actual camera cut-out, new sounds on speakers | Physical Android | NOT RUN | owner to confirm |

## v0.1.14 local evidence (Claude Code cloud container, 2026-11-19)
| Check | Platform | Status | Evidence |
|---|---|---|---|
| tools/run_godot_checks.sh (import + 15 Godot tests) | Linux container, Godot 4.7.2 headless | PASS | local run; CI pending on push |
| Negative controls: editor clipping off, even cylinders, accent not applied | Linux container | PASS (each test FAILs) | local run |
| Stills: HUD v2 top-down/chase, cyan accent, pause settings, editor + help popup, garage red/white | Xvfb + llvmpipe 720x1600 | RENDERED, NOT DEVICE | tests/capture_visuals.gd |
| Engine synth offline render (14 s idle/blips/launch/lift-off/limiter) | Linux container | RENDERED, NOT LISTENED ON DEVICE | level/CPU check: ~14 ms per audio second on the container CPU |
| Garage preview on Android (MSAA removed) | Physical Android | NOT RUN | owner to confirm |

## v0.1.13 local evidence (Claude Code cloud container, 2026-11-19)
| Check | Platform | Status | Evidence |
|---|---|---|---|
| tools/check_project.py | Linux container | PASS | local run |
| tools/run_godot_checks.sh (import + 13 Godot tests incl. new visual_identity_test) | Linux container, Godot 4.7.2 headless | PASS | local run; CI run pending on push |
| visual_identity_test negative control (tree clearance gate disabled -> FAIL) | Linux container | PASS | local run |
| Rendered stills race/garage/menu/editor | Xvfb + Mesa llvmpipe, GL Compatibility, 720x1600 | RENDERED, NOT DEVICE | tests/capture_visuals.gd (stills not committed) |
| track_builder_test / drift_scoring_test / engine_audio_test + negative controls | Linux container, Godot 4.7.2 headless | PASS | local run |
| Builder stills (partial chain, generated loop, race on built loop) | Xvfb + llvmpipe 720x1600 | RENDERED, NOT DEVICE | tests/capture_visuals.gd |
| Synth engine offline render (9 s launch/drift/impact/coast) | Linux container | RENDERED, NOT LISTENED ON DEVICE | spectral check only |
| Android look, frame rate, touch, smoke/scenery cost, builder finger feel, audio on speakers | Physical Android | NOT RUN | install CI APK v0.1.13 |
