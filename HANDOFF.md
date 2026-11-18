# Nitro Wheelz — v0.1.6 Track DNA P0 + dynamic camera P1

Model: GPT-6. Date: 2026-11-18.
Branch: agent/nitro-v0.1.6-dynamic-camera.
Previous P0 merged main commit b5c513f159c480897d1a07f018d2c8cd31815663.

P0: validated deterministic Shin-Kawa v2 spline JSON and matching road/barrier geometry. Godot, Foundation, Web and Android CI passed before merge.

P1 changes:
- Zoom equivalents: speed 0–20: 1.15; 50: 1.00; 90: 0.82; 120+: 0.72. Camera3D orthographic size is base_size divided by equivalent Camera2D zoom.
- Physics velocity-based 0.45 s lookahead, clamp 19 m, damp camera positional/zoom transitions.
- Fixed world top-down orientation and elevated chase with greater pitch, raycast wall obstruction in _physics_process ONLY.
- Added numerical camera regression.
- Added Linux and Windows native desktop export and separate GitHub workflow.

Remaining brief work: P2 responsive physics mobile test, P3 drift line/zone/angle/combo scoring, P4 checkpoints/score progression, P5 new approved UI, P6 effects and P7 human-driven three laps. None implemented/tested by this phase. Android / PC gameplay, frame rates, wall-side camera visuals and phone Xbox testing NOT RUN.
Workflow evidence links: pending.
