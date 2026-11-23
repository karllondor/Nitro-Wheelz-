## [0.1.39] — NITRO WHEELZ PARK tutorial bugfix (TEST BUILD)
Issue #27 (owner phone QA c7082510153), branch `agent/claude/issue-27-tutorial-bugfix` = v0.1.38 + this. Doc: docs/NITRO_WHEELZ_PARK.md (section "v0.1.39 tutorial bugfix"); handoff: docs/dev/handoffs/issue-27-tutorial-bugfix-20261122-claude.md.
- ROOT CAUSE fixed: the touch layer was switched off during every exercise schematic and never back on (dead GAS / stick / handbrake from lesson 6/10, the pressed state stuck). New press blocker in `race_touch.gd` instead (ignores NEW presses while a card is up and the frame after it was dismissed; releases always work).
- The 8 s schematic timeout never ran while the car was frozen: the card clock now runs every frame.
- Navigation: big banner (WHERE the exercise is: distance + side, then what to do inside the zone), an arrow that circles the car, a ring on the pavement round the cone, a dashed guide line, distance / side recomputed from the live car each frame, wrong-way hint, wandering hint.
- Full-size welcome card (labels over the real touch targets) before lesson 1; the lesson card shows number + title, the instruction is the big banner.
- New test: park_navigation_test (real touch events: no dead / stuck controls, live navigation and arrow, rings, a real donut completes DONUT LEFT and advances to 7/10, wrong way / far / straight never count); screenshot tool tests/capture_park_tutorial_ux.gd. Android versionCode 39 / versionName 0.1.39. NOT RUN: the tutorial on a phone.

## [0.1.38] — Physics modes ARCADE_PLUS / REAL_POWER_TEST, white Lada N20B20, Android start screen (TEST BUILD, one version)
Issue #25 (owner dispatch NW-START-20261122-B, #26 c7081190249). Branches `agent/claude/issue-25-physics-cplus-a` + `agent/claude/issue-25-android-splash` merged into one release branch. Docs: docs/PHYSICS_MODES.md, docs/ANDROID_START_SCREEN.md, docs/CAR_PROFILES.md; handoff: docs/dev/handoffs/issue-25-physics-modes-20261122-claude.md.
- ARCADE_PLUS (default): the approved arcade handling and the same 0-100 km/h, each car's implausibly low top speed lifted to a per-car target (red 200, white 200, E30 220, RYU-32 225 km/h; PROPOSED, not owner-approved); bit-identical below 100.8 km/h (golden trace + an 8 s identity trace per car).
- REAL_POWER_TEST (DEVELOPER > ACTIVE PHYSICS MODE, applies to the next race): power-curve drivetrain (torque tables with confirmed / estimated points, a game-shifted manual box with 0.25 s shift cuts, real drag, traction-limited launch). Runs are never saved (no record, star or score). Mode shown in the developer overlays only.
- White Lada 2106 = lightly tuned BMW N20B20 single-turbo four (own profile `lada_n20.json`: 275 PS / 410 Nm estimate vs 245 PS / 350 Nm stock; own sound with a turbo layer: whistle with boost, flutter on lift-off). Red stays the 13B. No second turbo, not star-gated.
- Android start screen: transparent splash icon, so the OS start window no longer shows the NW monogram (root cause: the exporter uses the adaptive foreground as the splash icon). Launcher icon, boot artwork, loading screen and its progress bar untouched.
- New tests: physics_modes_test, white_lada_test, android_start_test; audit tool tests/physics_ab_audit.gd. Android versionCode 38 / versionName 0.1.38. NOT RUN: every phone check (feel of both modes, cold / warm start).

## [0.1.37] — NITRO WHEELZ PARK (open training pad + optional tutorial) (TEST BUILD)
Issue #27 (owner dispatch 2026-11-22), branch `agent/claude/issue-27-nitro-wheelz-park` = v0.1.36 + this. Doc: docs/NITRO_WHEELZ_PARK.md; handoff + screenshots: docs/dev/handoffs/issue-27-20261122-claude.md; audit of the car performance (docs only): docs/CAR_PERFORMANCE_AUDIT_20261122.md.
- New main-menu entry PARK: ONE big open paved surface (no walls, no collider, no lap / score / stars) with donut rings, a large and a small figure-eight, a long flattened eight (miniature drift circuit for starter cars), 80 orange cones that tip and slide and never touch the car, and the approved full NITRO WHEELZ logo painted flat in the middle (the existing SVG, unchanged, checked by a test).
- START TUTORIAL (10 lessons judged by the real car and controls: GAS, steering, BRAKE, HANDBRAKE, first slide, donut left / right, large / small eight, the long route; automatic advance, schematic before a drill, highlights on the real touch targets, off-screen arrow, beacon, demonstration ghost, hints, saved progress) or FREE DRIVE = SKIP TUTORIAL on the same pavement; the pause menu toggles the tutorial; skipping keeps cones and paint where they are.
- The full Exo 2 variable font is registered as glyph fallback: Polish letters (nicknames, lessons) render in the game's own typeface.
- New tests: park_layout_test, park_tutorial_test; evidence tool tests/capture_park.gd; audit tool tests/car_performance_audit.gd + tools/perf/reference_model.py.
- Android versionCode 37 / versionName 0.1.37. NOT RUN: every phone check. The layout (outline, dimensions, positions) is PROVISIONAL: not owner-approved.

