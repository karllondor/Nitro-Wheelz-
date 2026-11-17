# Nitro Wheelz v0.1.4 — Mobile gameplay feedback iteration

Model: GPT-6. Date: 2026-11-17.
Branch: agent/nitro-v0.1.4-controls-walls.
User footage: /mnt/data/1000076007.mp4 (Nitro Wheelz 55.9 s), /mnt/data/1000076008.mp4 (DRIFTIT 30.7 s). These are source footage, not the new build.
Previous first race recorded off-road travel, unstable steering, thin/thumby pedal controls, and different camera-aligned start. DRIFTIT comparison shows larger road space and easier deliberate drifting.

## Changes
- Redesigned loop so spawn heading follows screen-up on portrait top-down camera, with a first right turn after a long straight.
- Track half-width increased 8.2 -> 12.0 world units; wall collision corrected to coincide with a continuous visible raised blue/white perimeter (car clearance 1.18 m).
- Wall bounce removes outward momentum, applies a restrained inward return, friction, and optional 100 ms haptic (VIBRATE permission) plus short camera shake. Contact does not allow entering the sand.
- Joystick uses an analog response exponent 0.74 for short moves; steering rate rises to 18 rad/s and release recovery to 23 rad/s. Handbrake press releases rear grip in around 8 ms and triggers one short non-repeating yaw flick while steering.
- Gas and brake have enlarged trapezoidal pedal face, deep controls; DRIFT larger.
- Godot regression tests: straight northbound spawn, wall both-sides rebound, close-range portrait control geometry, immediate handbrake response, existing reverse/steering/physics/camera tests.

## Constraints
This is an original Godot physics model informed by public DRIFTIT principles, NOT a copy of its source. Real-device steering feel, collision haptics and real-world phone FPS need manual playtest. Track layout fictional. Revisit if first turn is too far or narrow despite the road width increase.

## Build
v0.1.4 Android ARM64 debug and Web; generated APKs use ephemeral CI signing keys, so previous install may need uninstall (with data loss) before installing.
CI status not yet run when authored. Evidence links added after checks.
