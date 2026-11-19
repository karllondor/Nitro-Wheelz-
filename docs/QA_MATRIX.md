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

## v0.1.21 local evidence (Claude Code cloud container, 2026-11-19)
| Check | Platform | Status | Evidence |
|---|---|---|---|
| tools/run_godot_checks.sh (import + 20 Godot tests; sfx_mixer_test removed with the recordings) | Linux container, Godot 4.7.2 headless | PASS | local run; CI pending on push |
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
