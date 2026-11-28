# Issue #65 / #59 — Android UI rescue (v0.1.52) — Claude Opus handoff

```text
ISSUE / CLAIM / OWNER: #65 (P0 Android UX) + #59 (Developer menu); CLAIM issuecomment-7231227709; owner karllondor
MODEL / TOOL VERSIONS: Claude Opus (claude-opus-5-5, session reports it); Godot v4.7.2.stable.official.ed1daf0bf (headless + xvfb opengl3)
BASE BRANCH + SHA: feat/my-tracks-management-v0151 @ b3a2cab7acc325425d17e87c5eff9000c9463b51 (PR #63 head, verified)
WORK BRANCH + HEAD SHA: fix/android-ux-rescue-v0152 @ see the PR (draft) — exact SHA in the PR / #65 report
OTHER OPEN PRs REVIEWED: #63 (base), #58, #45, #44 (chain below it), #64 Forest Lab (NOT used here), #66 Sonnet colours (no branch yet)
PATHS TOUCHED / PATHS NOT TOUCHED: see "Files" below. NOT touched: scoring, drift zones, vehicle physics, race HUD, Forest Lab, tracks.
```

## Why (user evidence and root causes)

The owner reported on the phone: DEVELOPER cannot be scrolled and BACK is unreachable; SAVE / SAVE AS / RENAME / DELETE dialogs
are tiny; My Tracks scrolls only sometimes; Garage paint cannot be found; green / red rectangles cannot be turned off.

BEFORE captures at 540 x 1200 portrait (`docs/dev/handoffs/evidence/android-ux-rescue/before_contact.png`) confirmed every point:

| # | Symptom | Root cause |
|---|---|---|
| 1 | DEVELOPER cut off, BACK missing | the page is a plain VBox in a CenterContainer; taller than a portrait phone, BACK / TOUCH DIAGNOSTICS / RESET below the screen edge |
| 2 | system BACK closed the game | `application/config/quit_on_go_back` was the engine default (true) |
| 3 | tiny dialogs | native `ConfirmationDialog`, 90 % / max 570 px of a 1280-unit canvas = a small desktop window on the phone |
| 4 | scrolling "sometimes" | nested 56 %-high ScrollContainer inside the page; a drag that starts ON a button does not reach the container (headless harness: scroll 0), and the button under the finger may fire on release |
| 5 | Garage paint | PAINT exists (`garage.gd _next_paint`) and works, but 14 pt text on a 1280 canvas, a cycle button with no visible palette, greyed out for R32 FLAME (no palette for that test car) |
| 6 | green / red outlines | TOUCH DIAGNOSTICS (intended developer overlay, `touch_diagnostics.gd`); its OFF switch was in the unreachable part of DEVELOPER |

## Implementation

| Fix | Where |
|---|---|
| Every menu page scrolls inside the screen (`NitroTouchScroll`), BACK in a footer that never scrolls away, page height fitted to the screen minus logo / footer / status | `boot.gd _ready / _fit_page / _small / show_page / _scroll_list` |
| Drag vs tap arbitration: > 14 ui-units vertical = scroll (finger follows, fling), the touched button is cancelled (no press on release); still tap = press; horizontal drags (sliders) untouched; engine drag disabled (huge dead zone) so the two never fight | `ui/touch_scroll.gd` |
| Android BACK: `quit_on_go_back=false`; `AndroidBack` autoload closes an open card first (CANCEL, never confirm), otherwise sends `ui_cancel`, which every screen already handles (menus → parent page, garage → back, race → pause, builders → cancel tool); main menu on a phone leaves the game (Android convention); the LAN lobby keeps its own handler (group `own_go_back`) | `project.godot`, `ui/android_back.gd`, `boot.gd go_back`, `net/multiplayer_lobby.gd` (1 line) |
| SAVE / SAVE AS / RENAME / DELETE: in-scene card (`NitroMobileModal`), 92 % width in portrait, upper screen (keyboard), 88-unit buttons, 28-unit name field with clear button, DELETE in red, errors stay on the card, CANCEL / BACK never call the store. Same `FILE_DIALOG.show(...)` call in all three screens | `ui/mobile_modal.gd`, `ui/track_file_dialog.gd` |
| DEVELOPER first row: DIAGNOSTIC OVERLAYS (lists TOUCH / AUDIO / TELEMETRY that are ON; tap = all OFF); the touch overlay has its own DIAG OFF ✕ button | `boot.gd active_overlays / overlays_off`, `ui/touch_diagnostics.gd turn_off` |
| Garage: two-line car buttons, larger PAINT / WHEELS text, a row of paint swatches (tap = that paint, saved with the existing cosmetics file), "factory paint only" for R32 FLAME | `ui/garage.gd _build_swatches / _choose_paint`, `vehicles/car_cosmetics.gd choose_paint` (cosmetic only) |
| Version 0.1.52 / versionCode 52 (QA package unchanged: `com.karllondor.nitrowheelz.review.pr45`) | `VERSION`, `project.json`, `project.godot`, `export_presets.cfg` |

## Tests

* NEW `game/tests/android_ux_rescue_test.gd` (in `tools/run_godot_checks.sh`): 1080 x 2340 portrait window; BACK on screen on 8 pages,
  DEVELOPER scrolls to its last switch, simulated touch drag starting on a button scrolls without pressing it, still tap presses,
  AndroidBack closes a card then pages, card size / position / error / cancel, overlays off, DIAG OFF, garage swatches.
  Mutation checks: removing the button cancel → FAIL "button under a scrolling finger must not be pressed"; disabling the
  custom scroll → FAIL "a drag starting on a button must scroll the page (scroll 0)".
* `track_management_checks.gd` adapted to the new card (same assertions: duplicate protection, rename, delete warning names
  the track, cancel keeps the file, trash / restore keep stars and PB).
* NEW device check `game/tests/android_ux_checks.gd` + `NITRO_SMOKE=uxrescue` in `tools/android_three_circuits_smoke.sh`:
  emulator, real `adb shell input swipe` on DEVELOPER starting on a button and real `KEYCODE_BACK`; signed v0.1.51 (PR #63)
  installed first with a custom track + records, then v0.1.52 installed with `adb install -r`, files byte-compared.
* NEW `tools/apk_identity.py` (CI step): APK package / versionCode / signing certificate read from the APK itself.

## NOT proven here (owner phone)

Finger feel of the scroll and fling, the Android keyboard over the RENAME / SAVE AS card on the owner's phone, readability
at arm's length, the garage swatch colours vs the car paint under the phone screen.

## Next safe action

Owner evening QA with the checklist in the PR; then #67 / #68 stable QA integration on top of this branch
(`integration/stable-mobile-qa`), Forest Lab opt-in only, one package `com.karllondor.nitrowheelz.review.pr45`.
