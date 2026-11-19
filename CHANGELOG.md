## [0.1.11] — Brand, one modal per action, Undo, asphalt/sand textures
- Logo vector trace from user image (white NITRO, purple WHEELZ, yellow crown) at top of menu and editor; dark/purple/gold themed controls.
- New exclusive PAUSE CanvasLayer with RESUME, RESTART, GARAGE; old HUD/touch overlapping PAUSED/RESTART popups removed. FINISHED stays separate.
- Local results display concise day/month and HH:MM; underlying ISO timestamps remain untouched.
- Editor supports 48-step undo for drag, new, add/remove and reset; custom responsive overlay panels replace tiny native dialogs and keep keyboard field high on phone.
- Road UV world-coordinate tiling with source-derived compressed textures: supplied asphalt and sand assets stored in repository, exterior ground and shoulder use sand.
- ~10% yaw torque/power kick softening vs 0.1.10; handbrake grip remains immediate.
- Version 0.1.11, Android code 11 and unique platform artifact names. Automated suite added brand/pause/texture/headless UI checks; handset results NOT RUN.
- Model: GPT-6. Based on feedback files Screenshot_2026-11-19-01-25-52-822_com.karllondor.nitrowheelz.jpg, 1000076369.png, 1000076169.png, 1000076170.png and 1000076371.mp4.

## [0.1.10] — Handling rebalance and usable track editing
- Rebalance original driving model between overly stable v0.1.8 and involuntary sliding v0.1.9. Restore yaw damping, rear grip and countersteer support; power oversteer requires actual slip, except deliberately extreme low-speed donut inputs. Preserve instant rear lock on handbrake.
- Editing: Start New → Circle / Blank Canvas; tap-to-place knots, zoom ± and desktop wheel; name the track when saving; separate local JSON files for each name, reopen last saved valid project.
- Edited knots use orange active highlighting; red invalid node pairs are mapped to compiler sample/ring indexes. Global errors remain text-only.
- Regression suite adds new circle/blank editing, zoom, red error knots, naming and moderate GAS steering/recovery checks.
- All platform build numbers and Android versionCode set to 0.1.10 / 10. Human handset driving approval and phone dialog layout still NOT RUN.
- Comparison clips: 1000076248.mp4 (driving), 1000076249.mp4 (track editing). Engine Godot 4.7.2, model GPT-6.

## [0.1.9] — Actual Track Editor, result board and dynamic drift retune
- New **EDIT TRACK • BETA** separate from procedural Generate Track. Drag/Add/Delete spline control points, validate closed road and shared collision, save custom loop to user:// and play; fail-closed on invalid data.
- Result scene replaces the FINISHED popup and stacked Restart/Garage UI. Local-only history and best times stored separately per track. Display time, score and provisional stars. No online leaderboard.
- Steering+full GAS can now release the rear and produce power-oversteer without handbrake. Higher turning authority and less assisted stability permit deliberate donuts; handbrake flick impulse increased. Reverse stays separately modelled.
- Distinct Android APK versionCode=9, versionName=0.1.9 and matching versioned desktop/web artifacts.
- New headless tests: editable geometry & persistence, local records/stars, power-entry/drift and donut. Hardware feel and manually driven complete races still need review.
- Model: GPT-6. Source clips: 1000076235, 1000076237, 1000076238, 1000076239, 1000076240; no claim of matched input timing or exact reference car dynamics.

## [0.1.8] — Responsive handbrake, minimap, new course and Track Creator beta
- Unique v0.1.8 in game menu, Android versionName/versionCode and all Android/Web/Desktop artifact names.
- Same-physics-tick rear handbrake lock and brief steering overlap window for immediate entry; mobile GAS remains binary.
- Drone/chase framing raised to keep the car above controls; staggered-hole metal brake and tall gas, lowered handbrake.
- Live red vehicle dot and white start/finish marker on minimap.
- New original Shin-Kawa Full Circuit referencing supplied schematic's sweeper and S-curve rhythm, not identical source geometry.
- Android-accessible seeded validated Track Creator beta menu action, guarded by Track DNA compiler and saved under user://.
- Add automated geometry, generator determinism and touch/physics regressions.
- Android device feel, three human-driven laps, exact route and proprietary assets remain NOT RUN / not implemented.