## [0.1.36] — Feel + visuals batch, power-to-weight calibration, 13B rotary Lada (TEST BUILD, one version)
Issue #25 (owner request 2026-11-22 after the driftit.app comparison), branch `agent/claude/feel-visuals-v0.1.36` = v0.1.35 + this. Table of every wish: docs/FEEL_VISUALS_v0.1.36.md; calibration: docs/CAR_PROFILES.md (ADR-010); handoff + before / after screenshots: docs/dev/handoffs/issue-25-20261122-claude.md.
- GAS pedal is an L-shape with a wing above the brake (drawn and touched as one polygon; brake / handbrake / joystick unchanged).
- Tyre marks: soft-edged shader, thinner, opacity 0.40 (was 0.50 hard-edged), oldest marks lighter.
- Asphalt about twice as bright; cloud shadows 64 m patches with strength 0.26 (were 150 m / 0.55: the track suddenly went dark).
- One NITRO WHEELZ inscription on every straight >= 45 m (max 4, never near the start line); advertising band on both barriers; concrete slabs on street-circuit shoulders.
- Cars calibrated by power-to-weight (0-100 ~ 1/PS-per-tonne, top ~ cube root): anchor = red / white Lada 2106 with its Mazda 13B rotary (231 PS, ~1,150 kg est., 3.29 s / 127.8 km/h unchanged); the E30 (193 PS / 1,250 kg) is now slower: 4.29 s / 116.9 km/h (was identical to the Lada); RYU-32 unchanged (+9 % vs its target, inside the tolerance of its estimated mass).
- Lada: `lada_13b.json` (handling bit-identical to the baseline + rotary engine sound: two rotors, two banks, 9,200 rpm, bridgeport lope, popping) and a 13B engine bay in the red GLB (four trumpets in a row). `lada_baseline.json` stays the benchmark file.
- New tests: gas_pedal_shape_test, track_details_test, car_performance_test; evidence tool tests/capture_feel_v0136.gd; texture generator tools/art/make_track_textures.py.
- Android versionCode 36 / versionName 0.1.36. NOT RUN: every phone check.

## [0.1.35] — Player card, one RACE SETUP flow, results table layout (TEST BUILD, one version)
Issue #24 (owner request 2026-11-22), branch `agent/claude/profile-flow-v0.1.35` = everything of v0.1.34 + this. Flow, rules and limits: docs/PLAYER_PROFILE_FLOW.md; handoff + screenshots: docs/dev/handoffs/issue-24-20261122-claude.md.
- Finish screen TOP RUNS: POINTS flush right, TIME beside it, STARS, then DRIVER and CAR with all the remaining room (text shrinks to fit instead of being cut).
- Limits: player name 2–14 characters (letters incl. Polish, digits, space `- _ . '`), every car label at most 14 characters (tested for the whole catalog).
- First launch asks for the player name (WELCOME). New PLAYER CARD (tap the player chip in the main menu): vector avatar with skin / hair colour / hair style / t-shirt colour, editable name, total stars, list of the tracks driven with the best time / points / stars; a tap selects that track and opens RACE SETUP, where CAR opens the garage.
- DRIVE now opens RACE SETUP (TRACK + CAR + DRIVE). The track list only picks a track and returns to where it was opened from (it no longer starts the race); the garage has a TRACK button and BACK returns to the menu or to RACE SETUP; the last track is remembered.
- New tests: player_profile_test (limits, table columns at 900 / 960 / 1000 px design width, avatar, progress, the whole menu -> setup -> track -> garage flow); evidence tool tests/capture_profile_flow.gd.
- Android versionCode 35 / versionName 0.1.35. NOT RUN: every phone check (keyboard on the name fields, touch targets, long names on the phone, fresh install vs upgrade).

## [0.1.34] — Integration TEST build: four phone bugs, GLB cars by default, driver table, loading screen (TEST BUILD)
Integration branch `agent/claude/integration-v0.1.34` = merges of the task branches below (each has its own handoff + evidence in `docs/dev/handoffs/`; nothing here is phone-verified; no PR was merged).
- #18 open-route minimap: no false closing diagonal, START / FINISH markers, dot follows the real road (`race_hud.gd`).
- #16 black discs at the rear wheels on the first drift: wheel geometry was correct; the tyre smoke (billboard `keep_scale = false` + vertex colour) drew its youngest particles black — fixed, plus DEVELOPER > DRIFT LAYER ISOLATION to prove it on the phone.
- #19 Ojców stream over the asphalt: the water now follows the road (>= 2.2 m below the surface at every crossing, natural level elsewhere).
- #20 sliding roadside bushes: merged roadside planting used the absolute terrain height as the sway lever (0.5 m on Ojców, ~2.3 m on Touge); fixed, tree sway unchanged; DEVELOPER > VEGETATION WIND.
- Loading screen: the NITRO WHEELZ key art on the track loading card and as the boot splash (PNG, 0.8 s minimum).
- #22 Car Factory GLB models are the DEFAULT for Lada RED / WHITE and RYU-32 (owner decision 2026-11-22, ADR-009), per-car PAINT / WHEELS / SIGNATURE from `car_factory_cosmetics.json`, RYU-32 stripes = a PAINT preset; DEVELOPER > CAR FACTORY GLB CARS (OFF = earlier procedural models). Selective port from PR #15 (not merged).
- #23 local driver name + finish-screen TOP RUNS table: # | DRIVER | CAR | STARS | TIME | POINTS (owner's order); accessors renamed `get_driver_name` / `set_driver_name` (the PR #15 names are shadowed by Resource.get_name and returned null).
- New tests: terrain_route_minimap_test, wheel_smoke_test, terrain_water_road_test, vegetation_stability_test, loading_screen_test, car_factory_default_test, driver_profile_test.
- Android versionCode 34 / versionName 0.1.34. NOT RUN: every phone check (see the handoffs).

