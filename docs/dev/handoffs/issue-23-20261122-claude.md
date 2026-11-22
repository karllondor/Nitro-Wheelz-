# Handoff — issue #23 driver name + TOP RUNS table (2026-11-22)

ISSUE / CLAIM / OWNER: #23 — claimed in the issue by Claude Code, branch `agent/claude/driver-top-runs`. Owner approval + column order: chat 2026-11-22 ("Tak, ale w kolejności kierowca, auto, gwiazdki, czas i punkty").
MODEL / TOOL VERSIONS: Claude Code (Anthropic); exact serving model id in the owner chat report (not written into repository files). Godot 4.7.2-stable. No Android device.
BASE BRANCH + SHA: `ccr-91dad981-53kkbi` @ `181fb97` (v0.1.33)
WORK BRANCH + HEAD SHA: `agent/claude/driver-top-runs` — head SHA in the report
OTHER OPEN PRs REVIEWED: #15 (source of the port; stays open, unmerged), #21, #9–#14 stale
PATHS TOUCHED: `game/scripts/player/driver_profile.gd` (new), `game/scripts/ui/race_results.gd`, `game/scripts/ui/settings_panel.gd`, `game/tests/driver_profile_test.gd` (new), `game/tests/results_screen_test.gd`, `game/tests/capture_results_driver.gd` (evidence tool), `tools/run_godot_checks.sh`, `docs/dev/handoffs/*`
PATHS NOT TOUCHED: scoring, stars, ranking maths, record ids (`layout_id`), HUD, physics, controls, VERSION, CHANGELOG, HANDOFF.md, workflows

WHAT CHANGED
- Local driver name (`user://nitro_driver.cfg`, <= 16 characters, spaces collapsed, DRIVER when empty), editable in SETTINGS; local device only, no account / network.
- Every NEW run stores `driver` and the exact `car`; older runs without them stay UNKNOWN in the table (never backfilled with the current car).
- Finish screen TOP RUNS table, owner's column order: **# | DRIVER | CAR | STARS | TIME | POINTS** (`RESULTS.TOP_RUN_COLUMNS`); this run stays highlighted; ranking is still by points.
- BUG FOUND IN THE PR #15 VERSION: its `driver_profile.gd` named the accessors `get_name` / `set_name`; called on the preloaded script they hit the built-in `Resource.get_name / set_name` and silently return null, so the name would never have been saved. Renamed `get_driver_name` / `set_driver_name` (test `driver_profile_test` caught it).

TESTS (container, headless, Godot 4.7.2): PASS `driver_profile_test` (new: name cleaning + persistence, SETTINGS field saves, new runs store driver + exact car, an older run stays without them, ranking unchanged, column order, the screen fits portrait + landscape), `results_screen_test`, `track_records_test`, `main_menu_test`, `tools/check_project.py`. Full `run_godot_checks.sh` / CI: see the CI result on the branch.
EVIDENCE: `evidence/issue-23-results-top-runs-phone.png` (finish screen 720x1560, mixed rows: UNKNOWN legacy run, runs with driver + car; this run highlighted).
ANDROID / DEVICE PROOF: NOT RUN (legibility on a real 690–720 px phone, long names: a 16-character name is clipped in the DRIVER column at 720 px width).
REGRESSION RISKS: the DATE column of the old table is gone (the PR's design too). Names are not unique, not validated beyond cleaning.
NEXT SAFE ACTION: build an APK from the integration branch; owner phone check: set a driver name in SETTINGS, finish a run, finish another with a different car, check both rows keep their driver / car.
