# Handoff — #33 unified DEV preview 2: v0.1.44 = v0.1.43 + Astra's PR #34 (integration/nitro-dev, 2026-11-23)

ISSUE / CLAIM / OWNER: #33 (owner dispatch "P0 — INTEGRATE ASTRA QA FIXES"); claim https://github.com/karllondor/Nitro-Wheelz-/issues/33#issuecomment-7107420370.
MODEL / TOOL VERSIONS: `claude-sonnet-5-5` per `get_session` (the dispatch header said "Opus 5.5"; the session had been switched back to Sonnet, the actual model is recorded). Godot 4.7.2-stable; Android 35 x86_64 emulator in CI.
BASE + SOURCE: `integration/nitro-dev` @ `44a560005a5586faa1e7120c94e7ff3999c177ae` (v0.1.43) + `review/issue-33-fixes` @ `ef32b40714312d1fdeaf3201e94e64b3dcc1a033` (PR #34, commits cc6994b + ef32b40). PR base == integration head at merge time (both confirmed by `git rev-parse` right before the merge).
WORK BRANCH + BUILD SHA: `integration/nitro-dev`; APK built from `f25fc33f78d57298e927ba061dfbd93e7b093ba3` (merge `405e368`, bump `191d982`, on-device inventory `f25fc33`); later commits documentation only.
PATHS TOUCHED: the PR's 9 files (`race.gd`, `race_results.gd`, `track_editor.gd`, `android-debug.yml`, `net_race_test.gd`, `results_screen_test.gd`, `integration_boundary_test.gd` (+ uid), `run_godot_checks.sh`); version files + 3 workflows (0.1.44 / 44, artifact names); `game/tests/android_integration_capture.gd` (inventory + solo drive); CHANGELOG, INTEGRATION_MANIFEST, WORK_STATE, evidence jpg.
PATHS NOT TOUCHED: Astra's events / water code, multiplayer protocol / session, physics, scoring, Park, art, `main`, the production package.
REVIEW: independent read of the whole diff; failing controls reproduced on the unfixed code (see manifest); no finding dismissed; nothing removed. Test-isolation weakness found (editor tests depend on the editor's last-track marker being absent) — documented, not changed.
TESTS: local full suite exit 0 (58 specs, 60 PASS); CI Godot 45220331334 success, Foundation 45220331590 success, Android 45220331313 success incl. emulator (Astra's workshop smoke PASS, integration check PASS with 24 checks). Details: docs/dev/INTEGRATION_MANIFEST.md.
APK: artifact 14839864625, SHA-256 `02397bc67ca3cc98dfb1efe1f62b59e69a799609532ebee349bea9f9ff391ebc`, package `com.karllondor.nitrowheelz.dev`, versionName 0.1.44 / code 44.
DEVICE PROOF: emulator only. Physical phones: NOT RUN (owner QA).
REMAINING / NEXT: owner phone QA; Web menu decision (LOCAL MULTIPLAYER cannot work in the browser); production promotion needs a decision + save-migration test; do not push to `integration/nitro-dev` without announcing it in #33.
