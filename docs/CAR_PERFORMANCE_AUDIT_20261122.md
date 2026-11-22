# Car performance audit (issue #25, 2026-11-22)

Owner request: the cars feel far too weak at speed; acceleration, attainable top speed and power delivery should
reflect the real builds, without turning the game into a simulator. This audit is **analysis + measurements + a
proposal. No shared driving physics was changed** (the Lada handling stays bit-identical, `car_profiles_test`).

Reproduce: `godot --headless --path game --script res://tests/car_performance_audit.gd` (what the drive model does),
`python3 tools/perf/reference_model.py audit.json --chart ...` (a stated physical reference model). Raw data:
`docs/dev/handoffs/evidence/issue-25-game-audit.json`, chart `issue-25-accel-curves.png`.

## 1. Verdict
- The owner's feeling is right, and the cause is mechanical, not a data typo: the drive model has **no power curve and no
  real drag**. Drive acceleration is a constant (11.8 m/s2 for the Lada) at every speed and a quadratic drag with
  `drag_coeff` 0.009 is the only thing that ends the pull. That drag is about **18x** what a real saloon has
  (about 0.0005 per (m/s)^2), so every car stops accelerating at 117 - 141 km/h while the real cars keep pulling to
  230+ km/h. Below 100 km/h the game is **too strong** (launch 10 - 13 m/s2; a street-tyre RWD car is traction limited
  to about 5.5 m/s2), above 110 km/h it is **far too weak**. That is exactly "weak at speed".
- My v0.1.36 power-to-weight calibration (ADR-010) fixed the ORDER of the cars and the relative gaps, but anchored the
  Lada at the old arcade ceiling (127.8 km/h). It cannot make the numbers credible and I should not have presented it
  as "real"; it is an arcade-consistent ranking. The E30 is now at 116.9 km/h, below its real self by half.