## [0.1.33] — AI-generated body test car "RYU-32 FLAME (AI TEST)" (TEST BUILD, not for release)
Report: docs/car_factory/AI_BODY_PROTOTYPE.md (pipeline, licence status, known flaws).
- New fifth garage car R32 • FLAME: a body generated with an image-to-3D service (flame livery baked into its texture) fitted to the RYU-32 footprint, tyres cut out, the wheel library's rotating RYU deep 5-spoke wheels on its hubs. Drives exactly like the RYU-32 (same handling profile, V8 sound, collision footprint); looks only. Always on (no DEVELOPER switch); falls back to the procedural coupe when the GLB is absent.
- The black painted-on bonnet vent is repainted in the paint colour (texture + metallic-roughness fill, lumpy geometry relaxed); paint roughness floored so the car shader no longer washes the blue out.
- tools/car_factory/blender/import_ai_car.py: nose turn, non-uniform fit to the catalog, weld, axle detection, manual tyre cut with dark liners, hood repaint, decimation, baseline-JPEG textures, hubs. 41 371 triangles with wheels, 6 draw calls.
- Licence: the asset comes from the free (non-commercial) plan of the generating service; test project only, see docs/LICENSE_AND_SOURCES.md. Known flaws: open roof, invented sponsor text / plate on the texture.
- Android versionCode 33 / versionName 0.1.33. NOT RUN: phone review.

## [0.1.32] — Mobile QA fixes from the owner's v0.1.28 phone test (TEST BUILD)
Report: docs/MOBILE_QA_v0.1.32.md (causes found in code, fixes, tests, what is NOT confirmed on the phone, owner checklist).
- Track Builder MOVE / pinch: camera pitch and terrain lift frozen while a finger moves the map (the per-event mountain-occlusion search moved the ground under the finger), no fling, view centre kept over the map, plane-only pan. Test: 0.000 m drift of the ground point under the finger over 24 drag steps in the Tatry.
- Dead bottom-left strip fixed: BUILD now has its own map rectangle down to the button rows (the SETUP one left ~15 % of the screen above the two BUILD rows dead, also for a second pinch finger).
- The UPDATING TERRAIN pill no longer swallows touches; the map moves while the terrain adapts, world-changing buttons wait. A pinch no longer runs a terrain fit when its first finger lifts.
- Records per track layout: Terrain Builder DRIVE, the 3D builder and named saves fingerprint the geometry in the track id (all builder layouts shared one best: "CHASING 27,226" everywhere). HUD pill: NEXT ★n target of this track, then the best, then ALL STARS.
- Race cameras start behind the car's start heading (also after RESTART / terrain load). Rear-wheel steering on the first drift NOT reproduced: wheel_visual_test measures 0.00° on every car incl. the Car Factory test models.
- Builder markers only near the road (no more coloured grid over the landscape); roadside planting 2.0 m behind the barrier (was 0.9).
- Pause: RESTART and GARAGE / MENU need a second tap.
- DEVELOPER: TOUCH DIAGNOSTICS overlay (touch IDs, who takes each touch, hitboxes, input order, FPS / frame time, terrain fits, wheel angles), RESET DEVELOPER DEFAULTS, EXPORT DEVELOPER PRESET; developer settings moved to user://nitro_dev.cfg apart from the player's settings; every option documented in docs/DEVELOPER_MODE.md.
- New tests: builder_touch_test, wheel_visual_test, track_records_test; capture_mobile_qa.gd evidence tool.
- Android versionCode 32 / versionName 0.1.32. NOT RUN: phone verification.

## [0.1.31] — Car Factory stage 3: RYU-32 CLEAN / LIVERY as one GLB (TEST MODEL, not approved)
Report: docs/car_factory/RYU32_FACTORY.md (sources, missing LIVERY reference, V8 vs sheet engine, orthographic comparison, budget).
- New tools/car_factory/blender/build_ryu32.py: 90s drift coupe from the CLEAN BLUE reference sheet - aero kit bumpers with intakes and lips, kit over-fenders and skirts, twin-projector lamps, quad round tail lamps, big exhaust, large fixed wing, bonnet removed with a 1UZ-style V8 on eight ITB trumpets (the brief's V8, not the sheet's inline engine), cage with the X behind the seats.
- CLEAN and LIVERY share the GLB: the paint shader now takes an optional livery texture in the factory's livery UV layout. The LIVERY design is PROVISIONAL (no reference received).
- New wheel RYU DEEP 5-SPOKE (0.33 m tyre, 20 in rim look). 38 550 triangles with wheels, 8 draw calls, body GLB 1.18 MB.
- capture_car_views.gd: orthographic side / front / rear views (blueprint comparison) and a 5th argument for the look.
- DEVELOPER: CAR FACTORY TEST MODELS now covers the RYU-32 too; RYU-32 TEST LOOK: CLEAN / LIVERY. Default OFF = procedural RYU-32. Handling, V8 sound, collisions, saves unchanged.
- Android versionCode 31 / versionName 0.1.31. NOT RUN: phone review.

## [0.1.30] — Car Factory stage 2: Lada 2106 RED / WHITE as one GLB (TEST MODEL, not approved)
Report: docs/car_factory/LADA_2106_FACTORY.md (decision, sheet measurements, budget, BEFORE / AFTER, unconfirmed details).
- New tools/car_factory/blender/build_lada_2106.py: one shared sedan body + RED parts (exposed VAZ four with 4 ITB trumpets, quad round lamps, chrome grille / bumpers / trim, bolt-on overfenders, red sheet tail lamps) and WHITE parts (closed bonnet with raised centre, rectangular lamps, colour-keyed bumpers + skirts, rolled flares) in ONE GLB.
- Geometry variants: nwcf.tag_variant() writes a variant mask to TEXCOORD_1 (0 shared, 1 RED, 2 WHITE); the paint / atlas / glass shaders collapse the other variant's faces. One mesh, 3 body materials, 8 draw calls. RED 37 510 / WHITE 31 444 visible triangles incl. wheels (budget 42 000).
- Wheel library: LADA 5-SPOKE DISH and LADA MESH (18 in, per-design tyre / rim sizes; build_wheels.py --only keeps the E30 wheel files untouched). Atlas swatches extended append-only.
- Shown only with DEVELOPER > CAR FACTORY TEST MODELS: ON (default OFF = the approved procedural Lada). Looks only: handling, sound, collisions, scoring and saves unchanged; the garage labels the test model.
- Proportions follow the approved sheets (overhangs 0.68 / 1.06 m, 0.295 m tyres, roof 1.34 m) inside the unchanged 4.166 / 2.424 / 1.91 m gameplay footprint.
- New test factory_models_test; capture_car_views.gd takes a 4th argument factory|classic.
- Android versionCode 30 / versionName 0.1.30. NOT RUN: phone review.

