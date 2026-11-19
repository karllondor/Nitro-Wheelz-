## [0.1.19] — Car profiles: Lada baseline + RYU-32 4.0 V8, owner's recorded SFX merged
- **Owner's 17 recorded OGG sound effects merged** from `agent/nitro-v0.1.12-car-garage-audio` (they were pushed there at 11:13-11:22 UTC on 2026-11-19, after this branch had forked, which is why they were reported missing). Headless runs skip clip decoding but always create the synth engine; recorded tyre, impact and scrape clips take priority over synth layers; loops follow the volume sliders.
- **Car profiles** (`game/cars/*.json`, see docs/CAR_PROFILES.md): each car has a handling block for the shared drive model and an engine/sound block for the synth; tunable without touching driving code; paint variants share one profile.
- **Lada baseline unchanged, proven:** the drive model's constants became profile parameters with the same defaults; a golden physics trace and an engine-sound fingerprint recorded before the refactor are reproduced bit-identically (car_profiles_test).
- **RYU-32 = 4.0 V8 ITB** (owner correction: not an inline-six): eight cylinders, cross-plane burble, 760 / 7000 rpm, taller gearing, deeper exhaust, louder intake, no turbo clips; engine bay now shows a V8 with eight trumpets in two rows. Handling profile: stronger and faster, steadier long drifts, strong exits, but harder to throw in, longer to stop and more speed lost on lift-off (engine braking). Measured numbers in docs/CAR_PROFILES.md.
- **DEVELOPER:** BASELINE PHYSICS FOR ALL CARS (way back to the old handling) and AUDIO BENCHMARK (synth CPU on the device).
- Drift scoring and cameras unchanged. New `car_profiles_test.gd` with negative controls (Lada value nudged, RYU braking better than Lada).
- Android versionCode 19 / versionName 0.1.19.

