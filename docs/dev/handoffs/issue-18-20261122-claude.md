# Handoff — issue #18 open-route minimap (2026-11-22)

ISSUE / CLAIM / OWNER: #18 (P0) — claimed in the issue by Claude Code, branch `agent/claude/issue-18-minimap`
MODEL / TOOL VERSIONS: Claude Code (Anthropic); the exact serving model id is given in the owner chat report (not written into repository files). Godot 4.7.2-stable (pinned `.godot-version`), Python 3.x (tools only). No Android device used.
BASE BRANCH + SHA: `ccr-91dad981-53kkbi` @ `181fb97` (v0.1.33)
WORK BRANCH + HEAD SHA: `agent/claude/issue-18-minimap` — head SHA in the PR / issue report (a commit cannot contain its own SHA)
OTHER OPEN PRs REVIEWED: #21 (coordination docs, no code), #15 (v0.1.32b, conflicting, NOT touched: it does not change `race_hud.gd` / `race.gd`), #9–#14 (v0.1.7–v0.1.12 against `main`, stale)
PATHS TOUCHED:
- `game/scripts/ui/race_hud.gd` (outline, progress, markers, cache signature)
- `game/scripts/race/race.gd` (4 lines: pass `closed_loop`, `start_progress`, `finish_progress` to the HUD)
- `game/tests/terrain_route_minimap_test.gd` (new), `game/tests/capture_route_minimap.gd` (new evidence tool)
- `tools/run_godot_checks.sh` (one spec name added)
- `docs/dev/handoffs/*` (this file + evidence)
PATHS NOT TOUCHED: VERSION, CHANGELOG.md, HANDOFF.md, workflows, physics, HUD layout, controls, scoring, progression, drift_track.gd

WHY THIS FIX / USER EVIDENCE: phone capture `1000077052.jpg` + `1000077050.mp4` (Touge route, v0.1.33): a diagonal white line joins the two ends of the open route.
Root cause (confirmed in code AND reproduced in-engine with the v0.1.33 code, see evidence): `_rebuild_outline()` always appended the first point (closed the outline); `point_at_progress()` summed the arc with `(i+1)%n`, so the last "segment" was the chord finish -> start and `track_progress` (which the race measures over the REAL segments only) was mapped onto a different arc: the dot left the road. `_minimap()` took the START tangent from point 1 minus the LAST point.

IMPLEMENTATION + EXACT FILE/FUNCTION:
- `race_hud.gd`: new fields `closed_loop` (default true = legacy), `start_progress`, `finish_progress`.
- `_rebuild_outline()`: closes only circuits; open routes end exactly on the last real point (also when the sampling step skips it; the fit box includes it).
- `point_at_progress()`: open = segments 0..n-2, fraction clamped to 0..1 (1.0 = last real point, never the start); circuits keep the periodic formula (asserted bit-identical to the old one).
- `_minimap()`: circuit = start tick as before; open = white START tick + gold FINISH tick with ring, each on its own line (`_end_marker()`).
- `_signature()`: the cached outline is rebuilt when the points, their number or the topology change (not only when the rect changes).
- `race.gd` (HUD wiring): `closed_loop = track.closed_loop`; `start_progress = arc_lengths[start_index]/length`; `finish_progress = track.finish_progress`.

TESTS (container, headless, Godot 4.7.2):
- `terrain_route_minimap_test` PASS (new): outline ends on last real point and is not closed; progress clamped and always on the real polyline (1001 samples, max deviation < 0.01 m); half arc = half of the real length; START != FINISH; control: the same points treated as a circuit leave the route by > 20 m (the check sees the old bug); cache rebuild on topology/points change; circuit progress identical to the legacy formula; a real generated Irish-hills route: HUD `closed_loop=false`, dot within 0.5 m of the car along the whole road, markers on the start / finish lines; a real circuit keeps `closed_loop=true`.
- PASS: hud_layout_test, track_records_test, results_screen_test, main_menu_test, smoke_test, mobile_visual_test, dynamic_camera_test, drift_scoring_test, terrain_physics_test, `tools/check_project.py`.
- Full `tools/run_godot_checks.sh` and the CI run: see the CI result recorded on the branch.
- NOT RUN: Android, any real phone.

ANDROID / WEB / DESKTOP DEVICE PROOF: NOT RUN. In-engine evidence (Xvfb + llvmpipe, 720x1560): `evidence/issue-18-minimap-before-after.jpg` (same generated Japan-touge route, seed 7; top = v0.1.33 code at `181fb97`, bottom = this branch; car at start / middle / finish) + the HUD numbers in `issue-18-minimap-before.txt` / `-after.txt` (before: dot at the finish = (-48.5, 323.5) = back near the start; after: dot = car position).
APP VERSION / ARTIFACT LINK: no version bump in this branch (avoids VERSION/workflow conflicts with PR #15); no APK built from this branch yet.
REGRESSION RISKS / APPROVED LOOK & CONTROLS PRESERVED: HUD layout, speedometer, controls, scoring, laps, physics untouched; circuit minimaps are drawn exactly as before (tests assert it). Risk: a saved route whose first / last points coincide (zero-length) -> `point_at_progress` guards the segment length.
WHAT REMAINS / WHY: phone confirmation by the owner (open Touge: no diagonal at cold start, during the run, after save / load / edit / RESTART). The issue stays OPEN until then. Builder-side previews were not changed (they do not draw this minimap).
NEXT SAFE ACTION FOR THE NEXT AGENT: do not edit `race_hud.gd` minimap code on another branch before this one is reviewed; to verify on a phone, build an APK from this branch (workflow_dispatch of `android-debug.yml` on `agent/claude/issue-18-minimap`) or integrate through the owner's approved PR.