## [0.1.29] — E30 Blessed Final Visual Polish v0.3  — TEST BUILD, not approved until the owner reviews it on the phone
Report: docs/car_factory/E30_VISUAL_POLISH_v0.3.md (audit vs the camera-matched NIGHTRIDE photos, changes, measurements, BEFORE / AFTER, lessons learned).
- Paint (every colour / finish): clear coat reflects a world-space studio horizon, so reflection lines follow the body's curvature; shade keeps its chroma. Atlas metals: horizon reflection sharpness follows roughness (polished lip / chrome vs machined face).
- Signature wheels: wider polished step lip, deeper dish, contact-shadow ring, more concave face (same size, pivot, offset).
- Bumpers: upper bar with a rubber insert band, recessed lower apron, front lip, lower side wraps with a straight bottom; plate on the bar. Taller kidneys, fuller bonnet crown, deeper tail-lamp frames, rolled chrome exhaust tips.
- Garage: controlled framing for every car (lens fitted to the real silhouette each frame, never clipped, up to 22 % closer at narrow views), slightly higher product-shot camera.
- 41 502 triangles (budget 42 000), 8 draw calls, body GLB 1.055 MB. Dimensions, wheelbase, pivots, UV, materials, handling, audio, scoring, HUD and cameras unchanged; Lada / RYU-32 untouched.
- New QA tool tests/capture_car_views.gd (7 views + 6 close-ups + garage + race for any car variant).
- NOT RUN: phone review. Android versionCode 29 / versionName 0.1.29.

## [0.1.28] — Japan City street circuit  — TEST BUILD (owner request after v0.1.27)
- Buildings line the race road: a frontage row of shops (awnings, signs), mansions (balconies) and low offices faces the circuit on both sides with facades on the sidewalk right behind the verge (~5.4-6 m from the asphalt edge); gaps where grid streets meet the circuit; none over bridges / at the venue; grid blocks, poles and trees stay behind the row.
- Chase camera rises over a building beside the road instead of entering it; facade windows start at each face's own edge.
- Test: terrain_scenery_test checks the frontage (>= 20 buildings, nearest facade between verge + 1 m and 6 m). Everything else as v0.1.27.
- Android versionCode 28 / versionName 0.1.28.

## [0.1.27] — Terrain Builder visual & track builder refinement (+ owner chat requests)  — TEST BUILD, not approved until the owner plays it on the phone
Report: docs/terrain_builder/REFINEMENT_v0.1.27.md (every item, BEFORE / AFTER for all 8 regions, seeds, bridges, route ends, UI, measurements, PASS / FAIL / NOT RUN). The two phone recordings named in the brief were not received.
- Builder camera: line-of-sight FIT (no more Tatry rock / snow walls in front of the map), smooth pitch, no overview haze; region change shows a clear NOT GENERATED card.
- Navigation: ✋ MOVE mode, plane-anchored pan / pinch (no jumps), fling, 12° twist dead zone, auto-scroll while drawing at the map edge; setup drag pans.
- Loading card (dim, spinning dots, chequered progress) with frame-sliced terrain generation / road fit / AUTO / track loading in the builder, sliced terrain build at race start, card on AUTO-SMOOTH and menu transitions (new `NitroSteps`, `NitroBusy`).
- Landscapes: per-seed macro landforms (mirrors, macro parameters, 2-4 large hills / hollows); faceted rocks by geology; tree proportions / lean / crown variants; rock strata in the ground shader; taller Irish cliffs with strata, surf and sea stacks.
- Japan City: shader-painted street grid + zoned district (towers, offices, department store, mansions with balconies, shop rows with awnings and signs, convenience stores, parks with shrines, utility poles + wires, street trees, traffic signals), facade shader, concrete shoulder.
- Bridges: stream channel never filled (bridge over the Ojców stream, water continuous); > 6 m fill = bridge; masonry arch bridges / viaducts for Poland and Ireland sized by the valley, concrete for Japan.
- Builder preview pieces laid on the ground (no more buried road); buildability squares painted on the terrain; a new landscape keeps the whole road and reports red tiles.
- Roadside band behind the barrier (shrubs, flowers, ferns, heather, gorse, dwarf pine, stones, forest edge), delineator posts every 20 m; colour pass (linear tone mapping, cooler ambient, saturation, depth fog from 220 m); chase camera closer / lower with speed FOV.
- Open routes: staging paddock behind the start + parc fermé after the finish on terrain-fitted pads; start light pole with four green lamps before the start line.
- SAVE with a name (SAVE / SAVE AS NEW), MY TRACKS list in the builder, terrain tracks redirected from the node editor to the Terrain Builder; pause menu: ▶ RESUME, RESTART + ✎ EDIT TRACK, GARAGE / MENU, SOUND & STYLE folded.
- Game icon: the owner's NW crown icon (full-bleed, Android adaptive layers, project icon).
- Tests: terrain_scenery_test (city block variety, roadside planting behind the barrier), terrain_physics_test (route start / finish areas + start lights); run_godot_checks.sh runs headless tests with `--audio-driver Dummy`. Evidence tools: capture_bridges.gd, capture_ui_v0127.gd, capture_terrain.gd (routes, bridges, frame stats).
- NOT DONE: free-draw (Townscaper-like) drawing — evaluated only; Japan City catch fencing / rail viaduct. NOT RUN: phone / browser performance, owner review.
- Android versionCode 27 / versionName 0.1.27.