- A single PS-per-tonne formula cannot give both acceleration and top speed (the owner's #25 comment is right):
  acceleration is power / (mass x speed) until traction ends, top speed is power against drag (aero), not mass.

## 2. What the drive model does (code)
`game/scripts/driving/drive_model.gd`:
- l.336 `longitudinal_accel = drive_accel * gas` - constant, independent of speed (no torque / power curve, no gearbox, no
  shift, no rev limiter); l.337-338 fade to zero between `top_speed_mps - 5` and `top_speed_mps` (50 m/s = 180 km/h, never
  reached: the drag stops earlier).
- l.343 `rolling_drag` 0.45 m/s2 constant; l.349 `acceleration -= velocity * speed * drag_coeff` - quadratic drag,
  `drag_coeff` 0.009 (Lada), 0.0085 (RYU-32), 0.00915 (E30 since v0.1.36).
- `slide_drive_factor` 0.76-0.95 reduces drive while sliding, `power_loss_*` models rear grip lost by throttle (drift
  entry), `brake_accel` 15.6-17.
- Terminal speed = where `drive_accel - rolling - drag_coeff v^2 = 0`: Lada 127.8, RYU 140.5, E30 116.9 km/h.
- The handling constants (grip, yaw, steering lock at speed, `power_loss_per_mps`) are tuned for the **drift envelope
  (about 30 - 90 km/h)** and are what the owner approved; nothing above about 130 km/h has ever been tuned or tested.

## 3. Game vs a reference physical model
Reference model (`tools/perf/reference_model.py`, all inputs below are stated): wheel power = 0.85 x engine, traction cap
5.5 m/s2, `a(v) = min(a_traction, P_w / (m v)) - rho Cd A v^2 / 2m - Crr g`, **no gearbox / shift / torque curve / boost**
(an optimistic envelope: real 0-100 is typically 0.5 - 1.5 s slower, real top speed is often gearing- or limiter-limited).

| car | game 0-100 | model 0-100 | game top | model top (power / drag) | game a(100) | model a(100) | game a(120) | model a(120) |
|---|---|---|---|---|---|---|---|---|
| Lada RED 13B (231 PS, 1,150 kg est.) | 3.29 s | 5.39 s | 127.8 km/h | 231.6 km/h | 4.4 m/s2 | 4.1 m/s2 | 1.4 m/s2 | 3.2 m/s2 |
| Lada WHITE N20B20 (245 PS, mass missing) | 3.29 s (still the 13B profile) | 5.31 s | 127.8 km/h | 236.5 km/h | 4.4 m/s2 | 4.5 m/s2 | 1.4 m/s2 | 3.5 m/s2 |
| E30 M52B28 (193 PS, 1,250 kg est.) | 4.29 s | 5.87 s | 116.9 km/h | 231.2 km/h | 2.6 m/s2 | 3.1 m/s2 | -0.5 m/s2 | 2.4 m/s2 |
| RYU-32 V8 (355 PS, 1,300 kg est.) | 2.68 s | 5.24 s | 140.5 km/h | 285.6 km/h | 6.4 m/s2 | 5.1 m/s2 | 3.5 m/s2 | 4.6 m/s2 |

Reading: at 100 km/h the game is close to the reference (4.4 vs 4.1 m/s2 for the Lada) - the 0-100 "too fast" is all in
the first 60 km/h; from 110 km/h on the game collapses (1.4 vs 3.2 m/s2 at 120). The 285 km/h of the RYU model is the
unlimited power / drag figure (a real car is limited by gearing or a limiter: unknown build data).
Published references (web search 2026-11-22): RX-8 231 PS 13B-MSP 0-100 about 6.4 s at 1,380 - 1,390 kg (the model gives 5.7 s for 231 PS / 1,385 kg: optimistic by about 0.7 s, as stated, no gears); VAZ-2106 stock 75 PS / 1,035 kg 0-100 16 - 17.5 s, about 150 km/h. The owner's R6 hypothesis
(about 220 km/h) is **plausible for the E30 M52B28** (the model's power / drag top is about 230 km/h; a 5-speed final
drive or a limiter usually sets 220 - 235): NOT verified, build specific, not adopted as a target.

## 4. Constraints that make "just make it real" wrong
- The circuits are small (Oval 270 m, Shin-Kawa 1,096 m): at 230 km/h a car crosses the Oval in 4 s; the camera lens, the
  gauge (200 km/h), wall contact and the drift model are tuned for 130 km/h. Only the open routes (Touge, terrain) and
  the Park can use speed above about 150 km/h, and the Park is deliberately a slow starter surface.
- Drift feel must not move (golden trace). So the right target is "**credible numbers where the player can see them**":
  launch 0-100 (traction limited, slower than now), mid-range pull 60 - 140 km/h (now far too weak), and an honest top
  speed on open roads - while the drift envelope below about 90 km/h stays as approved.

## 5. Proposal (not implemented, needs the owner's decision and a scoped branch)
**A. REAL POWER CURVE (feature flag, default OFF).** Replace the constant drive force by
`a_drive(v) = min(a_launch, P_wheel / (m v)) x slide factors` and the exaggerated drag by `rho Cd A / 2m` per car, in the
same drive model, selected by a profile block `"drivetrain": {"power_kw", "mass_kg", "cda", "eta", "a_launch", "top_limit_kmh"}`.
With the flag OFF every number is bit-identical (golden trace). With it ON: Lada 13B about 5.4 s / 200+ km/h, E30 5.9 /
220+, RYU 5.2 / 250+ (model figures, gears will add ~1 s). Needs: handling check above 130 km/h (steer lock, yaw budget,
`power_loss_per_mps`), the camera / gauge range, a regression test table per car (0-100, 100-150, top, +-10 % of the documented
targets) and a phone A/B (DEVELOPER switch). Cost: small (one function), risk: drift feel at high speed.
**B. Compressed credible ("arcade ceiling").** Keep today's launch strength, raise the drag ceiling so the strongest car
reaches about 180 km/h and the order follows power: closest to the old feel, least credible. **C. Add a gearbox simulation**
(shift time, rev limiter, gear-limited top speed): the most "real power delivery", the most work; only after A.
Recommendation: **A, flagged, then tune**; C later if the owner wants shifting to be felt.

## 6. Per-car checklist (C = confirmed, E = estimate with the named basis, M = missing build data)
| item | Lada RED 13B | Lada WHITE N20B20 | E30 Blessed | RYU-32 |
|---|---|---|---|---|
| identity / variant | C Lada 2106, Nightride build (owner text quoting the videos; web search found no page: unverified) | C approved BMW N20B20 swap (owner); reference build M | C 4-door E30, M52B28 swap (creator video, SRC01/02) | C owner reference: 4.0 V8 ITB; which V8 / which donor M |
| engine layout | C 13B-MSP two-rotor (RX-8) | C inline-4 2.0 turbo | C inline-6 2.8 NA | C V8 4.0, ITB |
| power / torque | C 231 PS series output of the donor engine; torque / rpm curve M; build gain (bridgeport, ITB, exhaust) M | C stock 245 PS / 350 Nm (328i); tune / boost M | C factory ref 193 PS / 280 Nm (not dyno) | C owner 350 HP / 400 Nm; curve M |
| redline / limiter | E 9,200 (sound design); real M | M | E 6,500 (research tuning start) | E 7,000 (sound design); M |
| mass (race ready) | E 1,150 kg (1,035 shell + swap + cage); M | M (placeholder 1,100) | E 1,250 kg (research tuning start) | E 1,300 kg; M |
| drivetrain, diff | RWD; diff M | RWD; diff M | RWD; diff M (assume near-locked) | RWD; diff M |
| gearbox + final drive | M (the build needed a bigger box than stock) | M (8HP auto or manual?) | M | M |
| tyres / wheel radius | E visual (0.58 m tyre diameter on the E30 model); sizes M | M | E 0.58 m diameter (photos) | M |
| aero (Cd x A) | E 0.45 - 0.50 x 1.9 m2 | E same body | E 0.36 - 0.38 x 1.9 m2 | E 0.36 - 0.40 x 1.85 m2 |
| benchmarks | C platform: RX-8 0-100 6.4 s; build M | M | E public figures for a 193 PS E36 328i about 7 s (not looked up here) | M |
| top speed (real) | M (power / drag model ~230; gearing M) | M | M (model ~230; the owner mentions ~220) | M |

## 7. Questions for the owner (one packet, answer once; "unknown" is a valid answer - I then use the class-typical
estimate and keep it marked E)
- **#25.Q3 [DECISION]** direction: A (real power curve, flagged, recommended) / B (arcade ceiling) / keep as is.
- **#25.Q4 [DATA]** per car, only what you know: mass of the build, gearbox + final drive, diff, tyre size, redline /
  limiter, any measured speed (GPS / video / dyno). Most valuable first: **mass, gearbox + final drive, tyre size, the top
  speed you want to feel** (for the white Lada also: manual or automatic, stock or tuned).
- No public factory spec is asked from the owner (RX-8, 328i, E36, VAZ-2106 are looked up above).

## 8. Not done / untested
No phone test of anything here; the proposal is not implemented; sound of the rotary / future turbo is not part of this
audit; the white Lada engine split (approved in #25) is NOT implemented yet: it needs the decision above first (its
acceleration is defined by the new model) and the missing mass / gearbox data. Run on this container only: Godot 4.7.2
headless, Python 3 stdlib + Pillow.
