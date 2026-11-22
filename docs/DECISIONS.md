# Architecture decisions

ADR-001: First released starter is 0.1.0.
ADR-002: Engine-neutral production rules, Godot 4.7.2 minimal adapter; other engines opt-in.
ADR-003: Xbox pad + keyboard support by default; touch required when Android is targeted; real hardware evidence required.
ADR-004: Asset registration is canonical JSON and append-only against protected base.
ADR-005: Work is branched, reversible, and scoped; no auto pushes/merges.
ADR-006: Release packaging is immutable with SemVer and build stamping.
ADR-007: Mechanics first, no mandatory genre framework.
ADR-008: CI/agent guardrails are defense in depth, not a substitute for branch protection.
ADR-009 (2026-11-22, owner decision in chat, issue #22): the Car Factory GLB models are the DEFAULT player-visible models of Lada RED / WHITE and RYU-32 (E30 and the AI test body are GLB already). The earlier procedural models stay under DEVELOPER > CAR FACTORY GLB CARS: OFF for comparison. Looks only: handling, sound, collisions and saves are unchanged. The owner's visual review of the final look continues (the models are not release-final).
ADR-010 (2026-11-22, owner decision in chat, issue #25): car performance is CALIBRATED BY THE REAL POWER-TO-WEIGHT RATIO. Anchor = the red / white Lada 2106 with its Mazda 13B-MSP Renesis rotary (231 PS, build mass estimated 1,150 kg = 201 PS/t): the approved drive model (0-100 km/h 3.29 s, 127.8 km/h, lada_baseline handling bit-identical) stays. Others follow 0-100 ~ 1/(PS per tonne) and top speed ~ (PS per tonne)^(1/3); every profile lists power and mass (facts vs estimates named). First result: the E30 (154 PS/t) became slower (4.29 s, 116.9 km/h). DEVELOPER > BASELINE PHYSICS FOR ALL CARS gives the old equal-performance behaviour. Powers and masses are published data or labelled estimates, not dyno / scale data of the builds.
