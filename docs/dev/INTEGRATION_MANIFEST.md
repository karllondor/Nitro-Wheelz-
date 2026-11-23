# Nitro Wheelz — INTEGRATION MANIFEST

One authoritative development lineage (issue #33). Every combined build adds a section here: what it contains, from which
commits, what was tested where, and what the owner still has to check on a phone. **Integration is not accepted because
CI passes; it is accepted after the owner's phone QA.**

---

## v0.1.43 — first unified development preview (2026-11-23)

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
