# Nitro Wheelz — v0.1.7 candidate QA (pending mobile acceptance)
Date 2026-11-18. Model GPT-6. Branch agent/nitro-v0.1.7-benchmarks-hud.

| Test | Evidence | State |
| --- | --- | --- |
| Original Shin-Kawa regression and negative geometry controls | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44360209917 | PASS |
| New benchmark Oval 271m / Sweepers 295m compiler, geometry and centreline contacts | same Godot run | PASS |
| Steering, handbrake multitouch, Lada, lap/camera numeric tests | same Godot run | PASS |
| SemVer and protected-asset integrity | https://github.com/karllondor/Nitro-Wheelz-/actions/runs/44360209889 | PASS |
| v0.1.7 Android / Web / Desktop exports | PR workflow pending | NOT RUN |
| Native phone HUD screenshot | no device run | NOT RUN |
| Human 3 laps on each benchmark | no device run | NOT RUN |
| Speed perception both cameras vs DRIFTIT | no matched recording | NOT RUN |
| P3 LINE / ZONES / ANGLE / COMBO & P4 checkpoint-safe race | not implemented | NOT RUN |

Comparison tracks are **not identical copies** of DRIFTIT; user must supply in-game video and route overlay for further geometric calibration. Scores/stars should not be interpreted as production competitive results.
