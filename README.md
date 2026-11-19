# NITRO WHEELZ
### JAPAN DRIFT NIGHTS

**A skill-based arcade drift racer:** Japanese-inspired circuits, difficult but learnable oversteer, clean stylized 3D and two selectable cameras. Developed in Godot 4.7.2 for Windows, Linux and Android.

**Status: v0.1.18 OWNER-FEEDBACK TEST CANDIDATE (unmerged).** A first playable test build, not a finished racing game. No proprietary assets or DRIFTIT source code are used.

## Concept
Nitro Wheelz combines:
- **DRIFTIT-like mechanical principles:** a separately implemented deterministic two-axle car model, rear traction hysteresis, power oversteer, handbrake and assisted countersteering. Its developer-published numeric parameters provide initial tuning targets, not a claim of identical code or handling.
- **Japanese drift-circuit culture:** original fictional layouts inspired by Ebisu, Nikko and Meihan; the first track is Shin-Kawa Drift Park.
- **NIGHTRIDEPL and Drift Games cultural references:** the passion of collecting, building and tuning individual JDM cars, atmospheric night sessions and garages. There is no official partnership or branded car pack.
- **Clean HD-2.5D presentation:** actual 3D roads and cars with readable, selectively stylized surfaces. Default camera high top-down like the user's DRIFTIT mobile screenshots; chase camera is an option.

## Launch
Open game/project.godot in Godot **4.7.2 stable**, press F5, choose **START DRIFT SESSION**. For engine checks use:

```bash
python3 -m unittest discover -s tests -v
python3 tools/check_project.py
bash tools/run_godot_checks.sh
```

## Controls

| Action | PC | Xbox Wireless Controller | Android |
|---|---|---|---|
| Steering | A/D or ←/→ | Left stick | Joystick left |
| Throttle | W or ↑ | RT | GAS |
| Brake | S or ↓ | LT | BRAKE |
| Drift/handbrake | Space | A | DRIFT |
| Camera top-down/chase | C | Y | On-screen camera region |
| Pause | Escape | Menu | Top-right pause region |
| Restart | R | optional menu later | pause/menu later |
| Main menu | M | pending UI focus | pending UI focus |

InputMap runs through a single vehicle model regardless of device. Touch actions are pointer-ID-aware, allowing simultaneous steering, gas and drift. Android controls and controller connection must still be verified on a real device.

## Currently implemented
- Original two-contact-patch planar physics controller at 120 Hz with two 240 Hz substeps
- Public-reference starting grip values, hysteresis, handbrake, rear torque/traction trade-off and sliding-only countersteer assist
- Original Shin-Kawa, reference-inspired Full Circuit, two benchmark courses and a validated Generate Track beta, marker stripes, low-poly pines, barriers and car
- Drift scoring, speed and slip HUD, three-lap progression, persistent tyre marks and off-track slowing
- Overhead orthographic and behind-car chase cameras (same vehicle physics)
- Xbox/keyboard/touch bindings, input monitor, Godot smoke and deterministic physics regression tests
- Karll Game Starter quality, approved-asset guardrails, SemVer and release tooling

## Not yet built
Final branded/licensed vehicles, garage collecting, tuning, NIGHTRIDE/Drift Games packs, progression/saves, nitro boost, replay ghosts, real Japanese circuits, production-grade audio/VFX, online leaderboards and signed Android exports.

Future official creator packs require licensing/permission. Real auto body styles shown in reference material do not grant rights to use their brands or unique liveries.

## Evidence and release
See docs/PHYSICS_REFERENCE.md, docs/ART_DIRECTION.md, docs/CONTROLS.md and docs/QA_MATRIX.md. Every test should be marked PASS/FAIL/NOT RUN. Versioned artifacts use Nitro-Wheelz_v0.1.18_Platform and are never overwritten.


## v0.1.9 mobile playtest
- **EDIT TRACK • BETA** is now a separate touch-driven editor. Tap a white node, drag it to change the road, use ADD/DELETE, VALIDATE, SAVE and DRIVE. The road must pass the fail-closed Track DNA validator before racing. The **GENERATE TRACK • BETA** button remains a separate procedural variation feature.
- Finish screen is now a separate full-screen presentation with three-lap time, score, three-star result (provisional for non-Oval tracks), locally ranked best runs and recent play history. Data is local to this device only under `user://nitro_local_runs.json`, not an online leaderboard.
- More responsive power-oversteer, reduced assist/damping and stronger handbrake initiation support steering+GAS drifts and low-speed donuts. This is a deliberately more demanding arcade tune; device approval is still required.
- Build version 0.1.9 is visible in the menu, in Android versionName and in all APK/Web/Desktop artifact names.

