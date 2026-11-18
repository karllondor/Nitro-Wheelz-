# Nitro Wheelz — QA Report v0.1.6
2026-11-18 · Model: GPT-6 · Godot 4.7.2 stable

## Scope and release note
Track DNA P0 was merged in v0.1.5. This v0.1.6 PR adds velocity-driven dynamic camera P1, with Linux and Windows export workflows. It does **not** complete P2–P7 in the comprehensive development brief.

## Verified by executable tests
| Gate | Evidence | Result |
| --- | --- | --- |
| Starter structure, SemVer, art integrity | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44330447488 | PASS |
| Godot scene and import smoke | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44330447402 | PASS |
| InputMap, physics, reverse, Lada and touch regression | Same Godot run | PASS |
| Track DNA negative controls (invalid knots, width, crossing) | Same Godot run | PASS |
| 1,097 m sampled closed driving corridor, no invalid edge topology, same visual and static collision triangles | Same Godot run | PASS |
| Numerical camera zoom at 0/20/50/90/120 km/h, smooth damping, velocity lead, world-fixed rotation | Same Godot run | PASS |
| Godot Web export | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44330447484 | BUILT |
| ARM64 Android debug APK export | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44330447476 | BUILT |
| Native Linux x86_64 and Windows x86_64 exports | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44330447352 | BUILT |
| Linux native binary headless start in container | Godot v4.7.2 binary, --headless --quit-after 5 | PASS (exit 0) |

## Integrity and packaging
- Android APK version 0.1.6, arm64 library and AndroidManifest.xml present. Zip integrity PASS.
- Android APK SHA-256: `7abdee2f51e0ec35046ea43402b56d25b78a0878e8ce0739e289c04b0871620c`
- Linux executable SHA-256: `26d0f11802a77c3d5df887703b6ea5b07e16b048cbb8dc665f8c256a993e23c8`
- Windows executable SHA-256: `c80ed79cac2e5dad895ef6646391bc02473a648c5e18523486d4889fcf997ddd`
- Android debug build is signed with ephemeral CI key; uninstalling earlier debug releases may be necessary before installing this build. Local data loss possible.

## NOT RUN — never claim these as passed
1. Three complete **human-driven** laps (simulated centreline traversal is geometry only).
2. Full Android multitouch, rumble, vibration and screen-safe areas.
3. Drift handling feel against DRIFTIT on matching corners.
4. Visual comparison of overhead/chase composition and chase tree obstruction on actual hardware.
5. Sustained 60fps/thermal/battery benchmarking on Android.
6. Linux desktop interactive graphics and Windows exe execution.
7. Outside Zone / Inside Clip/angle combo system (P3 not yet implemented).
8. Three-lap checkpoint and direction exploit test, rating/unlocks, ranking (P4 not yet implemented).
9. Approved future HUD (P5), tyre smoke/lighting/texture improvements (P6).

## Next decision gates
- P2: on-phone steering / vehicle feel telemetry and comparison.
- P3: LINE+ZONES+ANGLE+COMBO independent scoring module with deterministic tests.
- P4: enforce ordered checkpoints and valid forward lap crossing before any published leaderboard score.
- P5: integrate approved UI after actual P3 readouts exist.
- Final human-played full three-lap acceptance on Android remains a release blocker.
