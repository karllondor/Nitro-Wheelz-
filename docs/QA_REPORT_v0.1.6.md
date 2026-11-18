# Nitro Wheelz — QA Report v0.1.6
2026-11-18 · Model: GPT-6 · Godot 4.7.2 stable

## Scope and release note
Track DNA P0 was merged in v0.1.5. This v0.1.6 PR adds velocity-driven dynamic camera P1, with Linux and Windows export workflows. It does **not** complete P2–P7 in the comprehensive development brief.

## Verified by executable tests
| Gate | Evidence | Result |
| --- | --- | --- |
| Starter structure, SemVer, art integrity | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44332935060 | PASS |
| Godot scene and import smoke | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44332934753 | PASS |
| InputMap, physics, reverse, Lada and touch regression | Same Godot run | PASS |
| Track DNA negative controls (invalid knots, width, crossing) | Same Godot run | PASS |
| 1,097 m sampled closed driving corridor, no invalid edge topology, same visual and static collision triangles | Same Godot run | PASS |
| Numerical camera zoom at 0/20/50/90/120 km/h, smooth damping, velocity lead, world-fixed rotation | Same Godot run | PASS |
| Godot Web export | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44332934683 | BUILT |
| ARM64 Android debug APK export | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44332934703 | BUILT |
| Native Linux x86_64 and Windows x86_64 exports | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44332934615 | BUILT |
| Linux native binary headless start in container | Godot v4.7.2 binary, --headless --quit-after 5 | PASS (exit 0) |

## Integrity and packaging
- Android APK version 0.1.6, arm64 library and AndroidManifest.xml present. Zip integrity PASS.
- Android APK SHA-256: `716972832401e921eaf337f5cf88bdbb2cbb5fb3b2d848c601e707fd2617b3d2`
- Linux executable SHA-256: `e2982eec176e84356f54831ac7afff78d38236f83f8c9964764c8ad4140cd88f`
- Windows executable SHA-256: `c1bb53046f99c7bdaa9111ca05c38fdcf2374f896e850d223db0bfac4883683a`
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

## Rendered desktop QA observation
- A Linux exported executable was launched in an isolated virtual portrait display (720x1280), menu + race scene reached without game errors. The start straight, Lada and finish line appeared in frame. This is a limited snapshot, **not** full-lap visual approval.
- A hardcoded v0.1.1 label in the prototype menu was noticed and replaced with Godot's application/config/version; included in the final v0.1.6 exports.
- Latest artifact download checksum and file format verified on 2026-11-18. Native Linux headless smoke exited 0. Windows native binary not launched.
