# DEVELOPER mode (v0.1.32; updated for 0.1.32b candidate)

Main menu > **DEVELOPER**. Developer / test options are stored in `user://nitro_dev.cfg`, **apart from the player's
settings** (`user://nitro_settings.cfg`: volumes, accent colour, sound on/off). Builds up to v0.1.31 kept them in the
player file under `[developer]` / `[physics_dev]`; the first start of v0.1.32 moves them over and removes them from
the player file. None of these options is saved into tracks or race results.

| Option (button) | Values (default **bold**) | Effect | Where |
|---|---|---|---|
| CONTROLLER DIAGNOSTICS | screen | Live view of keyboard / gamepad / touch actions, dead zones and the logical inputs the car receives. | `scenes/dev/input_monitor.tscn` |
| BASELINE PHYSICS FOR ALL CARS | ON / **OFF** | ON: every car drives on the Lada baseline handling (the way back to the old behaviour); looks and engine sound still follow the chosen car. | `car_catalog.gd baseline_physics_forced()` |
| AUDIO DEBUG OVERLAY | ON / **OFF** | Race overlay with the synth state: engine layout, rpm, gear, load, misfires, tyre squeal, scrape, player mix. | `ui/audio_debug_overlay.gd` |
| CAR FACTORY GLB CARS | **ON** / OFF | ON: Lada RED / WHITE and RYU-32 use their Car Factory GLB models by default. OFF: temporary legacy procedural comparison (appearance only, handling and saves unchanged). Obsolete saved factory_test_models switch is ignored. | `car_catalog.gd factory_test_models()` |
| ELEVATION PHYSICS ▶ GRADE FORCE | **0** / 25 / 50 / 75 / 100 % | Share of the gravity component along the road on terrain tracks (planar acceleration). 0 % = exactly the flat handling. Flat tracks never change. | `world/terrain/physics_dev.gd` |
| ELEVATION PHYSICS ▶ CAMERA PITCH | **ON** / OFF | Race cameras follow the road grade (visual). | same |
| ELEVATION PHYSICS ▶ BANKING / BODY ROLL | ON / **OFF** | Visual body roll from lateral acceleration (+ road cross-fall, 0 on level roads). | same |
| ELEVATION PHYSICS ▶ SUSPENSION (VISUAL) | ON / **OFF** | Visual heave / pitch from longitudinal acceleration. | same |
| ELEVATION PHYSICS ▶ GROUNDING | **SNAP** / SMOOTH | SNAP: car height = road height every tick; SMOOTH: damped follow (visual). | same |
| ELEVATION PHYSICS ▶ TELEMETRY OVERLAY | ON / **OFF** | Race readout of grade, pitch, roll, grounding, traction values. | `race.gd telemetry_text()` |
| TOUCH DIAGNOSTICS | ON / **OFF** | Overlay in the Track Builder and the race: every touch with its ID and **who takes it** (the top-most input-stopping control or SCENE), red outlines of all input-stopping hitboxes, the map area in green, the event order, FPS, frame / physics time, draw calls; Builder: stage, MOVE / DRAW, navigating, map rectangle, camera, last terrain generate / road-fit times, number of road fits and how many ran during a camera move (must stay 0); Race: the visual angle of each wheel vs the body (rear must read 0.0), steering, drift, speed. | `ui/touch_diagnostics.gd` |
| RESET DEVELOPER DEFAULTS | action | Deletes `nitro_dev.cfg`: every option above back to its default. The player's settings stay. | `dev_settings.gd reset_defaults()` |
| EXPORT DEVELOPER PRESET | action | Writes `user://nitro_dev_preset_<date_time>.cfg` and copies the same text to the clipboard (paste it into a bug report). | `dev_settings.gd export_preset()` |
| AUDIO BENCHMARK | action | Synth cost per second of audio for the Lada I4 and the RYU-32 V8 on this device. | `boot.gd audio_benchmark()` |
| (info line) | — | Godot version and renderer of this build. | `boot.gd` |

## Proposed, NOT implemented yet

The owner's "Nitro Dev Lab" proposal — live handling sliders (steering response, front / rear grip, countersteer assist,
yaw damping, handbrake grip) with units, RESET per value and saved presets — is not in this build. The handling values
live in `game/cars/*.json` (`handling`), so such a panel can edit a developer copy of a profile without touching the
car files. Bugs (map panning, dead touch areas, wheel visuals) are fixed in code, never hidden behind sliders.

RYU-32 CLEAN / BLUE + STRIPES are now selectable directly from GARAGE > PAINT; the provisional stripes do not require Developer Mode.
