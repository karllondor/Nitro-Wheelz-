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
