# Nitro Wheelz — handoff 2026-11-17

Model: GPT-6
Repository: https://github.com/karllondor/Nitro-Wheelz-
Branch: agent/nitro-v0.1-driving-lab
Game version: 0.1.0; Karll Game Starter base: 0.1.0
Engine: Godot 4.7.2 stable, GL Compatibility, 120 Hz physics ticks and two 240 Hz substeps.

## Delivered
Original independent two-axle physics inspired by publicly documented DRIFTIT principles; fictional Shin-Kawa drift circuit, procedural 3D car, overhead/chase cameras, lap time, drift scoring, rubber trail, input from keyboard/Xbox InputMap/touch, working Godot Web preview export and test harness.

## Verified
- Foundation PASS: https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44152482975
- Godot 4.7.2 PASS (smoke, input test, deterministic physics + brake regression): https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44152482693
- Web package BUILT: https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44152482658
- Artifact: Nitro-Wheelz_v0.1.0_Web.zip, browser files exported, not manually played.

## NOT RUN / known limits
- No physical Android APK, Xbox USB/Bluetooth, Windows/Linux native build.
- No direct manual video evaluation of the visual scene or responsive car handling.
- No final car textures, tuning, ownership, currency, ghost or licensed NIGHTRIDE / Drift Games packs.
- Current lap crossing is provisional; add sequential checkpoints for competition mode in v0.2.
- UI and virtual touch areas need real phone QA. Performance target 60 FPS, unmeasured.

## Next actions
1. Owner plays Web preview via HTTP host and reports handling/camera/HUD feedback.
2. Compare grip/braking/oversteer to DRIFTIT from real controlled runs.
3. Configure Android SDK/preset for an installable debug APK.
4. Implement checkpoint laps, ghost and garages in subsequent milestone branches.
5. Do not alter approved look or claim official creator association without permission.