## [0.1.26] — E30 Blessed visual refinement pass v0.2  — TEST BUILD, not approved until the owner reviews it on the phone
Report: docs/car_factory/E30_VISUAL_REFINEMENT_v0.2.md (BEFORE / AFTER views, close-ups, race cameras, photo-camera comparison, measurements).
- Bonnet: rounder nose, more crown, soft creases, separate shark-nose visor over the grille (the old leaning end cap pushed yellow wedges into the grille).
- A-pillars body-coloured (wider pillar, painted opening walls, slimmer 15 mm seal).
- New factory paint shader `nitro_car_paint` (E30 only; Lada / RYU-32 keep `diecast_paint`): panel light / shadow, paint depth, crisp clear coat, no milky film. Blessed Yellow #F2C40C -> #EFBA0D (old saved hex mapped). Scene lights unchanged.
- Front bumper profile + rounder corners; black grille panel under the bonnet lip; lamps with housing cup, thin chrome ring, recessed lens, low / high beam lens patterns, faint glow only.
- Tail lamps: framed, convex, three segments with dividers and ribs.
- Signature wheels: wide polished step lip, deep polished dish, concave face with real vent pockets, domed centre.
- Rubbing strips with rounded ends; darker glass (cage still visible); E30 18 % larger in the garage card (fits over a full turn).
- Car 38 266 -> 41 288 triangles (budget 42 000), draw calls 8 -> 8; body GLB 1.03 -> 1.06 MB, Signature wheel 92 -> 109 KB. Dimensions, wheelbase, wheel pivots, paint UVs, handling, audio and scoring unchanged.
- Tests: e30_factory_car_test checks the new paint shader and that the zoomed car stays inside the garage card. Tool: tests/capture_e30_views.gd (identical garage views + close-ups).
- NOT RUN: phone review.
- Android versionCode 26 / versionName 0.1.26.

## [0.1.25] — Terrain-first Track Builder (Japan / Poland / Ireland, 8 landscapes)  — TEST BUILD for owner review
Per docs/research/procedural_world/CLAUDE_MASTER_BUILD_BRIEF_2026-11-20.md. Report with every result marked PASS / FAIL / NOT RUN: docs/terrain_builder/TERRAIN_BUILDER_REPORT.md.
- **New terrain-first builder** (`TRACK BUILDER > TERRAIN BUILDER`, `scenes/terrain_builder.tscn`): choose COUNTRY -> LANDSCAPE -> event (PRACTICE / CLUB / PRO) -> **GENERATE TERRAIN** (again = new landscape) -> look around (drag orbit, pinch zoom, two-finger pan + twist rotate, VIEW 3D / TOP / LOW) -> DRAW ROAD on 56 m tiles draped on the terrain (green on grade / amber cut-fill-walls-bridge / red refused with the reason) -> terrain adapts automatically -> SAVE / DRIVE. DRAW, ERASE, UNDO, REDO, CLEAR, LOOP / ROUTE, CLOSE (auto-connects the ends over buildable tiles), AUTO (random buildable loop or route), FIT. Saved tracks reopen with EDIT (DRIVE list and results).
- **8 archetypes** (data in `terrain_catalog.gd`): Japan Sakura Circuit, Forest Drift Park, Touge Mountain, City Track; Poland Ojców Canyon (golden autumn), Tatry Mountain; Ireland Coastal Cliffs, Green Hills. Each with its own relief recipe, max road grade (3-7 %), geology (mossy / limestone / granite / basalt), vegetation species, tint (petals, autumn leaves, heather, field patchwork, parks), water (sea, stream), landmarks, venue style, sky / sun / fog, kerb and run-off colours.
- **Deterministic generated world** (`terrain_field.gd`, `terrain_world.gd`): 1120 x 1344 m detailed terrain (8 m grid) in 30 stable chunks + horizon ring to 3.2 km, sea plane, Ojców stream, true vertical sea cliffs with a rock face mesh, per-region lighting.
- **Road on terrain** (`road_profile.gd`, `terrain_track.gd`): heights solved over the full road width with a max-grade (Lipschitz) projection balancing cut and fill, periodic on loops; knot heights saved in the track (`elevation`) and expanded with the same spline in builder and race. Every sample classified: GRADE, CUT/FILL, CUT WALL, FILL WALL, BRIDGE, CLIFF BARRIER, UNBUILDABLE (with reason).
- **Local terrain adaptation**: flat bench beside the road, cut / fill slopes, continuous retaining walls, bridge decks + piers, cliff-side stone walls; only within ~98 m of the road; only the affected chunks rebuild; removing the road restores the generated terrain exactly.
- **Scenery zoning** (`terrain_scenery.gd`): per-chunk MultiMesh vegetation by species, rocks by geology (Ojców limestone pillars), Irish hedgerows / dry-stone walls (also along the road), city blocks set back from the road, landmarks outside the play area (village, distant volcano, castle on a limestone crag, mountain hut, lighthouse, tower-house ruin, harbour expressway, skyline), ONE venue next to the start sized by event mode (pit building with 3 bays + race-control tower + ambulance / fire engine for club / pro, tents, flags, start gantry, grandstand for pro). Safety strip: nothing solid within verge + barrier strip + 6 m of the road.
- **Open point-to-point routes**: Track DNA `topology: "open"` (own sampling + validation), start line inside the first tile, finish line before the end, end-cap barriers (visual + collision), one-lap race. Closed loops unchanged.
- **Race on terrain**: same world rebuilt from the saved descriptor; car height = road height, nose pitch with the grade, chase camera follows the grade and never goes inside the terrain, skid marks at road height.
- **Developer Mode > ELEVATION PHYSICS**: GRADE FORCE 0 / 25 / 50 / 75 / 100 % (g*sin(slope) along the road, integrated inside the drive-model substeps; 0 % default = the flat arcade handling, bit-identical golden trace), CAMERA PITCH, BANKING / BODY ROLL (visual), GROUNDING SNAP / SMOOTH, SUSPENSION (visual), TELEMETRY overlay. Switchable any time, no regeneration.
- Track DNA validator: broad-phase spatial grid for the pair tests (same pairs in the same order, identical results; 756 ms -> 56 ms on a 900-sample track).
- Compatibility: legacy flat tracks and Phase A builder tracks load exactly as before (no heights, no terrain); the Phase A 3D tile builder and the node editor are unchanged.
- Tests (all registered): terrain_world_test, terrain_scenery_test, terrain_builder_test, terrain_physics_test. Captures: tests/capture_terrain.gd, tests/capture_terrain_seeds.gd.
- NOT RUN: phone / browser frame rate and memory on real devices, owner's visual approval.
- Android versionCode 25 / versionName 0.1.25.

