# Issue #65 — Android system BACK left the game (owner phone, v0.1.53) — investigation and fix in v0.1.54

```text
MODEL: Claude Opus (claude-opus-5-5) | Godot 4.7.2 | base integration/stable-mobile-qa 9c827cd (v0.1.53)
OWNER REPORT: "systemowe back wychodzi z gry" in the DEVELOPER step of the v0.1.53 checklist (docs/dev/owner-qa/v0.1.53-20261128.md)
```

## What the code and the real APK show
| Fact | Evidence |
|---|---|
| `application/config/quit_on_go_back=false` is in the exported project | v0.1.52 / v0.1.53 CI emulator: after a real `KEYCODE_BACK` the game kept running and wrote its verdict |
| The APK targets **SDK 36 (Android 16)**, minSdk 24 | binary AndroidManifest of `Nitro-Wheelz-QA_v0.1.53_code53_….apk` |
| On Android 16 with targetSdk 36 the system no longer calls `onBackPressed()` / sends `KEYCODE_BACK`; apps must use the back-dispatcher API | Android 16 behaviour change (predictive back by default) |
| Godot 4.7.2's activity registers an **androidx `OnBackPressedCallback`** (dex: `getOnBackPressedDispatcher`, `addCallback`, `onBackPressed$lambda$29`, `Invoking onMainBackPressed for plugin`) | `classes7.dex` of the v0.1.53 APK. So BACK by key, button or gesture should still reach the game as `NOTIFICATION_WM_GO_BACK_REQUEST` |
| v0.1.53 left the game on ONE BACK on the main menu (Android convention) | `boot.gd go_back()` |
| The v0.1.52/53 device check ran with menu navigation OFF, so it could not see a quit on the main menu | `android_ux_checks.gd` (`navigate_enabled=false`) |

## Most likely cause (not proven on the phone)
DEVELOPER → main menu → game closed in two BACK deliveries: either the owner pressed twice (the first press's page change is easy to miss), or one gesture reached the game twice. Either way one BACK on the main menu was enough to close the game. A system-level exit (Android 16 predictive back bypassing Godot) remains possible; the new log separates the two.

## Fix in v0.1.54
* `android_back.gd`: a BACK within 350 ms of the previous one is **ignored** (logged as a duplicate).
* `boot.gd go_back()`: on the main menu the first BACK shows **PRESS BACK AGAIN TO EXIT**; only a second BACK 0.35–2.5 s later leaves the game.
* Every system BACK, every ignored duplicate, every main-menu decision and every app pause / resume / start is written to
  `user://back_events.log` (24 lines, kept across restarts), printed as `NITRO_BACK …` for `adb logcat -s godot`, and shown on
  DEVELOPER ("SYSTEM BACK LOG"). If the game ever closes again, reopen it → DEVELOPER: a line `APP PAUSED n ms after the last BACK`
  **without** a preceding `leave the game` line means the system, not the game, closed it.

## Tests
* `android_ux_rescue_test` (headless): duplicate ignored, first main-menu BACK only asks, an instant second does not leave, a deliberate
  second leaves, a late one asks again, log recorded and shown. Mutation checks: one-BACK exit → FAIL; no debounce → FAIL.
* Emulator (`NITRO_SMOKE=uxrescue`), navigation ON for the BACK steps: real `KEYCODE_BACK` DEVELOPER → main menu; one more
  `KEYCODE_BACK` on the main menu → the app must still run (`pidof`) and show the prompt; **gesture navigation** + edge swipe on
  DEVELOPER → the app must still run. Runs on **API 35 and API 36** (Android 16, the APK's target) for the QA branch.

## Expected BACK per screen (v0.1.54)
DEVELOPER / ELEVATION / SETTINGS / PROFILE / PARK / BUILD pages → parent page (same as the on-screen BACK) · Track list → Race setup
(or the garage when opened from it) · Race setup → main menu (track selection is opened FROM race setup, so going "back" to it would loop)
· Garage → where it was opened from · open card → CANCEL · race → PAUSE / un-pause · LAN lobby and Tree Designer → their own handler
· main menu → prompt, second BACK leaves.

NOT RUN: the owner's phone. Do not close #65 until the owner confirms on the phone.
