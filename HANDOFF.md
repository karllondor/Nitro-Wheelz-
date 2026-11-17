# Nitro Wheelz — v0.1.3 Handling + Zoom

Date: 2026-11-17. Model: GPT-6.
Development branch: agent/nitro-v0.1.3-camera-handling.

## User feedback / video evidence
Uploaded current Nitro Wheelz gameplay (1000075993.mp4, approximately 84 seconds) and DRIFTIT reference gameplay (1000075991.mp4, approximately 49 seconds). Nitro shows multiple 80–100 km/h off-road approaches and narrow camera framing; user says handling remains odd and camera is too close. DRIFTIT reference shows a wider view and more controlled transitions. User explicitly requests removal of unnecessary 'REVERSE' caption.

## Implementation
- No text 'REVERSE' on BRAKE; reversing continues to work.
- Overhead orthographic camera portrait size 78 (was 52) and landscape 62 (was 45). Fixed orientation world north-up, no rotation following yaw; chase moved further back/higher with broader field of view.
- Yaw rate now depends on 12 m/s² nominal combined arcade lateral budget divided by speed (plus small bonus during active slides); yaw torque reduced and damping increased. Calibration is intended to permit roughly 0.6 rad/s at 72 km/h, allowing ~33 m sweepers while removing the original unlimited high-speed spin rate. This is a candidate, not proof of equivalent DRIFTIT handling.
- Regression tests: 72 km/h steering sweeper, yaw rate cap, overhead fixed orientation during car yaw; prior braking, reverse, drift grip/recovery and Lada/touch tests retained.

## Validation
CI statuses not yet updated. Physical Android feel NOT RUN. These changes use original GDScript, not DRIFTIT source.
Public reference: https://driftit.app/blog/building-a-drift-game-in-threejs and https://driftit.app/guides/drifting-with-a-controller

Next: verify Godot/Android/Web checks, publish APK, have owner test identical high-speed sweeper and handbrake entry again. Check not to overcorrect into understeer.