## v0.1.10 handoff (Model GPT-6)
- **Driving:** reduces v0.1.9's unwanted spinning by restoring rear grip, increasing steering/yaw damping, and requiring actual rear slip before normal full-GAS power drift. Arcade car retains earlier handbrake one-tick response and intentional low-speed donut option. This is a tuning hypothesis awaiting real-phone approval, not a proven driving-feel fix.
- **Start New:** choose **CIRCLE** (valid closed editable circuit) or **BLANK CANVAS** (place control points by taps, minimum eight before Track DNA validation). Existing **GENERATE TRACK** remains separate.
- **Zoom:** +/− on the editing canvas, plus scroll wheel on desktop (0.5× to 4×). The camera/track bounds are refitted with the selected zoom.
- **Node feedback:** selected node **orange**; validator-identified failing local knot(s) **red**, mapped back from sampled curve/edge segment indexes. Structural/global errors such as fewer than eight nodes are explained in status text and cannot be assigned to one node.
- **Saving:** a track name is requested via dialog; each name uses its own local JSON file; the editor reloads the last saved valid track next time. Files are local to the handset, not published or shared online.
- **QA:** Godot headless checks cover nominal straight throttle, mild steering recovery, deliberate power drift, donut, circle/blank, node dragging, validation marking and named save. True multi-touch, Android UI visibility and player feel remain **NOT RUN** until tested on device.

## v0.1.11 device playtest — GPT-6
- Brand: the owner's white/purple graffiti logo and yellow crown are installed as a compact *vector trace* at the top of the main menu and track editor. This is a traced rendition, not the original raster embedded pixel-for-pixel. UI colors purple #9551F9, gold #FFDA49, white and deep charcoal.
- Pause bug: old HUD modal and touch Restart/Garage overlays are removed; PAUSE presents a single blocking CanvasLayer with RESUME / RESTART / GARAGE. Finish still uses a distinct result screen.
- History: recent drives show only day, abbreviated month and clock time; full ISO date remains stored for sorting.
- Editor: 48-deep UNDO for actual edits (node drag, add, delete, new/reset), Ctrl+Z on PC. Start New and Save are now compact native-in-scene dialogs with large touch labels and a name input positioned above the on-screen Android keyboard.
- Physics: approximately 10% reduction to yaw torque contribution and power-oversteer kick relative to v0.1.10. Handbrake flick remains unchanged.
- Surfaces: source-derived reduced WebP samples from the two provided images (dark asphalt / sand) are tiled on the shared procedural corridor, shoulders and ground using world-space UVs. The lighter textures may repeat at close range until a later visual polish pass.
- Tests: strict Godot import + tests for playable scenes, touch logic, pause exclusivity, loaded logo texture, asphalt/sand materials, editor Undo/dialog, and date formatting. Physical Android controls and perceived speed require owner approval.

## v0.1.18 — Editor auto-smooth, separate volumes, player menu
- Track editor highlights the failing corner and AUTO-SMOOTH fixes it.
- ENGINE / TYRES / EFFECTS volume sliders (pause menu and SETTINGS).
- Main menu: DRIVE, GARAGE, TRACK BUILDER, SETTINGS (+ DEVELOPER for diagnostics).

## v0.1.17 — New car, clearer scoring, points stars
- New RYU-32 coupe (blue, wide arches, big wing, open engine with trumpets) selectable in the garage and used in races.
- COMBO vs BANKED SCORE made explicit (banking timer, points fly into the score).
- Stars are earned with drift points; thresholds shown on the finish screen.

## v0.1.16 — Finish screen redesign
- Clear full-screen results: big drift points + change vs best, time/rank/best chain, per-lap table, drift stats, your top runs by points with this run highlighted.
- Smaller, subtle NW engraving on the handbrake.

## v0.1.15 — Barrier fix, HUD v3, garage studio, tyre/impact sound
- The whole car body now collides with the barriers (no more driving through them nose-first).
- HUD header avoids the phone's front camera; LAP beside it, CHASING inside the panel, TOTAL SCORE on the right; minimap laid horizontally with the dot on the line.
- Grey gradient garage studio, whole car always in frame; larger editor text; engraved NW handbrake.
- New tyre squeal, impact thud and wall scrape sounds.

