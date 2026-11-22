# Physics modes: ARCADE_PLUS (default) and REAL_POWER_TEST (v0.1.38, issue #25)

Owner decision 2026-11-22 (#25 c7080962400, restated in #26 c7081190249): the cars feel far too weak at speed. Keep the approved arcade
handling, lift the implausibly low top speeds per car ("C+"), and give DEVELOPER > diagnostics a real power-curve mode ("A") to test side by side
on the same car and track. Status: **CODE_READY, CI green (see the handoff), phone NOT RUN.** Targets below are **PROPOSED, not owner-approved.**

## The two modes
| | ARCADE_PLUS (default, "C+") | REAL_POWER_TEST ("A", DEVELOPER only) |
|---|---|---|
| drive force | the calibrated arcade tune (constant drive force, v0.1.36 power-to-weight law) | engine power at the current revs / speed, capped by launch traction (5.5 m/s2) |
| drag | arcade quadratic drag; **above 100.8 km/h** it grows only `drag_high_scale` times as fast, so each car ends at a per-car top speed | real drag `rho * CdA / 2m * v^2` + rolling resistance 0.012 g |
| gearbox | none | mechanical MANUAL box (estimated gear table), **the game shifts**; 0.25 s torque cut per upshift; no gear / clutch controls |
| steering, grip, drift, braking, reverse | approved arcade handling | the same (only the longitudinal force and the drag change) |
| records, stars, score | normal | **never saved** (results screen says so) |
| applies | every race | the NEXT race (set it in DEVELOPER before starting; no restart of a running race) |

`DEVELOPER > ACTIVE PHYSICS MODE` shows and switches the mode; the touch-diagnostics and telemetry overlays print `PHYSICS MODE ...` (plus gear / rpm /
power in A). The player HUD never shows it. `BASELINE PHYSICS FOR ALL CARS` (the older switch) still wins over both. Default is stored per device
(`user://nitro_dev.cfg`, `[developer] physics_mode`), RESET DEVELOPER DEFAULTS returns to ARCADE_PLUS.

## Why ARCADE_PLUS does not change the feel below 100 km/h
The model above the knee only: `drag = c*(k^2 + s*(v^2 - k^2))` for `v > k = 28 m/s (100.8 km/h)`, continuous at the knee. `s` is solved per car so that
`drive_accel - rolling = drag(top)`; `top_speed_mps` (the drive fade) is moved above the terminal speed. Below the knee the code path is the old
one: `physics_modes_test` proves a 8 s mixed drift / throttle trace is identical to the calibrated tune to 1e-9 for every car (speed kept < 90 km/h),
`car_profiles_test` keeps the old golden trace of the Lada bit-identical, and `car_performance_test` shows 0-100 km/h unchanged to 5 ms.

## Per-car numbers (C = confirmed, E = estimate, M = missing; details + sources in each profile's `real_power.provenance`)
| car | engine data | mass | ARCADE_PLUS top (proposed) | A top (limiter, estimated gearing) | power / drag limit (model) |
|---|---|---|---|---|---|
| Lada RED 13B | C 231 PS @ 8,200 rpm, 211 Nm @ 5,500 (RX-8); torque curve E | E 1,150 kg | 200 km/h | 203.9 | about 232 |
| Lada WHITE N20B20 tuned | C stock 245 PS / 350 Nm; tuned 275 PS / 410 Nm **E** (Stage 1) | E 1,150 kg | 200 km/h | 201.7 | about 245 |
| E30 M52B28 | C 193 PS @ 5,300 rpm, 280 Nm @ 3,950; curve E | E 1,250 kg | 220 km/h | 220.2 | about 231 |
| RYU-32 V8 | C owner 350 HP / 400 Nm; rpm of the peaks E | E 1,300 kg | 225 km/h | 228.0 | about 286 |

Rule used for the proposal (not a global number): **ARCADE_PLUS top = the REAL_POWER_TEST top, rounded down to 5 km/h.** The A top is the limiter speed of the top
gear (the gear table of the engine block = the sound-design table, used as the ESTIMATED gearing) because the power / drag limit lies above it for every car; so the
real gearbox + final drive decide the numbers. The E30 value agrees with the owner's own remark (about 220 km/h, not verified). To retune a car change
`arcade_plus.top_kmh` in its profile (one number); `car_performance_test` and `physics_modes_test` follow.

## Measured side by side (tests/physics_ab_audit.gd, real drive model, full-throttle straight, same cars)
| car | mode | 0-60 | 0-100 | 60-120 | 100-150 | 100-200 | top (60 s) | 100-0 brake |
|---|---|---|---|---|---|---|---|---|
| red | ARCADE_PLUS | 1.60 s | 3.29 s | 3.08 s | 4.09 s | not reached | 200.0 km/h | 18.5 m |
| red | REAL_POWER_TEST | 3.38 s | 6.08 s | 4.65 s | 5.33 s | 17.31 s | 203.9 km/h | 22.3 m |
| white | ARCADE_PLUS | 1.39 s | 2.76 s | 2.41 s | 3.05 s | not reached | 200.0 km/h | 18.5 m |
| white | REAL_POWER_TEST | 3.38 s | 5.80 s | 4.00 s | 4.52 s | 12.56 s | 201.7 km/h | 22.3 m |
| blue | ARCADE_PLUS | 1.37 s | 2.68 s | 2.24 s | 2.60 s | 7.46 s | 225.0 km/h | 20.1 m |
| blue | REAL_POWER_TEST | 3.38 s | 5.80 s | 3.74 s | 3.99 s | 10.42 s | 228.0 km/h | 24.3 m |
| e30 | ARCADE_PLUS | 1.91 s | 4.29 s | 4.75 s | 6.67 s | 20.11 s | 219.5 km/h | 18.5 m |
| e30 | REAL_POWER_TEST | 3.42 s | 6.65 s | 5.33 s | 6.77 s | 21.51 s | 220.2 km/h | 22.3 m |

(`red` = Lada 13B, `white` = Lada N20 tuned, `blue` = RYU-32 V8. "not reached": the C+ drag law approaches the terminal speed asymptotically, e.g. red 200.0 km/h after 60 s. Raw numbers: `docs/dev/handoffs/evidence/issue-25-physics-ab.json`.)

Reading: in A the launch is traction limited for every car (0-60 about 3.4 s, all cars the same) and 0-100 is 5.8-6.7 s (the credible figures of the audit's optimistic envelope);
C+ keeps the quick arcade launch (2.7-4.3 s). From 100 km/h on C+ stays quicker for the strong cars (100-150 km/h: 2.6-4.1 s against 4.0-5.3 s in A; the E30 is equal at about 6.7 s) and
both modes end at about the same top speed (by construction). The tuned N20 is clearly ahead of the 13B in both modes (A: 60-120 km/h 4.00 s against 4.65 s). Braking 100-0 is 18.5 m in C+ and
22.3 m in A: the arcade drag (kept below the knee) helps the brakes; the brake force itself is the same in both.

## High-speed handling (the arcade lateral model was tuned below about 130 km/h)
`physics_modes_test` drives every car in both modes at 150 km/h and at (top - 5): hands off = straight (0 deg drift), a lane change (+-0.5 steer, 0.5 s each) gives at most 5 deg
of drift and 0.34 rad/s of yaw, a handbrake tap slides 12-16 deg and recovers within 8 s; no NaN. **The cost is numb steering at speed**: the yaw limit is `13.5 / v` (0.29 rad/s
at 195 km/h = a 190 m radius). That is the approved handling extended, not tuned: whether 200+ km/h should turn harder is a design question for the owner (it would change the
shared lateral model, which this task does not do).

## Not done / not tested
Phone feel of either mode; turbo lag (the N20 curve is steady state); the HUD gauge still ends at 200 km/h (E30 / RYU-32 exceed it: HUD is the #28 design item); shift
indication in the HUD (none, by the owner's decision: the game shifts silently); the engine sound still follows the arcade speed-to-rpm map, not the physics rpm of A.
