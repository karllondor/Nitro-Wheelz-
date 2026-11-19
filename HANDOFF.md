# Nitro Wheelz — v0.1.7 BENCHMARK/HUD BRANCH (not released)

Model: GPT-6. Date: 2026-11-18.
Branch: agent/nitro-v0.1.7-benchmarks-hud.
Main remains on v0.1.6 (018efa1af388496fb7ba0a0f15c0c82f27138d0f).

Completed:
- Added independently authored Oval and Sweepers-style geometry datasets without altering Shin-Kawa.
- Both circuits compile as closed collision-safe Track DNA loops and pass centred wall-penetration checks.
- UI prototype follows approved graphic layout; usable touch hitboxes correspond to visual controls.
- Tightened both camera presentations for stronger perceived speed. Preserve existing physical model and velocity-based lead.
- New game test registered in tools/run_godot_checks.sh.
- Version labelled v0.1.7 in Godot, project.json, VERSION, and export artifact names.

Evidence:
- Branch pre-release commit 55815feed76ef46c9ff743312cb2a647e3983e7c, Godot https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44360209917 PASS and Foundation https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44360209889 PASS.
- Android/Web/Windows/Linux for v0.1.7: NOT RUN at creation of this note; obtain artifacts from pull-request workflows and confirm PASS.
- HUMAN Android three-lap driving, actual touch visuals, speed perception, frame rate, camera drift feel, P3 scoring zones and P4 secure checkpoint progression: NOT RUN / NOT IMPLEMENTED.
- DRIFTIT benchmarks share public track dimensions/intent only, not copied control points. Do not compare absolute lap times as matched scientific conditions.

Next: create review PR and export candidate APK; inspect mobile portrait visual; collect four short recordings (Oval/Sweepers in Nitro and DRIFTIT, first top-down), then follow-camera tests, tune physics separately.

