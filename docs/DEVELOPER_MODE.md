# DEVELOPER mode (v0.1.32)

Main menu > **DEVELOPER**. Developer / test options are stored in `user://nitro_dev.cfg`, **apart from the player's
settings** (`user://nitro_settings.cfg`: volumes, accent colour, sound on/off). Builds up to v0.1.31 kept them in the
player file under `[developer]` / `[physics_dev]`; the first start of v0.1.32 moves them over and removes them from
the player file. None of these options is saved into tracks or race results.

| Option (button) | Values (default **bold**) | Effect | Where |
|---|---|---|---|
| CONTROLLER DIAGNOSTICS | screen | Live view of keyboard / gamepad / touch actions, dead zones and the logical inputs the car receives. | `scenes/dev/input_monitor.tscn` |
| BASELINE PHYSICS FOR ALL CARS | ON / **OFF** | ON: every car drives on the Lada baseline handling (the way back to the old behaviour); looks and engine sound still follow the chosen car. | `car_catalog.gd baseline_physics_forced()` |
| AUDIO DEBUG OVERLAY | ON / **OFF** | Race overlay with the synth state: engine layout, rpm, gear, load, misfires, tyre squeal, scrape, player mix. | `ui/audio_debug_overlay.gd` |
| VEGETATION WIND | **DEFAULT** (1.0) / HALF (0.5) / OFF (0.0) (tap cycles) | Issue #20: strength of the foliage sway of terrain-track vegetation (trees sway at most ~0.2 m at the crown; the roadside planting sways ~0.03 m since v0.1.34). OFF = nothing in the scenery moves, which tells a phone test wind from any other movement. Read when a terrain world is set up (reopen the track). | `terrain_scenery.gd set_wind()` |
| CAR FACTORY GLB CARS | **ON** / OFF | v0.1.34 (owner decision 2026-11-22, issue #22): ON = the Lada RED / WHITE and the RYU-32 are the Car Factory GLB models, also in the player garage and race (PAINT / WHEELS from `game/cars/car_factory_cosmetics.json`). OFF = the earlier procedural Lada / RYU-32 for comparison (E30 and the FLAME AI test car have no procedural model and stay GLB). Looks only: handling, sound, collisions, saves unchanged. Stored as `legacy_procedural_cars` (the old `factory_test_models` key is ignored). | `car_catalog.gd factory_test_models()` |
| (removed in v0.1.34) RYU-32 TEST LOOK | — | The RYU-32 stripes are now the PAINT preset "BLUE + STRIPES" in the garage (same GLB, livery on / off). | `car_cosmetics.gd` |
| ELEVATION PHYSICS ▶ GRADE FORCE | **0** / 25 / 50 / 75 / 100 % | Share of the gravity component along the road on terrain tracks (planar acceleration). 0 % = exactly the flat handling. Flat tracks never change. | `world/terrain/physics_dev.gd` |
| ELEVATION PHYSICS ▶ CAMERA PITCH | **ON** / OFF | Race cameras follow the road grade (visual). | same |
| ELEVATION PHYSICS ▶ BANKING / BODY ROLL | ON / **OFF** | Visual body roll from lateral acceleration (+ road cross-fall, 0 on level roads). | same |
| ELEVATION PHYSICS ▶ SUSPENSION (VISUAL) | ON / **OFF** | Visual heave / pitch from longitudinal acceleration. | same |
| ELEVATION PHYSICS ▶ GROUNDING | **SNAP** / SMOOTH | SNAP: car height = road height every tick; SMOOTH: damped follow (visual). | same |
| ELEVATION PHYSICS ▶ TELEMETRY OVERLAY | ON / **OFF** | Race readout of grade, pitch, roll, grounding, traction values. | `race.gd telemetry_text()` |
| TOUCH DIAGNOSTICS | ON / **OFF** | Overlay in the Track Builder and the race: every touch with its ID and **who takes it** (the top-most input-stopping control or SCENE), red outlines of all input-stopping hitboxes, the map area in green, the event order, FPS, frame / physics time, draw calls; Builder: stage, MOVE / DRAW, navigating, map rectangle, camera, last terrain generate / road-fit times, number of road fits and how many ran during a camera move (must stay 0); Race: the visual angle of each wheel vs the body (rear must read 0.0), steering, drift, speed. | `ui/touch_diagnostics.gd` |
| DRIFT LAYER ISOLATION | **OFF** / HIDE SMOKE / HIDE SKID / HIDE SHADOW / HIDE WHEELS (tap cycles) | Issue #16: hides ONE visual layer of the car in a race (tyre smoke, skid marks, contact shadow, rolling wheels) so a phone test can tell which layer draws a black shape on the first drift. Visual only; TOUCH DIAGNOSTICS prints `LAYER HIDDEN: ...` in the race. | `race.gd _apply_layer_isolation()` |
| RESET DEVELOPER DEFAULTS | action | Deletes `nitro_dev.cfg`: every option above back to its default. The player's settings stay. | `dev_settings.gd reset_defaults()` |
| EXPORT DEVELOPER PRESET | action | Writes `user://nitro_dev_preset_<date_time>.cfg` and copies the same text to the clipboard (paste it into a bug report). | `dev_settings.gd export_preset()` |
| AUDIO BENCHMARK | action | Synth cost per second of audio for the Lada I4 and the RYU-32 V8 on this device. | `boot.gd audio_benchmark()` |
| (info line) | — | Godot version and renderer of this build. | `boot.gd` |

## Proposed, NOT implemented yet

The owner's "Nitro Dev Lab" proposal — live handling sliders (steering response, front / rear grip, countersteer assist,
yaw damping, handbrake grip) with units, RESET per value and saved presets — is not in this build. The handling values
live in `game/cars/*.json` (`handling`), so such a panel can edit a developer copy of a profile without touching the
car files. Bugs (map panning, dead touch areas, wheel visuals) are fixed in code, never hidden behind sliders.
