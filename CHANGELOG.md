# Nitro Wheelz change history

## [0.1.1] — Mobile UI + low-poly Lada hotfix
- Fixed visual heading sign mismatch: Godot mesh forward (local -Z) now matches the physics heading, avoiding the car spawning sideways.
- Replaced the primitive block car with an original procedural, red low-poly four-door Lada-inspired drift sedan: wide arches, 5-spoke deep-dish wheels, chrome, round lamps, exposed intake and drift lip.
- Enlarged main menu, timer, drift score, speedometer and touch-control labels for portrait Android.
- Restyled large DRIFT, GAS, BRAKE and joystick controls with rounded translucent panels. Visible control rectangles now match the exact multitouch hit areas.
- Preserved two cameras: top-down default and optional chase; same physics for both.
- Added visual-forward/track spawn/camera/touch regression checks in Godot CI.
- Prepared separate v0.1.1 APK and Web artifact naming. No previous package is overwritten.
- **Hardware status: NOT RUN** until physical Android testing and visual inspection.

## [0.1.0] — Driving Lab (first functional source prototype)
- Imported Karll Game Starter v0.1.0 and customised project identity.
- Created original planar two-axle car dynamics based on published DRIFTIT mechanics, with fixed 120 Hz updates and 240 Hz internal substeps.
- Procedural fictional Japanese drift track Shin-Kawa, low-poly car, skid marks, score and provisional three-lap timer.
- Overhead default / chase alternate cameras, keyboard, Xbox InputMap and portrait-friendly multitouch overlay.
- Added Godot driving regression tests with a no-creep/no-turn-at-standstill brake test.
- Implemented automatic Web export artifact from GitHub Actions.
- Validated Godot import, scene startup, input map, numerical physics and Web export in CI. Real phone/pad and visual handling tests remain NOT RUN.

Public physics sources: https://driftit.app/blog/building-a-drift-game-in-threejs and https://driftit.app/guides/drifting-explained