## [0.1.24] — Car Factory prototype: E30 Blessed (Blender -> GLB -> Godot)  — TEST BUILD for visual review
- Car Design & 3D Production Audit saved in the repo: docs/car_factory/CAR_FACTORY_AUDIT.md (approved for testing: Premium Die-Cast + Nitro Rules, Blender + Python + GLB + Godot).
- **New pipeline** `tools/car_factory/` (bpy 5.3.0): shared library `nwcf.py` (lofts, lathes, tubes, panel-gap strips, Manifold booleans, solidify, atlas + livery UVs, 3 runtime materials, GLB export, outline validation, build reports), `build_e30_blessed.py`, `build_wheels.py`, camera-match comparison tools (`compare/`).
- **E30 Blessed** (`e30` in the garage, 4th car): four-door E30 sedan, factory dimensions 4.325 x 1.645 m / wheelbase 2.570 m, lowered, quad lamps + kidney grille, black bumpers / strip / frames, see-through tinted glass with seats, wheel and roll cage, blank plates, no logos. One GLB for garage and race; 3 body materials (paint / atlas / glass) -> 8 draw calls with wheels and shadow (Lada 32, RYU-32 33); 28.7 k body + 4 x 2.4 k wheel triangles; Godot's import LOD brings it to ~16.6 k primitives at race distance (measured in GL Compatibility).
- Compared with the owner's photos by solving each photo camera from keypoints (RMS 2.4-2.6% of the keypoint span); rear bumper height and exhaust position corrected from the overlays. Photos are NOT committed (public repo, third-party images): manifest with sha256 in assets/references/drafts/e30_blessed_v0.1/.
- **Wheels as separate assets:** SIGNATURE (source-matched approximation; exact design unconfirmed) and NW DEEP DISH, shared hub convention, wheels.json catalog.
- **Garage prototype:** SIGNATURE / PAINT / WHEELS row (6 paint presets with solid / metallic / pearl finishes, 2 wheel designs), live preview, saved per car in the garage file, separate from handling. `CARS.select()` no longer wipes other garage-file sections.
- **Profiles:** `cars/e30_blessed.json` — handling = Lada baseline + confirmed factory wheelbase only (research JSON tuning recorded as NOT applied, needs A/B); engine = M52B28 inline six, naturally aspirated, even 1-5-3-6-2-4 firing on two 3-into-1 manifolds. Lada and RYU-32 untouched.
- New shaders `nitro_car_atlas.gdshader`, `nitro_car_glass.gdshader`; new car script `glb_car.gd`, cosmetics `car_cosmetics.gd`.
- Tests: new `e30_factory_car_test`; `editor_results_test` now clears its own QA records (a second local run used to fail). Dev tools: `car_perf_probe.gd`, `car_camera_match_render.gd`, capture shots `garage_e30`, `garage_e30_custom`, `race_e30`, `race_e30_chase`.
- NOT RUN: phone / browser FPS and memory, steering-lock clearance in motion, owner's visual approval.
- Android versionCode 24 / versionName 0.1.24.

## [0.1.23] — Procedural world, Phase A: Japan Drift Town vertical slice  — TEST BUILD for visual review
- Per docs/research/procedural_world/NITRO_PROCEDURAL_WORLD_BIBLE.md, **Phase A only** (report: docs/research/procedural_world/PHASE_A_REPORT.md).
- New shared generator (builder + race): `scenery_rules.gd` (analytic road field from the builder tiles, lots, fences, greenery, rows, module keys, deterministic hash), `scenery_modules.gd` (hand-modelled stand-alone garage, joining workshop row pieces with a continuous roof and fascia, 2x1 workshop roof sign, fence runs, rounded concrete aprons, street lamps; tree art shared with the race), `procedural_world.gd` (incremental chunk rebuilds).
- Adjacency: a stand-alone garage becomes one 2x1 workshop when the road grows next to it and goes back when the tile is removed / UNDOne.
- Race: a built track saves `world: {theme, seed, version}`; the race rebuilds exactly the same world from the tiles (no extra roadside trees). Track DNA, road geometry, walls, physics and scoring unchanged; a road reshaped in the node editor keeps no tile world.
- Track Builder: compact floating bar with FIT, camera framed on the occupied track, pinch zoom + two-finger pan (no accidental painting), same eight buttons in the same order in two bottom rows.
- Tests: new procedural_world_test; track_builder_test extended. Whole suite PASS, physics golden unchanged.
- NOT RUN: Android / Web frame rate and memory with the world.
- Android versionCode 23 / versionName 0.1.23.

