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