## [0.1.7] — Benchmarks Oval/Sweepers, speed-perception camera tune, HUD playtest
- Added two optional comparison tracks: near-271m/24m two-sweeper Oval and near-295m/23m independent Sweepers-style loop.
- Track layouts use original control points; dimensionally comparable to DRIFTIT public guide, NOT identical proprietary course data.
- Keep original Shin-Kawa as the default selectable circuit; garage now offers 3 circuits.
- Fix Track DNA's false-negative local proximity validation on short tracks using physical distance along track rather than a constant knot neighbourhood.
- Bring overhead framing closer on portrait phones; chase moves closer and steeper, plus a small blend of true travel direction for visible drifting.
- Replace prototype HUD/touch rendering with approved black/pink visual direction: minimap, time, score tiles, camera/pause, numerical angle, portrait metal pedals and vertical handbrake. Prototype score/time data is real; star progression remains unimplemented.
- Regression: new Oval/Sweepers geometry/collision scene test, existing Godot controls/physics/camera tests.
- Android visual performance, subjective speed, real three laps and DriftIt matching recordings: NOT RUN. CI must be checked by commit SHA before marking build PASS.


# Nitro Wheelz change history

## [0.1.6] — P1 dynamic camera and desktop exports
- Implements speed-dependent orthographic camera scaling: Camera2D zoom-equivalent 1.15 at up to 20 km/h, 1.0 at 50 km/h, 0.82 at 90 km/h, 0.72 from 120 km/h.
- Smooth exponential interpolation of both zoom and camera position, including gradual close-in on braking.
- Camera moves ahead of actual velocity vector over 0.45 s (maximum 19 m), not the vehicle bonnet direction; supports sidelong drift.
- World-fixed top-down orientation; chase camera pulls back with speed, looks down more and raycasts potential solid-wall occlusion on the Godot physics tick.
- New dynamic-camera headless regression with zoom response, forward lead, speed values, and no world rotation.
- Native Linux x86_64 / Windows x86_64 export presets and GitHub Actions workflow added; no interactive PC playtest.
- Inherits v0.1.5 validated Nitro Track DNA P0; P2 driving re-tune, P3 LINE+ZONES+ANGLE+COMBO, P4 checkpoint scoring/ranking, P5 approved HUD and P6 art are queued, not falsely marked done.
- Build/CI status PENDING before workflow run; Android/PC visual and feel testing NOT RUN.


## [0.1.5] — Nitro Track DNA P0 geometry prototype
- Replaced handwired control point source with versioned JSON track data (19 authored knots + editable per-section widths).
- Added deterministic Track DNA compiler, shared centreline and left/right edge arrays, robust fail-closed spline/corridor validation, negative tests for duplicate nodes, invalid widths, figure-eight intersection.
- Switched all road strips, white lines, barrier meshes, analytic car contact bounds and Godot StaticBody3D collision mesh to the same validated edge arrays. Fixed previous offset/collision discrepancies.
- Replaced dangerous serpentine Shin-Kawa v0.1.4 layout with a validated original closed loop (screen-up first straight, first right-hand bend, varied road widths, curved technical sections). Prototype geometry, not final competitive circuit.
- Start line crosses the exact current road width, perpendicular to start tangent. Scenery avoids all other road branches.
- Geometry-only full-loop test and two-side wall rebound/collider mesh identity; no physical handset or three-lap human driving claim.
- **P1 dynamic camera and P2–P7 scoring/HUD/progression:** pending; retain existing systems until P0 gate is green.
- CI/build status pending at authoring; update handoff with evidence.


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
- **Build/test status:** Foundation, Godot, Android debug APK and Web export PASS on CI. Physical Android handling, screen appearance and vibration NOT RUN.
- Build evidence and checksum in HANDOFF.md.


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