## [0.1.22] — Owner screenshot feedback: HUD header, handbrake, results, camera 0  — TEST BUILD
- results: this run's TIME in yellow, and this run's row in YOUR TOP RUNS highlighted yellow (points, time, THIS RUN) instead of the accent colour;
- HUD: LAP moved beside the minimap ("LAP" over "1/3", left of the camera keep-out); track name larger (hh x 0.15, fitted); chase line (FIRST RUN / CHASING / BEATING) drawn straight on the header, no frame inside the frame; race clock larger; speedometer lower (0.585 h -> 0.63 h, still clear of the joystick);
- handbrake: NW engraving centred in the base box; the box frame is now like every other control (thin edge, neon only on the lower-right corner);
- **camera 0 (top-down) 20% further out**: orthographic base size 60 -> 72 (portrait), 72 -> 86.4 (landscape); speed zoom curve, lead and framing unchanged. A/B: same capture scripts before/after (RYU at start, Lada drifting), docs/QA_MATRIX.md. Chase camera unchanged. Physics unchanged.
- From now on every build sent for testing gets its own version number (v0.1.21 had been reused for three pushes).
- Android versionCode 22 / versionName 0.1.22.

## [0.1.21] — Audio cleanup, editor polish, HUD/garage fixes, realistic engine synth  — TEST BUILD, sound not yet approved
Owner brief v0.1.21 (P0 audio, P1 editor / HUD / garage, P2 track selection) on top of the first v0.1.21 push.
- **P0 audio, brief follow-up:**
  - original 17 OGG + 17 WAV masters + manifest + catalogue **archived** in `archive/recorded_sfx/` (outside `game/`, so never imported or exported); nothing recorded inside the game except the music; new `audio_regression_test.gd` fails if a recorded clip reappears or a race holds any audio player besides the synth;
  - **no rev flares while slowing down:** off the throttle the gearbox no longer drops gears (the engine winds down in gear, clutch in near a stop). Braking 120 -> 0 km/h: max rev rise +0 rpm (was up to +4300 rpm with the old speed map; in-game at 26 km/h braking 2300 rpm instead of 5182). On the throttle (drifts, kick-down) unchanged;
  - tyre squeal -2.5 dB and the same level for both cars (was scaled by engine loudness, V8 squeal was 3 dB under its engine);
  - music default 0.6 -> 0.45 (about -26 LUFS in game: ~1 dB under an idling engine, ~9 dB under the car driving; was louder than the idle). Still no ducking or adaptation; untouched old 0.6 settings move once;
  - pause freezes the sound exactly (no reset to idle, no rev jump on resume); restart clears every transient (crackle window, ignition cut, pops, impact, counters);
  - the player's car choice now survives an app restart even when going straight to DRIVE (it was only read when the garage was opened, so the race fell back to the red Lada);
  - generator playback released on exit (fewer leak warnings in headless tests).
- **P1 track editor:**
  - the editor draws the **real road** the race builds (same spline, width, edge lines where the barriers stand, start/finish line at node 0 with a direction arrow) instead of straight lines between nodes;
  - **every** problem is found (the validator stopped at the first): exact stretch of each too-tight corner, both stretches of too-close roads with the gap drawn and measured, crossings marked; status says "2 PROBLEMS • CORNER TOO TIGHT (11 m, needs 16 m)";
  - **AUTO-SMOOTH improved, not duplicated** (`NitroTrackDNA.repair`): tight corners relax only the knots that shape them, too-close roads are pushed apart, stacked knots separated; knots elsewhere keep their exact coordinates; no node moves more than 18% of the track size (else it says so); a real figure-eight is reported, never "fixed"; reports how many nodes moved and how far;
  - touch: finger-sized targets (6% of the short side), bigger nodes, dragged nodes keep the finger offset (no jump), a ring around the node being dragged, the finger left after a pinch keeps panning;
  - SAVE AS writes full float precision, re-reads the file and verifies the compiled road equals the editor's; the editor then keeps editing exactly what the file holds;
  - new `editor_geometry_test.gd`: complex shapes, two hairpins (two separate reports), close sections, figure-eight, stacked knots, closed-loop integrity, SAVE AS, race road == editor preview (edges, width, start), touch.
- **P1 HUD / camera / garage:** small HUD labels grew ~35-45% (BANKED SCORE, COMBO, PTS TO BANK, track name: from ~1.1 mm to ~1.6 mm on a phone); speedometer no longer overlaps the joystick on 3:4 tablets and in landscape (phones unchanged); new `hud_layout_test.gd` (11 screens, overlaps + minimum text sizes); camera test drives both cars: same zoom at the same speed, car in view in both cameras; garage preview == race model (same factory) checked per variant.
- **P2 track selection / flow:** DRIVE lists built-in CIRCUITS, then MY TRACKS (every saved editor / builder track, newest first, accent-framed, length, best score, EDIT button), then QUICK (random); scrolls when long. Results of a player track offer EDIT TRACK (editor -> race -> results -> editor). Local leaderboards and three-lap stats unchanged. Per-car rankings: reviewed, not implemented (runs are stored per track; adding the car id to each run record is the way, see HANDOFF).

