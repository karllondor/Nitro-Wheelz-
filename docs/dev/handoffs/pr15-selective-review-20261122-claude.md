# Selective review of PR #15 (`agent/nitro-v0.1.32b-mobile-feedback`) against the dev head `181fb97` (v0.1.33)

Reviewer: Claude Code (Anthropic; exact serving model id in the owner chat report). Date 2026-11-22.
Method: `git diff b1ef0ef..PR15` (merge base `b1ef0ef`, 32 commits, 32 files, +415 / -82), a trial merge into a scratch worktree of `181fb97` (aborted, nothing pushed), reading every code diff, the PR's own CI (green on its head: android, desktop, web, godot, foundation).
Nothing from PR #15 was merged, cherry-picked or deleted. The PR stays open as it is.

## Trial merge into `181fb97`
Conflicts: `.github/workflows/{android-debug,desktop-export,web-preview}.yml`, `HANDOFF.md`, `VERSION`, `game/project.godot`, `project.json` (all version / artifact-name churn: the PR stamps `0.1.32-b.1`, the dev head is `0.1.33`) and two REAL ones: `game/scripts/vehicles/car_catalog.gd` and `game/tests/factory_models_test.gd` (v0.1.33 added the `flame` car / FLAME checks there). Clean: `CHANGELOG.md`, `docs/QA_MATRIX.md`, `garage.gd`, `race_results.gd`, `settings_panel.gd`, `car_cosmetics.gd`, `glb_car.gd`, `boot.gd`, the new files.

## What the PR contains and what is still needed

| Area | Files | Still needed on v0.1.33? | Recommendation |
|---|---|---|---|
| Version / workflow / release stamp `0.1.32-b.1`, artifact names, `bump_version.py`, `check_project.py`, `package_release.py`, `test_tools.py`, `build_info.json`, `project.json`, `VERSION`, `HANDOFF.md`, `CHANGELOG.md` | many | No — stale; would roll the dev head back from 0.1.33 | DROP (never merge) |
| Car Factory GLB as the DEFAULT model for Lada RED / WHITE and RYU-32 (`factory_test_models()` default ON, dev key renamed `legacy_procedural_cars`, button text, `FACTORY GLB` status) | `car_catalog.gd`, `boot.gd`, `garage.gd` | Yes — the owner asked why the new cars are not visible in the APK (v0.1.28 -> v0.1.32 feedback); still OFF by default on the dev head | PORT as its own task AFTER the owner decides the default (art lock / approval) and re-doing it on top of the `flame` entry; keep the "obsolete saved `factory_test_models=false`" handling |
| Cosmetics independent of the model JSON: `car_factory_cosmetics.json` (136 lines), `cosmetic_profile()`, `visual_choice()`, livery id in `car_cosmetics.gd` (RYU stripes = a PAINT preset on the same GLB) | `car_catalog.gd`, `car_cosmetics.gd`, `garage.gd`, new json | Yes if the GLBs become the default (garage paint / wheels for every factory car) | PORT together with the previous row; resolves the `car_catalog.gd` conflict by hand |
| Driver name + local top-runs table (driver, car, points, stars, time; legacy rows "UNKNOWN") | new `player/driver_profile.gd`, `race_results.gd`, `settings_panel.gd`, tests | Independent of the P0 bugs; v0.1.32 changed `race_results.gd` too (record ids carry a layout fingerprint, `layout_id`) — no textual conflict, semantics must be re-tested (`results_screen_test`, `track_records_test`) | PORT as its own small task if the owner wants it (feature, not a bug fix) |
| GLB rear hub yaw pinned to 0 every frame, roll phase wrapped to ±PI | `glb_car.gd` (+8 / -1) | Harmless hygiene; it is NOT the cause of issue #16: the rear hub yaw was already measured 0.00 in every case, and the black shapes at the rear wheels are the tyre smoke (see `issue-16-20261122-claude.md`) | OPTIONAL small port; do not count it as the fix for #16 |
| `docs/MOBILE_QA_v0.1.32b.md`, `DEVELOPER_MODE.md`, `QA_MATRIX.md`, `RELEASE_POLICY.md` | docs | Historical record of the owner's feedback and the wheel hypothesis | KEEP in the PR as history; do not merge the version text |
| Test edits (`e30_factory_car_test`, `factory_models_test`, `garage_audio_test`, `mobile_visual_test`, `results_screen_test`, `visual_identity_test`) | tests | Follow the model default flip and the version stamp | Port with the matching feature, re-derived on the dev head |

## Superseded by newer work
- The PR's wheel analysis (hub yaw) is superseded by issue #16's measurements (hub yaw 0.00, geometry correct, tyre smoke renders black young particles).
- `RYU-32 TEST LOOK` (CLEAN / LIVERY dev button) exists on the dev head; the PR removes it in favour of the PAINT preset — decide together with the default flip.

## Suggested order (each its own task branch from the dev head, owner approval before integration)
1. Owner decision: should the Car Factory GLBs be the default for Lada / RYU now?
2. If yes: port the default flip + cosmetics presets (one branch), re-run `factory_models_test`, `garage_audio_test`, `mobile_visual_test` + garage / race captures.
3. Driver name / local top-runs table (one branch) if wanted.
4. Rear-hub hygiene (optional).
Never merge the old PR wholesale.
