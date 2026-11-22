# Handoff — issue #27 NITRO WHEELZ PARK (v0.1.37, 2026-11-22)

ISSUE / CLAIM / OWNER: #27 — claimed in the issue by Claude Code (comment 7079397895), branch `agent/claude/issue-27-nitro-wheelz-park`. Owner dispatch c7079276183 (start now, no merge / release).
MODEL / TOOL VERSIONS: Claude Code (Anthropic); serving model id in the owner chat report (not written into repository files). Godot 4.7.2-stable. No Android device.
BASE BRANCH + SHA: `agent/claude/feel-visuals-v0.1.36` @ 465f7e1 (contains v0.1.34 - 0.1.36; the dev branch has none of it yet).
WORK BRANCH + HEAD SHA: `agent/claude/issue-27-nitro-wheelz-park` — head SHA in the report.
OTHER OPEN PRs / CLAIMS REVIEWED: #15 (stale, not touched), #9-#14 stale; #25 / #24 owned by me earlier, no other agent claims on these paths.
PATHS TOUCHED: NEW `game/scripts/park/*` (9 scripts), `game/tracks/nitro_wheelz_park.json` (marker), `game/assets/brand/nitro_wheelz_logo_pavement.png`, `game/assets/shaders/pavement_paint.gdshader`, `game/assets/fonts/Exo2-ItalicVF.ttf` (+ import), `game/tests/park_layout_test.gd`, `park_tutorial_test.gd`, `capture_park.gd`, `car_performance_audit.gd`; SMALL edits: `game/scripts/race/race.gd`, `ui/race_hud.gd`, `ui/race_pause.gd`, `ui/hud_style.gd` (font fallback), `boot.gd`, tests `main_menu_test.gd`; `tools/run_godot_checks.sh`, `tools/art/render_logo_svg.gd`, `tools/perf/*`, docs, version files.
PATHS NOT TOUCHED: the drive model / handling numbers / car profiles, scoring, stars, records, the track registry and the circuits, camera logic (#17), launcher / splash.

OWNER DECISIONS APPLIED (see `docs/dev/OWNER_DECISIONS.md` draft D-03 .. D-06): one surface, two entries, no barriers, movable cones, flattened-eight route for starter cars, the approved logo asset, no stars in the Park.
IMPLEMENTED: see `docs/NITRO_WHEELZ_PARK.md` (features, layout numbers, detection thresholds, files, measurements).
NOT IMPLEMENTED / OPEN: any owner-approved geometry (the layout is PROVISIONAL); a drifting scripted driver for the eights (feasibility proven by a path follower only); cone-hit sound; per-lesson star / reward integration (not allowed by the decisions).

TESTS (container, headless, Godot 4.7.2): PASS `park_layout_test`, `park_tutorial_test`, `main_menu_test`, `mobile_visual_test`, `hud_layout_test`, `gas_pedal_shape_test`, `track_details_test`, `smoke_test`; the full suite = CI on the branch (see the report).
EVIDENCE: `evidence/issue-27-pad-overview.jpg` (the whole pad from above), `issue-27-logo-game-camera.jpg` (top-down game camera at the logo), `issue-27-logo-flat-overview.jpg`, `issue-27-tutorial-screens.jpg`, `issue-27-free-drive-and-lessons.jpg` (container, llvmpipe, 900 x 2000; `tests/capture_park.gd`).
ANDROID / DEVICE PROOF: NOT RUN. OWNER_QA_PACKET posted in #27.
REGRESSION RISKS: PARK button added to the main menu (one more row); `hud_style.gd` registers the full Exo 2 font as glyph fallback (+302 KB APK, same family, SIL OFL) - Polish letters in names / lessons now render in the same face; the pause menu has an optional extra row.
NEXT SAFE ACTION: owner phone test on one APK: PARK -> FREE DRIVE (drive everywhere, hit cones), PARK -> START TUTORIAL (GAS ... DONUT LEFT), POMIŃ, pause row, logo from the game camera.
