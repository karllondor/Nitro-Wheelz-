# Nitro Wheelz change history

## [0.1.4] — Mobile track walls, rapid drift and portrait first straight
- Rebuilt the fictional Shin-Kawa layout with a vertically northbound starting straight, followed by a right turn (natural rightward joystick action).
- Widened racing road from 16.4 m total to 24 m total.
- Replaced decorative disconnected barrier segments and the off-road sand penalty / invisible speed clamp with continuous raised blue-and-white walls and a vehicle-width-adjusted rebound at the same visible edge.
- Wall contact consumes outward velocity, returns a mild 18% inward bounce, damps wall-skimming speed, and clears any active slide combo; strong impacts cause a short bounded camera shake and phone/controller haptic feedback.
- Enabled Android VIBRATE export permission. Haptics still require real-device testing and may be disabled by system settings.
- Made steering animation much faster and biased small analog thumb displacements toward earlier response.
- Reduced handbrake rear-grip engagement time and added a one-shot yaw flick on press (only when moving and steering; no automatic repeated spin).
- Enlarged DRIFT hit zone and rebuilt GAS/BRAKE as thicker trapezoidal pedal controls with tactile rib styling. All hit areas match their displayed controls.
- Added CI tests for start heading, straight start, collision bounce on both sides, instant DRIFT, steering responsiveness, and synthetic portrait touch geometry.
- Car visual identity, two cameras and BRAKE-to-reverse retained. **Android driving feel still requires owner playtest.**
- **Build/test status:** pending CI when authored.


## [0.1.3] — Camera framing and speed-aware steering
- Removed the user-unwanted REVERSE subtitle from the BRAKE button (braking and reversing remain functional).
- Zoomed out portrait overhead camera (52 -> 78 world units) and landscape camera (45 -> 62), widened and backed off chase camera.
- Changed top-down camera to maintain a constant world orientation while the vehicle yaws, preventing the road from visually rotating with the car.
- Bounded car yaw rate by lateral acceleration available at current speed, instead of allowing ±2.8 rad/s even around 80–100 km/h. Reduced yaw torque and increased damping to address mobile footage showing off-track overshoots and unstable corner exits.
- Added deterministic high-speed sweeper and fixed-overhead-camera orientation regressions.
- All changes preserve the approved low-poly Lada, track, controller mappings, and BRAKE reverse behavior.
- **Godot/Android/Web CI:** PENDING at authoring; physical Android driving feel NOT RUN.


## [0.1.2] — Grip recovery and BRAKE / REVERSE
- Reviewed two owner-provided real-device recordings: Nitro Wheelz chase-camera overslides compared with DRIFTIT mobile top-down.
- Rebuilt rear power grip to decline with throttle and scale with speed (36 km/h full gas: 60% loss; 72 km/h: 37% loss), rather than multiplying the same 60% loss across all speeds and the rear sliding state.
- Smoothed steering and strengthened lift-off/neutral countersteer recovery and yaw damping; slide reattaches after throttle release instead of retaining uncontrollable rotation.
- Preserved the handbrake's separate low-grip rear axle state and deterministic fixed-step integrator.
- BRAKE reduces forward speed; holding BRAKE through a stop engages capped reverse. GAS brings the car forward from reverse.
- Touch BRAKE button explicitly labels REVERSE; speedometer indicates R when backing.
- Expanded deterministic physics regression tests for braking transitions, reverse, straight-line traction, speed-dependent steering, and slide recovery.
- **CI evidence:** Foundation, Godot 4.7.2 import/smoke/numerical physics, Android ARM64 APK export, and Web export all PASS for code SHA e975440ce2e3d24ab37bb89587a94ad489645ad7. Real Android playtest NOT RUN.


## [0.1.1] — Mobile UI + low-poly Lada hotfix
- Fixed visual heading sign mismatch: Godot mesh forward (local -Z) now matches the physics heading, avoiding the car spawning sideways.
- Replaced the primitive block car with an original procedural, red low-poly four-door Lada-inspired drift sedan: wide arches, 5-spoke deep-dish wheels, chrome, round lamps, exposed intake and drift lip.
- Enlarged main menu, timer, drift score, speedometer and touch-control labels for portrait Android.
- Restyled large DRIFT, GAS, BRAKE and joystick controls with rounded translucent panels. Visible control rectangles now match the exact multitouch hit areas.
- Preserved two cameras: top-down default and optional chase; same physics for both.
- Added visual-forward/track spawn/camera/touch regression checks in Godot CI.
- Prepared separate v0.1.1 APK and Web artifact naming. No previous package is overwritten.
- **Hardware status: NOT RUN** until physical Android testing and visual inspection.

## [0.1.0] — Driving Lab (first functional source prototype)
- Imported Karll Game Starter v0.1.0 and customised project identity.
- Created original planar two-axle car dynamics based on published DRIFTIT mechanics, with fixed 120 Hz updates and 240 Hz internal substeps.
- Procedural fictional Japanese drift track Shin-Kawa, low-poly car, skid marks, score and provisional three-lap timer.
- Overhead default / chase alternate cameras, keyboard, Xbox InputMap and portrait-friendly multitouch overlay.
- Added Godot driving regression tests with a no-creep/no-turn-at-standstill brake test.
- Implemented automatic Web export artifact from GitHub Actions.
- Validated Godot import, scene startup, input map, numerical physics and Web export in CI. Real phone/pad and visual handling tests remain NOT RUN.

Public physics sources: https://driftit.app/blog/building-a-drift-game-in-threejs and https://driftit.app/guides/drifting-explained