First v0.1.21 push:
- **Recorded sound effects removed (owner's decision):** the 17 OGG clips, the 13 processed cuts, `sfx_spec.json`, `manifest.json`, the WAV masters (`audio_masters/`), `tools/build_sfx.py`, `docs/audio/SFX_CATALOG.md`, `sfx_mixer_test.gd`, the car profiles' `sfx` blocks and the DEVELOPER "AUDIO: SYNTH ONLY / SYNTH + RECORDED FX" switch. Car sound = the synth alone again (engine, tyre squeal, wall scrape, impacts), like before v0.1.19; the v0.1.20 road-noise layer is gone too. They remain in git history. `drive_audio.gd` is back to a thin synth driver; AUDIO DEBUG OVERLAY now shows the synth state.
- **Engine synth rebuilt for realism** (`engine_synth.gd`, still per-sample GDScript, no samples):
  - exhaust acoustics as waveguides: a header pipe per bank (quarter-wave modes) and a tail pipe (half-wave modes), with lossy reflections, so the timbre sweeps with rpm like a real exhaust;
  - cycle-to-cycle variation: every combustion lands a little early/late and burns a little stronger/weaker; crank speed wanders (most at idle) — no frozen, perfectly periodic tone;
  - turbulent jet noise at the pipe exit, breathing with every pulse: the 1-4 kHz "rasp" a recording has (measured against the owner's real limiter recording: 2 kHz was 13 dB too dark, high band far too periodic);
  - rounded blow-down pulse attack, valvetrain / timing-chain tick (heard at idle), overrun lean misfires (decel burble), soft saturation, stereo early reflections (L/R correlation ~0.97, mono-safe);
  - RYU-32 V8: firing slots on two banks (1UZ order 1-8-4-3-6-5-7-2), unequal headers and a 0.5 m longer run from one bank -> cross-plane burble (cycle harmonics between the firing harmonics 2.5x the even-bank engine).
  - Per-car keys in the profile `engine` block: `bank`, `header_m`, `bank_lag_m`, `tail_m`, `header_reflect`, `tail_reflect`, `pipe_damp_hz`, `jet`, `jitter_idle`, `jitter_high`, `wander`, `misfire`, `mech`, `mech_hz`, `room` (docs/CAR_PROFILES.md). RYU loudness 1.3 -> 1.2 to keep the old Lada/RYU level gap.
- **Physics, camera, scoring and HUD unchanged:** the golden physics trace is still bit-identical. The Lada engine-sound fingerprint was re-recorded once for the new model (documented in car_profiles_test.gd) and still proves Lada JSON == synth defaults.
- **Tests:** engine_audio_test gained five realism checks, each against the same synth with that feature switched off (cycle change 0.93 vs frozen 0.24, V8 burble 2.49 vs even banks 0.76, 38 coast misfires / 0 at full load, idle tick x2.96, L/R 0.977). garage_audio_test checks that no recorded SFX ship; main_menu_test that the audio-mode switch is gone.
- **CPU:** 36-40 ms per second of audio in the container (was ~25 ms; ~4% of one core). Editor: preview spline 0.3 ms per drag step; validate + diagnose on release 90 + 84 ms for a 28-node circuit. Android / Web: NOT RUN — use DEVELOPER > AUDIO BENCHMARK.
- **Not approved yet:** owner listening on Android, both cars. Before/after engine demos and in-game Movie Maker recordings (music muted) were produced for listening.
- Android versionCode 21 / versionName 0.1.21.

## [0.1.20] — AUDIO HOTFIX (P0) + background music  — TEST BUILD, audio not yet approved
- **Root causes found** (docs/audio/SFX_AUDIT.md): `exhaust_pops` restarted on every physics tick while afterfire > 0.9 (14 restarts per lift-off, reproduced by the negative control); clips were played whole (4-7 s) although the useful sound sits in the middle (e.g. handbrake squeal 1.9 s late); "single" clips contain several events; loops were not loopable (drift squeal dropped out every 7 s); `tyre_rolling` / `tyre_corner` contain engine hum, not tyres; `engine_limiter` is 7 s of continuous engine fighting the synth; few cooldowns, no priorities.
- **All 17 clips audited** (length, silence, LUFS, clipping, spectrogram content, event region). 13 are used as cuts of the owner's WAV masters (`sfx_spec.json` -> `tools/build_sfx.py` -> `assets/audio/processed/`, seamless loops, fades, -3 dBFS peaks, 0.2 MB); 4 are not used, with the reason documented. The original files are untouched.
- **New mixer** (`drive_audio.gd`): one gate for every recorded one-shot — edge-triggered events, per-clip cooldown, no restart while playing, exclusive groups (tyre / turbo / exhaust / wall / kerb) with priorities, max 3 simultaneous one-shots. Exhaust pops fire exactly once per afterfire window. Kerb rumble once per kerb entry. Regrip once when a real drift (>= 0.6 s, with hysteresis) ends. Wall slide is a loop following the sliding speed. Drift squeal is a loop following slip; a new synth road-noise layer replaces the hum-filled rolling clip and ducks smoothly while drifting.
- **Engine-specific effects:** car profiles gained an `sfx` block. Lada I4 (turbo) uses spool / blow-off; RYU-32 V8 (NA) never plays turbo clips and plays the exhaust pops lower (pitch 0.78). Tyre / wall / kerb / wind effects are shared.
- **DEVELOPER:** AUDIO: SYNTH ONLY / SYNTH + RECORDED FX (comparison), AUDIO DEBUG OVERLAY (engine state, active loops and one-shots, last PLAY / BLOCK / STOP decisions with reasons).
- **Background music:** original track "Night Drift" (tools/compose_music.py: 120 BPM, A minor, dark pads, layered 808, half-time drums, formant chops), loops plainly in menus and races (no adaptation, owner's choice), MUSIC slider in SETTINGS and pause. 1.7 MB.
- Physics, camera, scoring and HUD unchanged; car profiles still bit-identical (car_profiles_test). New `sfx_mixer_test.gd` with negative control (old behaviour -> "exhaust_pops played 14").
- **Not approved yet:** listening on Android by the owner is required (unit tests cannot approve audio). Movie Maker recordings of the real game mix for both cars in both modes were produced for listening.
- Android versionCode 20 / versionName 0.1.20.

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

## 0.1.40 • judged event workshop (test branch)
Terrain Builder roads support Practice, Club Event and Pro Event. ROUTE defaults to 12 m road, LOOP retains the 24 m circuit. MY TRACKS includes an editable Ojców workshop example. Judged runs add earned technical points to the active chain. Prototype results are session-only.

## Issue 19 water review on the 0.1.40 Workshop
Ojców stream height now accounts for the full road and bridge footprint on both 12 m routes and 24 m circuits. Water transitions back to its natural height outside each crossing.