## [0.1.18] — Audit plan: editor auto-smooth, separate volumes, player menu
- **Track editor AUTO-SMOOTH (audit P1):** the failing spline section is drawn in red on the map (from the validator's samples), the message is short and human ("CORNER TOO TIGHT (13.5 m) • TAP AUTO-SMOOTH", "ROADS TOO CLOSE TOGETHER", "TRACK CROSSES ITSELF"), and AUTO-SMOOTH (replaces the redundant VALIDATE button; validation already runs after every edit) relaxes only the nodes around the problem until the circuit validates. One UNDO step; if it cannot fix the shape it reverts and says so.
- **Separate volumes (audit P1):** ENGINE, TYRES and EFFECTS sliders next to SOUND ON/OFF and the accent colour, in a shared settings panel used by the pause menu and the main menu. They scale the synth's engine / tyre squeal / impact + scrape layers and the recorded clip groups; saved in user://nitro_settings.cfg.
- **Player main menu (audit P2):** DRIVE (track list with your best points per track, your last custom track, random track), GARAGE, TRACK BUILDER (3D tiles, node editor, generate & drive) and SETTINGS; controller diagnostics moved to DEVELOPER. COLLECTION not added yet (only three cars; garage covers them).
- New `main_menu_test.gd`; editor test covers AUTO-SMOOTH (fails with smoothing disabled); pause test covers the volume sliders reaching the synth and persistence.
- Android versionCode 18 / versionName 0.1.18.

## [0.1.17] — New car RYU-32 coupe, clearer scoring, stars for drift points
- **New car: RYU-32 COUPE (deep blue)**, built from the owner's blue 3D reference sheet: 4,545 mm long, 2,615 mm wheelbase, 1,290 mm high, wide bolt-on arches, aggressive bumpers and skirts, large fixed wing on uprights, rectangular twin-projector headlamps with amber corners, four round tail lamps, single big exhaust, bonnet removed with an inline engine on six chrome throttle trumpets, strut and X braces, silver 5-spoke deep-dish wheels. Original procedural geometry in the same die-cast style and API as the Lada (`scripts/vehicles/coupe_lowpoly.gd`); fictional name, no badges.
- **Car catalog** (`scripts/vehicles/car_catalog.gd`): Lada red, Lada white, RYU-32 blue. Garage shows one button per car, title and dimensions follow the selection, choice persists and the race spawns the chosen car. All cars use the same drive model for now (owner audit: keep physics); the wall-collision footprint follows the chosen car's size.
- **Scoring clarity (owner audit P0):** header now reads BANKED SCORE; the live box is labelled COMBO and shows raw points × multiplier plus "= N PTS TO BANK"; after you straighten up it shows BANKING… with a timer bar, and banked points fly into the BANKED SCORE, which pulses gold.
- **Stars for drift quality (audit P1):** stars are earned with drift points, scaled by distance (3 laps × track length; provisional 2.0 / 4.5 / 7.5 pts per metre, calibrated on the owner's runs). The finish screen shows the three thresholds under the stars and re-stars older stored runs by points. Time stays a statistic.
- Tests: coupe proportions/parts/catalog in visual_identity_test, coupe selection in garage_audio_test, wall_body_test runs both car footprints; star tests now use points.
- Android versionCode 17 / versionName 0.1.17.

## [0.1.16] — Finish screen redesign, subtle handbrake engraving
- **Finish screen rebuilt** (owner: "hard to read, you don't know where to look"). Full-screen board drawn in the HUD style with one hierarchy: track + FINISHED / NEW BEST! / FIRST RUN and stars; hero card with DRIFT POINTS as the biggest number and the change against your best (gold when beaten, red points-to-best otherwise), then TIME (with +/- vs your fastest), RANK and BEST CHAIN; LAPS table with time and points per lap, a points bar and the fastest lap in gold; chips for transitions, kerb clips and chains lost; YOUR TOP RUNS on this track ranked by points with gold/silver/bronze places, stars, date and this run highlighted (shown with its real rank under the top 5 when it is lower); big RESTART / GARAGE buttons. Landscape uses two columns. The old "recent drives" list and loose text lines are gone.
- Race records lap splits (time + points banked per lap; the last lap includes the final banked chain) and stores them with the run.
- Handbrake NW engraving is smaller and subtler (a shade lighter than the plate, hairline lips).
- New `results_screen_test.gd` (ranking by points, best/delta, real rank outside the top 5, splits add up to the total, layout fits portrait and landscape); negative controls verified (rank by time, missing splits).
- Android versionCode 16 / versionName 0.1.16.

## [0.1.15] — Barrier fix, HUD v3, garage studio, tyre/impact sound
- **Fix: driving through barriers.** Wall collision only tested the car's centre (kept 1.28 m from the edge), so a nose- or tail-first hit pushed the front 2.4 m of the race-scale body into and through the barrier (owner screenshot on Sweepers). New `resolve_body()` tests ten points on the oriented body (corners, bumpers, doors) against the barrier face, pushes the car back, reflects the velocity and adds a yaw kick from the contact lever arm. Evidence: 60 s of random driving on Sweepers / Shin-Kawa / Oval — old code up to 1.20 m past the barrier face, new code 0.000 m. New `wall_body_test.gd` (236 nose/tail-first impacts on all four tracks; fails with the old centre-only test).
- **HUD v3 (owner feedback):** a top-centre keep-out in the header for phone front cameras (it cut the old TOTAL SCORE label); LAP x/3 sits in the top band beside it; track name (light, centred) and the CHASING pill move into the header next to the minimap; TOTAL SCORE is the big number on the right with the clock under it. Minimap is turned so the track's long side is horizontal, and the car dot is placed on the white line from lap progress (never off it). Live chain points get a subtle glass frame and keep their value while fading. Callouts sit ~20% higher. Speedometer and joystick ring get the accent neon on the lower-right edge like the other panels. NW initials on the handbrake are engraved (metal cut with dark lip and light catch) instead of printed.
- **Garage:** neutral grey radial gradient studio with faint drift-swirl rings (screen-space backdrop, after the owner's poster reference) for both paints; camera uses a horizontal field of view so the whole car stays in frame at every turntable angle (it was cut off side-on). Owner confirmed the cars now show on the phone after the v0.1.14 MSAA fix.
- **Track editor:** TRACK EDITOR in large bold white on the left, track name centred in the accent colour; larger button, validation and help text; calmer frame (thin green when drivable, red with glow when not).
- **Sound:** tyre squeal rebuilt as white noise through narrow resonances whose pitch wanders, with stick-slip flutter (the old two fixed tones sounded like a siren); wall impacts are a falling-pitch body thud with crunch and panel rattle; new grinding scrape while the body slides along a wall. Tests check the squeal is noisy (not a pure tone), the impact has a low thud and scrape follows wall contact; negative controls verified.
- Android versionCode 15 / versionName 0.1.15.

## [0.1.14] — Owner feedback: HUD v2, editor layout, settings, engine
- **Driving HUD v2 (owner sketch):** bigger minimap with the stats to its right — TOTAL SCORE (heavy, where the clock used to be), LAP x/3, a smaller clock and a small track name; one thin full-width progress line split into three lap segments (done laps full, current lap fills). Centred **CHASING <best score>** pill under the header (local best on this track; "NEW BEST" once beaten, "FIRST RUN" with no record) replaces CHASING TIME/stars. The live chain (+points xN) sits centred under it and only appears while points are being scored. Round car-style speedometer (accent arc, ticks, needle, digital km/h) above the drift-angle pill. Scoring callouts are larger, outlined and pop just above the car (projected from the active camera), clear of the speedometer.
- **Pause menu settings:** SOUND ON/OFF (mutes the master bus) and six accent colours (pink, violet, cyan, lime, orange, red). The accent recolours every panel edge, glow, bar, button, gauge and handbrake cap immediately; both settings persist in `user://nitro_settings.cfg` and load at boot.
- **Handbrake:** the owner's NW initials (`assets/brand/nw_initials.png`) replace the "///" mark on the lever base. Pedals and lever otherwise unchanged (owner: keep them).
- **Car:** NW rear-screen banner removed from both cars.
- **Garage fix:** the 3D preview card was empty on Android. v0.1.13 had turned on 4x MSAA for the preview SubViewport, which renders nothing on some GL Compatibility phone drivers; MSAA removed (not yet confirmed on the owner's phone).
- **Track editor layout:** logo and instruction text removed. Header: saved track name on the left, TRACK EDITOR on the right, "?" help. The edit window now fills the space down to the validation line and the map is clipped to it (never drawn under buttons); FIT/ZOOM float in its top-right corner; buttons are compacted. The window frame is green when the track is drivable and red when it needs fixing; the validation text sits under the window. First open shows a HOW TO EDIT popup with a "Don't show again" checkbox and CLOSE.
- **Engine sound:** procedural engine rewritten as a source-filter model of an inline-four on individual throttle bodies (2 firings per turn): slightly uneven cylinders (lumpy idle), pulses ringing through fixed exhaust/intake resonances, load-dependent rasp and induction roar, hollow overrun with crackle/pops after lifting off, ignition cut on upshifts and a bouncing rev limiter. Recorded `engine_limiter` / `exhaust_pops` clips (when present) now follow this rev model instead of a speed proxy.
- Tests: visual_identity (HUD v2 rectangles, chase pill, callout anchor), brand_pause_surface (sound + accent settings, persistence), editor_results (clipped window, no button overlap, help popup), engine_audio (four-cylinder firing pitch, uneven idle, shift cut, limiter bounce, crackle window). Negative controls verified.
- Android versionCode 14 / versionName 0.1.14; artifact names v0.1.14.


## [0.1.13] — Die-cast car, approved driving HUD, night drift park
- **Car remake (die-cast / "resorak" target):** the box-assembled Lada is replaced by smooth procedural geometry: one lofted rounded body shell, lofted greenhouse with inset tinted glass and chrome drip rails, bolt-on widebody arches over a true 1.61 m shell (1.91 m over arches), quad round lamps + chrome grille/bumpers (red) or rectangular lamps + colour-matched bumpers (white), ducktail, exhaust, mirrors, door lines and handles, exposed triple-trumpet engine (red) or creased bonnet (white). Deep-dish tyres/rims built as surfaces of revolution: white 5-spoke (red car), cross-laced mesh (white car). "NW" rear-screen banner. 4.166 m / 2.424 m dimensions and the wheel/pivot API are unchanged.
- **Die-cast paint shader** (`assets/shaders/diecast_paint.gdshader`): GL-Compatibility-safe glossy finish with a view-space studio reflection so the car reads as a polished collectible from the high top-down camera. Soft contact shadow under the car. Meshes are batched per material and cached per paint variant.
- **Driving HUD to the approved reference image:** dark glass parallelogram panels with hot-pink neon edges, Exo 2 ExtraBold/SemiBold Italic (SIL OFL 1.1), header with minimap / track + lap / clock + live lap-progress bar, TOTAL SCORE / SCORE + combo / CHASING TIME with gold stars, skewed angle and KM/H tiles, icon PAUSE/CAM buttons. Stars are the projected result tier from the real pace using the same thresholds as the finish screen; the chased time is the next tier.
- **Touch controls redrawn:** metal joystick knob, ribbed handbrake lever with pink cap, chrome shaft and neon "///" base, perforated brushed-aluminium pedals with pink-lit edge. Touch rectangles unchanged except PAUSE/CAM, which now share one rectangle source with the HUD drawing.
- **Fix:** the pedal hole loop raised a GDScript runtime error every frame (`Array` assigned to `Array[float]`), so pedals on device had no holes; rewritten.
- **Night drift park:** surface → painted line → safety gap → raised blue/white kerb → outer gap → concrete barrier → earth verge → grass. Kerb blocks (~3 m) are cut exactly at arc-length boundaries with an even block count, so the colour sequence is continuous over every segment join and the start/finish. Barrier geometry and collision triangles are untouched (recoloured only). Voxel cherry-blossom trees, dark pines, soft tree shadows, pink verge blossom decals (MultiMesh, deterministic per track, kept clear of every road branch), moonlight, violet vignette and restrained rear-wheel tyre smoke. Softer translucent skid marks.
- **Original procedural textures** (`tools/generate_surface_textures.py`, seeded): night grass, earth verge, blossom sprites. The supplied asphalt texture is kept (tinted); the supplied sand texture is no longer used by the ground but stays in the repository.
- **Camera framing:** portrait top-down base size 84 → 46 (landscape 76 → 58) and an 11% portrait framing offset, so the car is close to the reference size and sits above the pedals; speed zoom curve and 0.45 s velocity lookahead unchanged.
- **Menus:** boot, garage, pause, results and editor share the HUD button/panel style. Garage: studio turntable (drag to spin), pink rim light, neon plinth, card frame. Editor: logo no longer overlaps title/instructions (TextureRect expand mode was set after size, so the SVG kept its native 620x349 size).
- New `visual_identity_test.gd` (car proportions, seamless kerbs, scenery clearance on all four tracks, HUD/touch rectangle agreement, projected stars, font) with a verified negative control. `capture_visuals.gd` renders review stills under Xvfb.
- Android versionCode 13 / versionName 0.1.13; artifact names v0.1.13. Android/desktop/web workflows also run on branch `ccr-91dad981-53kkbi`.
- **3D TRACK BUILDER (new menu entry "BUILD TRACK • 3D"):** tap the grass and a 56 m road tile appears with kerbs, verge, flowers and trees (drawn by the race's own track code); tap next to a road end to extend it, drag to lay a strip, ERASE, UNDO, CLEAR, GENERATE (procedural loop: rectangle grown by random one-tile bumps), SAVE (also opens in EDIT TRACK) and DRIVE. Tiles are joined by explicit links (max two per tile), so the result is always one loop without crossings while parallel strands may sit side by side. The loop becomes Track DNA control points (straights through tile centres, 28 m quarter arcs) and is validated by the unchanged fail-closed compiler (16 m minimum radius kept). Work in progress persists in user://nitro_builder_draft.json.
- `drift_track.gd` can draw open chains (`build_from_samples`) for the builder preview; race geometry/collision code paths are unchanged.
- **P3 drift scoring** (`scripts/race/drift_scorer.gd`): chain points = speed x angle sweet spot (25-60 deg) x kerb proximity (up to x1.5 with the car body on the kerb/outer gap); multiplier +0.1 per 1.5 s and +0.25 per left/right transition (cap x5); chains bank after 0.9 s without drifting; a wall hit (>= 2 m/s) or spin (>= 115 deg) loses the un-banked chain. HUD: TOTAL = banked, SCORE xN = live chain, short callouts (KERB CLIP, TRANSITION, BANKED, CHAIN LOST). Results show best chain, transitions, kerb clips and lost chains.
- **Procedural inline-six engine** (`scripts/audio/engine_synth.gd`): one phase-continuous wavetable voice at 3 firing pulses per revolution, simple 5-speed gearbox with drift wheelspin revs, throttle-dependent tone, tyre squeal and wall thump fallbacks. Recorded clips still take priority when present; the synth keeps the same engine identity from idle to the limiter.
- New tests: track_builder_test, drift_scoring_test, engine_audio_test (all with verified negative controls); builder scene added to the smoke test.
- Handset look/performance, finger feel in the builder, score balance on real laps and sound quality on phone speakers: NOT RUN.
- **Owner feedback pass:** EDIT TRACK can pan (drag empty map, right/middle mouse), pinch-zoom with two fingers and wheel-zoom at the cursor (zoom up to x6), plus a FIT button; edge knots are now editable up close.
- **Cars closer to the approved sheets:** red drift spec is a crisp faceted low-poly body (flat-shaded shell, square edges, polygonal widebody flares), taller greenhouse with upright glass, chrome window frames, black B-pillar, chrome mirrors, four short velocity stacks low in the open bay, red/white tail lamps, crimson paint and neutral chrome. Pearl white keeps a soft rounded body with clean sides (no belt chrome), colour-matched front lip, no front indicators and dark-faced mesh wheels; the NW banner is only on the red car. Garage uses the sheets' light studio (grey for red, lavender for white) and opens on the front three-quarter view.
- **Race framing:** top-down camera further out (portrait base 46 -> 60, landscape 58 -> 72) and the race car drawn 15% larger (RACE_CAR_SCALE; physics, wheelbase and wall contacts unchanged; skid marks scaled).
- **Sky:** golden-hour sky shader with drifting clouds (chase camera) and soft cloud shadows drifting over the whole park (one transparent world-space plane, cloud texture generated by tools/generate_surface_textures.py). Ground slightly brighter and vignette lighter so the shadows read.

## [0.1.12] — Car remake / garage / conditional user audio
- Redesigned Lada 2106 drift spec to real 4.166m overall length and 2.424m wheelbase; corrected the driving model's axle separation and shortened cabin to increase hood/boot lengths. Added sloped front/rear windshields and refined wheel arches.
- Red engine-exposed spec and pearl-white closed-hood spec via 3D garage preview, persistent selection until app is restarted.
- 17 independent WAN source-derived OGG files are now COMMITTED under `game/assets/audio/`, and all corresponding 16-bit WAV edit masters are COMMITTED under repository-root `audio_masters/`. Physics-reactive mixer resolves exact filenames. Audio quality still requires mobile listening tests.
- Android versionCode=12, versionName=0.1.12, distinct export artifact names.
- Added garage/audio regression suite; physical handset controls and recorded-audio playback require confirmation.
- Model: GPT-6. Reference dimensions cross-checked against VAZ-2106 workshop specs (4166mm / 2424mm).

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
