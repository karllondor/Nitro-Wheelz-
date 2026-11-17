# Nitro Wheelz change history

## [0.1.0] — Driving Lab (first functional source prototype)
- Imported Karll Game Starter v0.1.0 and customised project identity.
- Created original planar two-axle car dynamics based on published DRIFTIT mechanics, with fixed 120 Hz updates and 240 Hz internal substeps.
- Procedural fictional Japanese drift track Shin-Kawa, low-poly car, skid marks, score and provisional three-lap timer.
- Overhead default / chase alternate cameras, keyboard, Xbox InputMap and portrait-friendly multitouch overlay.
- Added Godot driving regression tests with a no-creep/no-turn-at-standstill brake test.
- Implemented automatic Web export artifact from GitHub Actions.
- Validated Godot import, scene startup, input map, numerical physics and Web export in CI. Real phone/pad and visual handling tests remain NOT RUN.

Public physics sources: https://driftit.app/blog/building-a-drift-game-in-threejs and https://driftit.app/guides/drifting-explained
