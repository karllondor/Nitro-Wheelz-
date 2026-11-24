# Nitro Wheelz — INTEGRATION MANIFEST

One authoritative development lineage (issue #33). Every combined build adds a section here: what it contains, from which
commits, what was tested where, and what the owner still has to check on a phone. **Integration is not accepted because
CI passes; it is accepted after the owner's phone QA.**

---

## v0.1.45 — unified development preview 3: smoother remote car + HOTSPOT guide (2026-11-24)

| | |
|---|---|
| Canonical branch | `integration/nitro-dev` |
| APK built from | **`ef7f9056d024d22a32d3ae3fc8742f11f55bafdf`** (= v0.1.44 docs head `0b87849` + one commit; later commits on the branch are documentation only) |
| Integrator / model | Claude Code, **`claude-sonnet-5-5`** as reported by `get_session` |
| Android package | **`com.karllondor.nitrowheelz.dev`** "Nitro Wheelz DEV" — verified in the built APK manifest; separate from production `com.karllondor.nitrowheelz` |
| Version | 0.1.45, versionCode 45 |
| Trigger | the owner's first real two-phone test of local multiplayer on v0.1.44 (#31 comment 7125741006, #33 comment 7125741282); claim #33 comment 7125990483 |
| Status | CODE_READY · CI_PASS · EMULATOR_PASS · APK_READY · **OWNER_QA_PENDING** · NOT merged to `main` · NOT a production release |

### What changed (multiplayer only; no driving, scoring, HUD, builder, editor, event, water or save change)
| # | Owner report on v0.1.44 | Change in 0.1.45 | Proof |
|---|---|---|---|
| 1 | "at the start it glitched, the son's car jumped" (connection never dropped) | `NitroNetRemoteView` (steered render clock, jitter-adaptive 110–340 ms delay, discontinuity smoothing, clock-step re-sync); the sender stamps snapshots with simulation time | `net_remote_view_test`: deterministic Wi-Fi / phone-hitch MODEL, same packets through the v0.1.44 receiver and the new one: 21 visible pops (worst 4.60 m, link stalls and 30 fps phones) → 0 pops, worst 0.35 m. **A model, not a Wi-Fi measurement; the cause on the owner's phones is UNCONFIRMED.** Emulator: the new receiver drove the remote car 54.5 m inside the exported APK |
| 2 | "it said we need Wi-Fi, we did not know a hotspot works" | menu line "NO WI-FI? NO PROBLEM. ONE PHONE'S HOTSPOT IS ENOUGH.", **NO WI-FI? HOTSPOT HOW-TO** page (steps for both phones), clearer no-address / not-on-a-network / unreachable texts | `multiplayer_lobby_test`; container screenshot `docs/dev/handoffs/evidence/issue-31-lobby-hotspot-v0145.jpg` |
| 3 | (so the next report carries data) | `LINK GOOD / FAIR / POOR` next to the other player's score | `net_race_test` |
Open question to the owner: what "I left the map" meant (exit to the menu is by design; app in the background or a locked screen hits the 6 s silence timeout).

### Feature inclusion (unchanged from v0.1.44, all still IN the APK)
Solo race / records / stars, Practice / Club / Pro events, ROAD 12 m, water (#19), node editor (OPEN / SET START / REVERSE / terrain / widths), offline multiplayer, Park + tutorial, garage, all six main-menu entries: covered by the same specs as v0.1.44 (all PASS again) and by the on-device inventory below.

### Tests (exact)
* Container: `GODOT_BIN=… bash tools/run_godot_checks.sh` on `ef7f905` → **exit 0, 59 specs, 61 PASS lines**, no `ERROR:` / `FAIL:` (v0.1.44: 58 specs / 60 PASS; +1 = `net_remote_view_test`).
* CI on `ef7f905`: Godot pinned import and smoke [45355987413](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/45355987413) **success** (59 specs, 61 PASS) · Foundation checks [45355987373](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/45355987373) **success** · Android Debug APK [45355987448](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/45355987448) **success** (jobs `android` + `workshop-device`).
* Emulator (inside the exported APK, package `.dev`): Astra's workshop smoke **PASS** (`technical 90.16 | pending 138`, identical to v0.1.44) and the integration check **PASS** (25 ok items: 12 feature files packed, Practice / Club / Pro + ROAD 12 m, water footprint code, six menu entries, host on UDP 47821 + join, lobby, START after both READY, synchronised GO, records blocked in the multiplayer race, remote car followed 54.5 m, remote score label, own car drives, clean leave, solo race untouched, terrain circuit opened in the node editor, SET START, SAVE AS with terrain heights, Club event judging with 30 zones, race starts on the chosen node). The emulator is not a phone and not a radio: the two sessions talk over the device's own loopback.

### APK
* Artifact `Nitro-Wheelz_v0.1.45_Android-debug` (id 14902576613), run https://github.com/karllondor/Nitro-Wheelz-/actions/runs/45355987448
* `Nitro-Wheelz_v0.1.45_Android-debug.apk`, 81,299,115 bytes, **SHA-256 `352e1066b641be8e206bc0080e5923daa8491f911b899110460d5a02f10cd632`** (downloaded again into a fresh directory, identical to the workflow's `.sha256`, zip test clean)
* Manifest strings: package **`com.karllondor.nitrowheelz.dev`** (no `.review`), versionName 0.1.45, `android.permission.INTERNET`; arm64-v8a + x86_64.

### Coordination
* PR #36 (GPT-6, draft, `feat/pc-web-hud-v0145` @ `1cfab07`, PC/Web HUD, base `0b87849`): a dry-run merge with this commit conflicts **only** in `tools/run_godot_checks.sh` (the single spec line); it must rebase onto `ef7f905` or later, and it takes the next free version number (its branch name says v0145) when the owner accepts it. Nothing of it is in this build.

### Open items (carried over, none blocks this build)
* **Phone QA** of everything, above all the two-phone retest: does the jump at the start disappear, does a **hotspot** join work (never tried by anyone), what the LINK word says on real Wi-Fi — OWNER_QA_PENDING.
* Typing the host's address is still manual (automatic room discovery not started): likely the next friction on a hotspot.
* **Web:** the web menu still shows LOCAL MULTIPLAYER although browsers cannot send raw UDP — owner decision pending (see v0.1.44).
* Graphics feedback from the owner (PC build "looks bad", concept image): awaiting the PC screenshot, the PC build type and the concept file; nothing changed in this build.
* Headless teardown sometimes reports one leaked audio object at exit (cosmetic, pre-existing); promotion to the standard package needs an owner decision and a save-migration test; editor tests depend on the editor's "last track" marker being absent.

---

## v0.1.44 — unified development preview 2: Astra's independent QA fixes integrated (2026-11-23)

| | |
|---|---|
| Canonical branch | `integration/nitro-dev` |
| APK built from | **`f25fc33f78d57298e927ba061dfbd93e7b093ba3`** (= `44a5600` v0.1.43 docs head + merge `405e368` of PR #34 + version bump `191d982` + on-device inventory `f25fc33`) |
| Integrator / model | Claude Code, **`claude-sonnet-5-5`** as reported by `get_session` (the task header said "Opus 5.5"; the session had been switched back to Sonnet, so the actual model is recorded) |
| Android package | **`com.karllondor.nitrowheelz.dev`** "Nitro Wheelz DEV" — verified in the built APK manifest; separate from production `com.karllondor.nitrowheelz` |
| Version | 0.1.44, versionCode 44 |
| Status | CODE_READY · CI_PASS · EMULATOR_PASS · APK_READY · **OWNER_QA_PENDING** · NOT merged to `main` · NOT a production release |

### Integrated change: PR #34 (`review/issue-33-fixes` @ `ef32b40714312d1fdeaf3201e94e64b3dcc1a033`, Astra / GPT-6.2)
Heads confirmed immediately before merging: PR head = `ef32b40…`, integration head = `44a5600…` (the PR's base, so a clean no-squash merge). Source commits `cc6994b`, `ef32b40`.
| # | Finding on v0.1.43 (Astra's QA, reviewed independently) | Fix in 0.1.44 | My verification |
|---|---|---|---|
| 1 MAJOR | Start-line shuffle: reverse over the line spent **25/25** Club sectors, forward crossing credited **lap 2** | signed seam crossings (`lap_winding` in `race.gd`); judge paused while behind the line; restart recomputes it | Astra's `integration_boundary_test` **run by me on the unfixed 0.1.43 code → FAIL** (missed 25/25, lap 2, splits 1); on the merged code → PASS (missed 0/25, lap 1, splits 0). Code read: open routes return before the new logic, `last_progress` / `lap_winding` written only in `_ready`, `_lap_logic`, `_restart`; `results_screen_test` was adapted from a one-call shortcut to a real progress sequence (the old shortcut cannot work with stateful crossings) and still proves 3 laps + finish |
| 2 MAJOR | Node editor OPEN erased per-node widths: Shin-Kawa's 25–26 m sections became 24 m | `_adopt` keeps `widths_m`; preview + insert / delete / add keep the profile; SET START / REVERSE already permuted it | same test: unfixed → "expected max 26 m, actual 24 m", 4 width assertions FAIL; merged → 26 m, PASS. `DNA.repair` (AUTO-SMOOTH) keeps the node count, so the profile stays aligned. My v0.1.43 test (`terrain_integration_matrix_test`, 12 m ROAD kept) still passes |
| 3 MAJOR | A PR **targeting** `integration/nitro-dev` could build with the production package id | workflow: PR-targeted builds → `com.karllondor.nitrowheelz.review.pr<N>` + LAB artifact name; push builds of the branch stay `.dev` | workflow read; this build's APK manifest = `.dev` (unchanged canonical path); Astra's PR artifact was decoded by her as `.review.pr34` |
| 4 MINOR | LAN HUD showed solo "NEXT ★1 1,600"; finish screen drew solo stars / rankings | HUD shows "LOCAL MULTIPLAYER"; results hide stars, top runs and solo deltas for multiplayer | `net_race_test` (extended: HUD text + results after the peer left, records byte-identical) PASS; **emulator screenshot shows "LOCAL MULTIPLAYER" in the HUD** |
No finding was dismissed. No feature was removed or disabled by the PR (checked: diff touches only `race.gd` lap / judge-gate / HUD cue, `race_results.gd` multiplayer branches, `track_editor.gd` width handling, `android-debug.yml`, tests).

**Test-isolation note (not a product bug, not changed):** during my review `editor_geometry_test` failed once locally ("EDIT TRACK missing"). Cause found and reproduced on purpose: my own desktop dry run had left the editor's "last edited track" marker pointing at a Club terrain circuit, so the editor started from an event circuit and the result screen showed the event panel ("EDIT ROAD"). With the marker removed (the state of any fresh CI machine) the test passes 5/5; with the marker pointing at the Club circuit it fails every time. The editor tests therefore depend on that marker being absent or flat — a pre-existing fragility in the test suite, independent of PR #34.

### Feature inclusion matrix (v0.1.44 — all IN the APK; verified on this commit)
| Feature | Verified by (local suite = 58 specs / 60 PASS; CI run 45220331334 = same; emulator = run 45220331313) | Owner phone |
|---|---|---|
| Solo race, HUD, results, **records / stars per layout**, garage, cars, physics C+ / A, Park + tutorial | full suite (driving, results_screen, track_records, physics_modes, park_*, …); emulator: solo race → no multiplayer object, records allowed, car drives | pending |
| **Practice / Club Event / Pro Event**, procedural zones, judging, event result panel | event_workshop_test; emulator: Astra's smoke `PASS technical 90.16 / pending 138` on the `.dev` APK; inventory: modes `[practice, club, pro]` packed | pending |
| **ROAD / TOUGE 12 m** vs 24 m circuit | event_workshop_test, terrain_integration_matrix_test; inventory: ROAD width 12.0 | pending |
| **Water (#19)**: stream below the full bridge-deck width | terrain_water_footprint_test, terrain_water_road_test, matrix test (≥ 2.19 m under a shaped Club ROAD circuit); inventory: footprint code packed | pending |
| **Node editor**: OPEN / SET START / REVERSE / terrain circuits / per-node widths (new) | node_editor_open_test, integration_boundary_test, editor_geometry / editor_results; emulator: terrain circuit opened, SET START, SAVE AS, DRIVE | pending |
| **Offline multiplayer** (HOST / JOIN / READY / START, countdown, remote car, no records, no solo stars (new)) | net_session, net_race, multiplayer_lobby; emulator: host + joiner over the device ENet stack, GO, remote car followed (61.5 m), records blocked then allowed | pending (2 phones) |
| Main menu: DRIVE, PARK, LOCAL MULTIPLAYER, GARAGE, TRACK BUILDER, SETTINGS | emulator inventory on the real menu | pending |
| Five-star progression / unlock economy | **not implemented anywhere** (owner decision pending) | — |

### Tests (exact)
* Container: `GODOT_BIN=… bash tools/run_godot_checks.sh` on the merged + bumped code → **exit 0, 58 specs, 60 PASS lines**, no `ERROR:` / `FAIL:` (includes both lines' tests, `terrain_integration_matrix_test`, `integration_boundary_test`).
* CI on `f25fc33`: Godot pinned import and smoke [45220331334](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/45220331334) **success** (58 specs, 60 PASS) · Foundation checks 45220331590 **success** · Android Debug APK [45220331313](https://github.com/karllondor/Nitro-Wheelz-/actions/runs/45220331313) **success** (export + INTERNET manifest check + `.dev` package; job `workshop-device` = Android 35 emulator).
* Emulator (inside the exported APK, package `.dev`): Astra's workshop smoke **PASS** (`technical 90.16 | pending 138`) and the integration check **PASS — 24 checks**: 12 feature files packed, modes + ROAD 12 m, water code, 6 menu entries, multiplayer host + join + lobby + READY + START + GO + records blocked + remote car followed + cleanup, solo race (no multiplayer object, records allowed, car drives), terrain circuit in the node editor with landscape, SET START, SAVE AS with heights, node-shaped + world kept, terrain race judged as Club (30 zones) starting on the chosen node. Screenshots: `docs/dev/handoffs/evidence/issue-33-v0144-android-emulator.jpg`.

### APK
* Artifact `Nitro-Wheelz_v0.1.44_Android-debug` (id 14839864625), run https://github.com/karllondor/Nitro-Wheelz-/actions/runs/45220331313
* `Nitro-Wheelz_v0.1.44_Android-debug.apk`, 81,282,387 bytes, **SHA-256 `02397bc67ca3cc98dfb1efe1f62b59e69a799609532ebee349bea9f9ff391ebc`** (downloaded again, identical to the workflow's `.sha256`, zip test clean)
* Manifest strings: package **`com.karllondor.nitrowheelz.dev`**, versionName 0.1.44, `android.permission.INTERNET`; arm64-v8a + x86_64.

### Open items (carried over, none blocks this build)
* **Phone QA** of everything (touch, frame rate, two-phone hotspot, audio, bridge in both cameras) — OWNER_QA_PENDING.
* **Web:** Astra's cross-platform QA (#33 comment 7104965829) found that local multiplayer cannot work in the browser (no raw UDP in HTML5) while the web menu still shows LOCAL MULTIPLAYER, plus a Web audio-sample console warning. Not part of the Android DEV APK; needs an owner decision (disable / explain the entry on Web).
* Headless teardown sometimes reports one leaked audio object at exit (cosmetic, pre-existing); long-session memory on a handset unmeasured.
* Promotion of this lineage to the standard package needs an owner decision and a save-migration test.
* Editor tests depend on the editor's "last track" marker being absent (see the test-isolation note).

---

## v0.1.43 — first unified development preview (2026-11-23) — superseded by v0.1.44

| | |
|---|---|
| Canonical branch | `integration/nitro-dev` (new; serialized integration lane, #33) |
| APK built from | `6d1ef7128d390c9788e5f07bacd6ad2844ef6424` |
| Integrator / model | Claude Code, `claude-opus-5-5` (session model per `get_session`; the owner switched the session to Opus for this task) |
| Android package | **`com.karllondor.nitrowheelz.dev`**, launcher name **"Nitro Wheelz DEV"** (separate from the production `com.karllondor.nitrowheelz`: installs NEXT TO it, never touches its saves) |
| Version | 0.1.43, versionCode 43 |
| Status | CODE_READY · CI_PASS · EMULATOR_PASS · APK_READY · **OWNER_QA_PENDING** · NOT merged to `main` · NOT a production release |

### Source lines (verified heads, fetched before integrating)
| Line | Branch @ head | Agent | Contains |
|---|---|---|---|
| Common base | `agent/claude/issue-27-tutorial-bugfix` @ `2bdcb4c` (v0.1.39) | Claude | everything up to the tutorial bugfix (Park, physics C+ / A, white Lada N20, Android start screen, …) |
| Claude | `agent/claude/node-editor-open-start` @ `015d619` (= `4b64997` v0.1.42 + handoff text) | Claude Sonnet | v0.1.41 offline local multiplayer (`5276f68`, `679f4a3`, `a490690`, `17ded17`), v0.1.42 node editor OPEN / SET START / REVERSE / terrain circuits (`4b64997`) |
| Astra | `agent/codex/issue-19-water-integration` @ `8038f79` (draft PR #32), which contains `agent/codex/issue-29-procedural-events` @ `19f507a` (draft PR #30) | GPT-6.2 Astra | #29 Practice / Club / Pro judged events, procedural zones, ROAD / TOUGE 12 m surface, Event Workshop, Android workshop smoke (`6a93cee` … `19f507a`); #19 stream below the full bridge-deck width + visible lowered stream (`cae167a`, `8038f79`) |

`git merge-base --is-ancestor 19f507a 8038f79` = true, so merging `8038f79` brings all of #29 and the water fix. Nothing was cherry-picked and
nothing was squashed: both histories are in `integration/nitro-dev`.

### Integration commits
| Commit | What |
|---|---|
| `80d795e` | the merge. `race.gd`, `boot.gd`, `terrain_builder.gd` merged automatically (disjoint hunks — both sides kept, checked by reading the result). Conflicts only in version files (→ 0.1.43 / 43, `x86_64` export kept for the emulator), `run_godot_checks.sh` (union of both test lists), `android-debug.yml` (Astra's package isolation + emulator jobs AND Claude's INTERNET manifest check, plus a `.dev` preview package for this branch) |
| `5dd2d47` | **functional fix found by integration**: the node editor clamped every opened circuit to 18–28 m, so a #29 ROAD (12 m) circuit would have been silently widened when shaped. ROAD keeps 12 m; editor status + OPEN list show event and surface. New `terrain_integration_matrix_test` (fails on the old clamp — verified). |
| `0d8bfcf` | CI: Godot regression + Foundation checks also run on `integration/**` |
| `6d1ef71` | on-device integration check inside the APK on the Android emulator (multiplayer over the device ENet stack + node editor on a terrain circuit + drive) |

### Feature inclusion matrix (v0.1.43)
| Feature | From | In the APK | Verified by (container / CI / emulator) | Owner phone |
|---|---|---|---|---|
| Solo race, HUD, results, records / stars per layout, garage, cars, physics C+ and A diagnostics, white Lada N20 | base v0.1.39 | YES | full suite (results_screen, track_records, physics_modes, white_lada, car_* …) | pending |
| Nitro Wheelz Park + tutorial (v0.1.39 bugfix) | base | YES | park_layout, park_tutorial, park_navigation | pending |
| Android start screen (transparent splash icon) | base | YES | android_start_test | pending |
| Offline local multiplayer (HOST / JOIN / READY / START, countdown, remote car, no records) | Claude v0.1.41 | YES | net_session, net_race, multiplayer_lobby; **emulator: two sessions over the device's ENet stack, real race scene, GO, remote car follows, cleanup** | pending (2 phones) |
| Node editor: OPEN, SET START, REVERSE, terrain circuits with landscape, red unbuildable stretches, node-shaped routing | Claude v0.1.42 | YES | node_editor_open, editor_geometry, editor_results; **emulator: terrain circuit opened, SET START, SAVE AS, DRIVE** | pending |
| Practice / Club Event / Pro Event, procedural zones, judging (wrong edge = 0 technical), event result panel | Astra #29 | YES | event_workshop_test; **emulator: Astra's workshop smoke on the `.dev` APK — PASS, technical 90.16** | pending |
| ROAD / TOUGE 12 m surface vs 24 m circuit | Astra #29 | YES | event_workshop_test, terrain_integration_matrix_test | pending |
| Event Workshop example route (Terrain Builder > MY TRACKS) | Astra #29 | YES | event_workshop_test, emulator smoke | pending |
| Stream / bridge clearance on 12 m and 24 m roads (#19) | Astra water | YES | terrain_water_footprint_test, terrain_water_road_test | pending |
| **Cross-feature**: #29 Club ROAD circuit shaped in the node editor keeps 12 m / ROAD / CLUB / world; race judges it with zones regenerated from the edited road; #19 water still ≥ 2.19 m under the shaped road | integration | YES | terrain_integration_matrix_test (Ojców 621727) | pending |
| Five-star progression / unlock economy | — | **NO (not implemented anywhere, owner decision pending)** | — | — |

### Design gates (kept visible, not removed)
* **Multiplayer runs only on the four unjudged built-in circuits** (oval, sweepers, Shin-Kawa ×2). Judged events in multiplayer are not designed yet
  (#33 §6); the LOCAL MULTIPLAYER menu entry stays; the protocol whitelist refuses every other track. Test: `terrain_integration_matrix_test`.
* **A judged event run writes no record / star** (Astra's session-only result panel) — the same rule as multiplayer and the A diagnostic physics.
* **Node editor edits closed loops.** Point-to-point ROUTES (most ROAD / TOUGE layouts) are edited in the Terrain Builder; OPEN lists them and sends you
  there. Event mode and surface are switched in the Terrain Builder; a circuit shaped in the node editor keeps the mode / surface it had (it no longer
  reopens in the Terrain Builder, because its tiles describe the old road).

### Tests (exact commands)
* Container, Godot 4.7.2 headless: `GODOT_BIN=… bash tools/run_godot_checks.sh` on the merged code → **exit 0, 57 specs, 59 PASS lines, no `ERROR:` / `FAIL:`**
  (includes both lines' tests + `terrain_integration_matrix_test`).
* GitHub Actions on `6d1ef7128d390c9788e5f07bacd6ad2844ef6424`: `Godot pinned import and smoke` run 45171146521 = **success** (57 specs, 59 PASS lines, incl. event_workshop, terrain_water_footprint, net_*, multiplayer_lobby, node_editor_open, terrain_integration_matrix);
  `Foundation checks` 45171146548 = success; `Android Debug APK` 45171146577 = success (job `android` = export + INTERNET manifest check + package `.dev`; job `workshop-device` = emulator).
* Emulator (Android 35 x86_64, Mesa lavapipe, in CI): `tools/android_event_smoke.sh` (Astra, `.dev` package) and `tools/android_integration_smoke.sh` (Claude): both **PASS** on run 45171146577 —
  Astra's workshop smoke: `PASS | Android | technical 90.16 | pending 138`;
  Claude's integration check: `PASS | Android |` 22 checks ok — host on UDP 47821, join 127.0.0.1, lobby, START after READY, synchronised GO, race attached the
  multiplayer controller, records blocked, remote car followed (63.4 m), remote score label, own car drives, leaving cleans up + records allowed again,
  terrain loop generated, node editor opened it with its landscape ("VALID • 1213 m • CLUB EVENT • CIRCUIT • TERRAIN OK"), SET START, SAVE AS with heights,
  node-shaped + world kept, race built the terrain, judged as Club (30 zones), started on the chosen node.
  Screenshots: `docs/dev/handoffs/evidence/issue-33-v0143-android-emulator.jpg` (multiplayer race — the second car is ahead out of frame, its movement is
  checked numerically —, node editor after SET START, race on the shaped Club circuit with zones, Astra's Builder on Ojców 621727). The emulator renders with
  lavapipe and runs the physics slower than real time (the host car reached only 21 km/h in 3.5 s there vs 107 km/h on the desktop dry run): not a phone measurement.
* Desktop dry run of the device check (Xvfb, opengl3): all 22 checks ok, 15 s.

### APK
* Artifact `Nitro-Wheelz_v0.1.43_Android-debug` (id 14816508367), run https://github.com/karllondor/Nitro-Wheelz-/actions/runs/45171146577
* File `Nitro-Wheelz_v0.1.43_Android-debug.apk`, 81,274,014 bytes, **SHA-256 `ccb4d493148d3231acfdb065da0bd7096071d09fc9cef8b7d6f9635f7dd75508`**
  (downloaded again and compared with the workflow's `.sha256`: identical; zip test clean).
* Manifest strings: package **`com.karllondor.nitrowheelz.dev`**, versionName 0.1.43, `android.permission.INTERNET`; native libs arm64-v8a + x86_64.
* Signed with the repository's debug key (persistent if the `NITRO_DEBUG_KEYSTORE_B64` secret is set, as for earlier builds).

### Owner phone test (Nitro Wheelz DEV — installs next to your normal app)
1. Install `Nitro-Wheelz_v0.1.43_Android-debug.apk`; the launcher shows **Nitro Wheelz DEV** next to Nitro Wheelz (your normal app and its records stay untouched).
2. Solo: DRIVE on SHIN-KAWA, PARK tutorial lesson 1–2, garage → everything as v0.1.39.
3. Events: TRACK BUILDER → TERRAIN BUILDER → MY TRACKS → EVENT WORKSHOP; switch Practice / Club / Pro (button left of MOVE) and ROAD / RACE TRACK; DRIVE a Club run → event result panel.
4. Water: Terrain Builder Ojców, a road crossing the stream → water stays under the bridge deck in the Builder and both driving cameras.
5. Node editor: save a terrain LOOP → TRACK BUILDER → EDIT NODES (opens it with the landscape) → SET START on another node → SAVE AS → DRIVE (starts there, still the same event / surface).
6. Multiplayer (two phones, both with the DEV APK, hotspot with mobile data off): LOCAL MULTIPLAYER → HOST / JOIN → READY → START → drive together.
7. Report per item PASS / FAIL / NOT TESTED in #33.

### Known limits / not proven
Everything on a real phone (touch, frame rate, two-phone Wi-Fi / hotspot, install over an older DEV build); open routes in the node editor; judged events in
multiplayer (not designed); the emulator uses software rendering (lavapipe) — its screenshots prove the scenes render, not how they look on the owner's GPU.
