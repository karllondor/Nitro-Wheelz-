# Car profiles (v0.1.19, engine keys v0.1.21)

Every car points at one profile file in `game/cars/`. A profile has two blocks:

- `handling`: numbers for the shared drive model (`scripts/driving/drive_model.gd`). Any key from `NitroDriveModel.TUNABLE` may be set; missing keys keep the baseline. No driving code changes per car.
- `engine`: the procedural engine sound (`scripts/audio/engine_synth.gd`): layout, cylinders, firing pattern, revs, gearing, exhaust geometry, resonances, combustion variability, mechanical noise and loudness (no recorded sound effects since v0.1.21).

Paint variants of one car share one profile (Lada red + white -> `lada_baseline.json`). Car Factory cars (v0.1.24, `e30_blessed.json`) add a `model` block (GLB path, wheel radius, cosmetic camber, shadow size) and a `cosmetics` block (immutable `signature` preset, paint presets, wheel ids); cosmetics are stored per car in the garage file and never read by the drive model. Facts vs estimates vs untested tuning are recorded in `provenance`, `handling_notes` and `engine_notes`. Profiles are plain JSON inside the export (`include_filter="*.json"`), a few hundred bytes each.

## Rules
- `lada_baseline.json` is the benchmark. Its handling values equal the v0.1.12+ tune and `car_profiles_test.gd` proves the physics trace is bit-identical to the pre-profile code and that its engine block equals the synth defaults (engine-sound fingerprint, re-recorded once for the v0.1.21 engine model). Do not edit it to tune other cars.
- DEVELOPER > BASELINE PHYSICS FOR ALL CARS puts every car back on the Lada physics (sound and looks stay per car).
- DEVELOPER > AUDIO BENCHMARK reports the synth CPU cost per engine on the device it runs on (use it on Android and Web).

## Handling keys (baseline value -> effect)
| key | Lada | effect |
|---|---|---|
| front_grip / rear_grip | 6.15 / 5.95 | tyre grip front / rear |
| rear_slide_grip | 0.60 | rear grip while sliding (holding angle) |
| handbrake_grip | 0.10 | rear grip with handbrake |
| reattach_seconds | 0.45 | time for the rear to regrip |
| countersteer_assist | 0.66 | automatic countersteer help |
| wheelbase | 2.424 | stability vs agility |
| drive_accel | 11.8 | power |
| top_speed_mps / drag_coeff / rolling_drag | 50 / 0.009 / 0.45 | top speed (drag-limited around 128 km/h on the Lada) |
| brake_accel | 17.0 | braking |
| yaw_torque_gain / yaw_damping | 0.522 / 1.22 | how eagerly the car rotates / how fast rotation settles (mass, inertia) |
| yaw_lateral_budget / slide_yaw_bonus | 13.5 / 2.4 | rotation limit at speed |
| steer_lock_rest/mid/high_deg | 35.5 / 22 / 8.5 | steering lock (angle kit) |
| power_loss_base / per_mps / max | 0.83 / 0.023 / 0.60 | how much throttle breaks rear grip (throttle steering) |
| flick_yaw_impulse / power_entry_kick | 0.56 / 0.252 | handbrake flick and power-entry rotation |
| slide_drive_factor | 0.76 | drive force kept while sliding |
| engine_brake_decel | 0.0 | extra decel on lift-off (engine braking) |

## RYU-32 V8 (owner's reference: 4.0 V8, individual throttle bodies, ~350 HP / 400 Nm)
Measured on identical scripted tests (`car_profiles_test.gd`, printed every run):

| metric | Lada | RYU-32 |
|---|---|---|
| 0-100 km/h | 3.29 s | 2.68 s |
| top speed | 127.8 km/h | 140.5 km/h |
| braking 100-0 | 18.5 m | 20.1 m |
| drift entry (time to 25 deg) | 1.10 s | 1.47 s |
| held drift, scripted driver | 30.0 deg +/- 17.3 @ 67 km/h | 31.0 deg +/- 2.8 @ 73 km/h |
| corner exit, speed gained in 2 s | +6.9 km/h | +20.6 km/h |
| lift-off: time to < 5 deg / speed lost | 1.30 s / 30.7 km/h | 1.29 s / 35.8 km/h |

Sound: V8 firing 4x per crank turn, two exhaust banks in the 1UZ firing order with a longer run from one bank (cross-plane burble), 760 rpm idle, 7000 rpm limiter, deeper exhaust resonances, louder ITB intake, quieter valvetrain than the Lada's chain-driven four.

## Engine keys (v0.1.21 sound model; Lada value / RYU-32 value)
| key | Lada | RYU-32 | effect |
|---|---|---|---|
| bank | [0,0,0,0] | [0,1,1,0,1,0,0,1] | exhaust bank of each firing slot (in firing order) |
| header_m | [0.95] | [0.62, 0.80] | header length per bank (m) -> header pipe modes |
| bank_lag_m | 0 | 0.5 | extra pipe run of bank 1 to the collector (m): uneven pulse arrival = burble |
| tail_m | 3.0 | 3.6 | collector to tail-pipe exit (m) -> tail pipe modes |
| header_reflect / tail_reflect | -0.32 / 0.34 | -0.34 / 0.32 | loop gain of the pipe reflections (strength of the pipe colour) |
| pipe_damp_hz | 1000 | 900 | loss per round trip (lower = darker pipe ring) |
| jet | 1.0 | 0.6 | turbulent jet noise at the pipe exit (the "rasp" under load) |
| jitter_idle / jitter_high | 0.016 / 0.005 | 0.010 / 0.004 | combustion timing scatter (fraction of a firing interval) |
| wander | 0.010 | 0.007 | crank speed wander at idle |
| misfire | 0.10 | 0.08 | lean-misfire probability on a closed throttle (decel burble) |
| mech / mech_hz | 1.0 / 2900 | 0.45 / 3400 | valvetrain / timing-chain tick level and pitch |
| room | 0.20 | 0.20 | stereo early reflections |
| loudness | 1.0 | 1.2 | overall level |