## v0.1.14 — HUD v2, editor layout, settings and engine
- HUD v2 to the owner sketch: big minimap + TOTAL SCORE / LAP / clock, three-segment lap progress line, centred CHASING score pill, live chain only while scoring, round speedometer, larger callouts above the car.
- Pause menu: sound on/off and accent colour (recolours the whole interface; saved).
- NW initials on the handbrake; NW banner removed from the cars; garage preview fixed for Android (no MSAA).
- Track editor: clipped full-size edit window with green/red validity frame, name + TRACK EDITOR header, compact buttons, first-open help popup with "Don't show again".
- Inline-four ITB engine synth: uneven idle, exhaust/intake resonances, overrun crackle, shift cut, rev limiter.

## v0.1.13 — Die-cast car, approved HUD and night drift park
- Car: smooth procedural die-cast Lada 2106 (lofted shell + greenhouse, inset glass, widebody arches, deep-dish wheels, glossy toy-paint shader, contact shadow). Red = quad lamps, chrome, exposed trumpets, white 5-spoke; white = rectangular lamps, clean creased bonnet, mesh wheels.
- HUD and touch controls redrawn to the approved gameplay reference (pink neon glass panels, Exo 2 italic, gold stars, metal pedals, ribbed handbrake). Fixes the per-frame pedal draw error.
- Track art: blue/white kerbs with a seamless block sequence, white edge line, concrete barrier (same collision), earth verge, grass with blossoms, voxel cherry trees, pines, tree shadows, tyre smoke, vignette.
- Closer top-down framing (one constant: `OVERHEAD_BASE_PORTRAIT` in `scripts/race/race.gd`).
- Developer stills: `xvfb-run -s "-screen 0 720x1600x24" godot --path game --rendering-driver opengl3 --resolution 720x1600 --script res://tests/capture_visuals.gd -- /abs/out/dir`.
- BUILD TRACK • 3D: tap-to-build circuit builder with live road/kerb/scenery preview, GENERATE, SAVE and DRIVE (validated by Track DNA).
- Drift scoring with chains: kerb clips, left/right transitions, wall/spin loses the chain; TOTAL vs SCORE xN like the reference HUD.
- Procedural inline-six engine sound (works without the recorded OGG pack).
- Track editor: pan, pinch zoom and FIT. Cars restyled to the owner's sheets (faceted red drift spec, smooth pearl white). Sky with clouds and drifting cloud shadows; camera further out with a 15% larger race car.
- Handset rendering, frame rate and feel: NOT RUN.

## v0.1.12 — Car dimensions, garage and sound-import workflow
- Lada 2106 dimensions from technical manual: 4.166m body and 2.424m wheelbase, synchronized in visual geometry and model physics. Widebody/drift wheel track intentionally stylized, not stock 1.611m body width.
- Redesigned silhouette: proportionally longer bonnet and boot, shorter squarer cabin, sloped front/rear glazing, 24-segment tyres and 13-arch-segment flares, five-spoke wheels and detailed chrome trim. Red open engine vs white closed hood are accessible in GARAGE through a live 3D preview.
- Selected garage paint persists via user://nitro_garage.cfg across app restarts, and is used by all race tracks.
- New adaptive physics-driven audio controller in `scripts/audio/drive_audio.gd` maps 17 OGG clips to sliding, road speed, turbo, exhaust, handbrake, kerb, gravel and impact. Fails silently when assets are absent.
- **CRITICAL:** GitHub connector cannot upload the local generated OGG binary directly; **the repository and its CI APK do not yet include those 17 clips**. They are available in the separate `nitro_wheelz_v0.1.12_dropin_sfx.zip` conversation attachment. Copy `game/assets/audio/*.ogg` from that ZIP into the repository and rebuild Android to activate recorded sound. WAV masters supplied as well. Never imply that the default APK already plays the supplied files.
- No continuous Engine Master was uploaded; the provided limiter sample is triggered only at high simulated speed, not used as a looping engine idle. No physical phone speaker/fidelity test has run.
- Source model: GPT-6, 2026-11-19. Source videos: 1000076241.mp4 (tyres), 1000076242.mp4 (turbo/exhaust), 1000076358.mp4 (track/collision).
