# Android start screen (issue #25.Q2, v0.1.38)

Owner report (recording of v0.1.37 on an Android phone, #25 c7080732329): after tapping the launcher icon a **large square NW-crown icon**
appears for about 0-4 s, before the approved full-screen artwork. Status: **CODE_READY, phone NOT RUN.**

## Root cause (verified in the engine source and in the v0.1.37 APK)
Android 12+ draws its OWN start window ("system splash": one icon on one colour) before the app's first frame; it is not the Godot boot splash.
In Godot 4.7.2 (`platform/android/export/export_plugin.cpp`, `load_icon_refs()`): *"Splash icon: user selection -> adaptive foreground icon"*.
The repo never set `splash_screen/icon`, so the start-window icon was the adaptive **foreground** icon. In the v0.1.37 APK
`res/drawable/splash_icon.webp` and `res/mipmap/icon_foreground.webp` have the same SHA-1 (`a4221cc128...`): 432 x 432, the NW crown badge.
The start-window background is `@mipmap/icon_background` (flat `#06000E`).

## The change (one export option, no Gradle, nothing else touched)
`game/export_presets.cfg`: `splash_screen/icon="res://assets/brand/android_splash_icon.png"`, a fully transparent 432 x 432 PNG
(new file). The OS start window is now only the flat dark background colour; no icon is drawn.
Not touched (byte-identical to v0.1.37, checked by `tests/android_start_test.gd`): the launcher icon (`app_icon_192.png`, adaptive
foreground / background layers, `app_icon.png`), the approved boot artwork (`boot_splash.png`), the in-game loading art, the Godot boot splash
settings, `gradle_build/use_gradle_build=false`. The in-game loading **progress bar stays** (#28 c7080848490): it is not part of this change.

## Expected start sequence (design, NOT measured on a phone)
1. Tap the NW launcher icon -> OS start window: flat dark `#06000E`, no icon (as long as the process and the engine need to produce a first frame).
2. Godot boot splash: the approved full-screen artwork (`boot_splash.png`, minimum 800 ms) as early as the engine can draw it.
3. Loading screen with its progress bar (unchanged) -> menu.

## Platform limits (cannot be removed)
- Android 12+ never allows a full-bleed picture in the system start window: it is an icon (masked to a circle) on a colour. Only step 2 can show
  the artwork. The time of step 1 is the cold-start time of the process (APK 52 MB, GL Compatibility): unmeasured here.
- Some OEM skins (e.g. Xiaomi, Samsung One UI) may draw their own app-icon start window regardless of the app theme: not controllable, not testable here.
- On Android 13+ with "themed icons" the launcher may use the monochrome layer; the project sets none (the template's blank default is shipped): not changed here.
- Options considered and NOT taken: a custom Gradle project / theme (same constraints, much bigger change); `splash_screen/disable_godot_boot_splash`
  (would keep the OS window up until the game has started, i.e. delay the artwork); a branding image (extra element on the start window).

## How to check on the phone (owner QA)
Cold start (swipe the app away, tap the icon, film 0-5 s) and warm start (home button, tap the icon again): PASS = no NW icon at any moment,
the artwork follows the dark screen. Compare with the v0.1.37 recording. How to revert: delete the `splash_screen/icon` line.
