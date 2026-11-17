# Physics reference and independent implementation

## Publicly documented DRIFTIT reference (2026-09-30 and 2026-10-03)
- https://driftit.app/blog/building-a-drift-game-in-threejs
- https://driftit.app/guides/drifting-explained

Developer describes a deterministic planar vehicle, two virtual contact patches, separation of longitudinal/lateral motion, axle lateral force caps, rear traction hysteresis, power oversteer, sliding handbrake, countersteer assistance and 120 Hz physics with 240 Hz substeps. They report nominal 5.6 m/s² front and 6.4 m/s² rear lateral grip, rear grip sliding at 62% of normal, full handbrake at 10%, rear reattachment ~0.45 seconds, full throttle stealing up to 60% of rear lateral traction and 82% assisted countersteer. Drift counted above 10 degrees / 4 m/s.

## Nitro Wheelz
File: game/scripts/driving/drive_model.gd.
This is an **original GDScript implementation** developed from publicly stated equations/engineering descriptions, not copied DRIFTIT source. Exact final driving feel is **not yet verified** against game recordings; constants are initial targets and integration details differ.

State: position m, velocity m/s, heading rad, yaw rate rad/s, rear_traction, slide_hold and drift angle. Each fixed engine tick advances two 1/240 s substeps. Front and rear lateral acceleration are separately saturated; rear traction changes with brake, gas and slip. Car yaw comes from axle force difference, never visual rotation trickery. Score uses drift angle/speed (game-specific interpretation).

## Validation
Tests: game/tests/driving_test.gd; runs alongside import and smoke in tools/run_godot_checks.sh.
Subsequent tuning must compare:
- accelerate from rest / stop straight
- corner on grip, then handbrake flick
- maintain a 10–40° slide via throttle
- release gas and regain grip without snap
- change direction through an S-bend
- remain stable across screen refresh rates
- keyboard, Xbox analog trigger, multitouch drive same dynamics
- off-track reset, barrier interaction, anti-cheat laps

Limitations: two-axle planar motion does not yet model real 3D banking/grade/load transfer. Avoid claiming simulation equivalence, physical realism or author endorsement.

