# Car quality checklist (v0.1.31)

Tick every line for each car stage; write PASS / FAIL / NOT RUN in the car report. Each line names the solution that
was actually used.

## A. References and decisions
- [ ] Sources listed with a confidence level; missing items requested (e.g. RYU-32 LIVERY) and marked PROVISIONAL.
- [ ] Conflicts resolved explicitly in the report (RYU-32: V8 kept although the sheet draws an inline engine).
- [ ] No logos, badges, plate characters, third-party images in the repo (grille emblems become blank tabs).

## B. Geometry
- [ ] Footprint inside the catalog length / width; wheelbase exact (script validation + `factory_models_test` /
      `e30_factory_car_test`). Overhang split from the references.
- [ ] Silhouette checked against the reference: orthographic overlay for blueprints (`ortho_side` / `ortho_front` /
      `ortho_rear`), camera-matched overlay for photos. A perspective garage shot alone is not a comparison.
- [ ] Tyres inside the arches (outer face vs half width), tucked stance where the reference shows it.
- [ ] Openings read as openings (dark `gap` / `well` swatch), not grey panels.
- [ ] Interior visible through the glass is modelled (seats, dash, wheel, door cards, cage if present); glass is not
      darkened to hide it.
- [ ] Panel gaps / shut lines on doors, bonnet, boot.
- [ ] Engine bay complete when the bonnet is open (inner wings, firewall, slam panel, floor, engine, ancillaries).

## C. One model, variants, looks
- [ ] Same node in garage and race (`CARS.make`), no LOD, nothing hidden while driving.
- [ ] Geometry variants via the UV2 mask; the other variant's faces are masked (test counts hidden triangles > 0).
- [ ] Looks without geometry change via the paint material only (RYU-32 CLEAN / LIVERY share the GLB).

## D. Materials
- [ ] Three body materials converted to the Nitro shaders; `variant_slot` set on all three.
- [ ] Paint colour sampled from the reference; per-variant shading overrides where the default shade shifts the hue
      (Lada WHITE).
- [ ] Chrome / polished vs machined / painted surfaces differ in roughness (horizon reflection reads them apart).
- [ ] Lamps: textured lenses in frames, glow only where the reference shows it lit (Lada sheets yes, E30 no).

## E. Budget and performance
- [ ] ≤ 42 000 triangles per visible car incl. wheels; ≤ 8 draw calls; GLB size recorded.
- [ ] Shader cost noted (e.g. one 3x3 transform + smoothsteps per pixel for the horizon reflection).
- [ ] Phone frame time: NOT RUN unless measured on the owner's phone.

## F. Gameplay untouched
- [ ] `car_profiles_test`: Lada baseline physics bit-identical; RYU-32 V8 profile; handling identical with the test
      switch on / off (`factory_models_test`).
- [ ] Engine sound, scoring, collisions, controls, saves unchanged.

## G. Evidence (`tests/capture_car_views.gd -- <out> <variant> race factory [look]`)
- [ ] BEFORE / AFTER from identical cameras: front 3/4, rear 3/4, left, right, front, rear, top.
- [ ] Garage screen, race top-down, race chase.
- [ ] Close-ups: bonnet / engine bay, A-pillar, grille + lamps, wheel, rear bumper, tail lamp.
- [ ] Orthographic side / front / rear.
- [ ] Sheets written to docs/car_factory/<car>/ (our renders only).

## H. Delivery
- [ ] Full suite PASS locally (`tools/run_godot_checks.sh`; a post-PASS shutdown WARNING is reported, not hidden).
- [ ] New version + versionCode; CHANGELOG, QA_MATRIX, HANDOFF updated; separate revertable commit.
- [ ] CI Android / Web / desktop / godot results linked in QA_MATRIX. "CI built the APK" is not "tested on Android".
- [ ] Owner told where to switch the model on (DEVELOPER) and that it is NOT approved until reviewed.

## Lessons recorded (all cars)
1. Measure (camera match / orthographic overlay / colour sampling) before changing anything.
2. Reflections, not brightness, sell the material.
3. Profiles as data (sections, bumpers, flares) are easy to compare and tune.
4. Budget by trading invisible geometry for visible detail.
5. One QA capture tool for all cars keeps BEFORE / AFTER honest.
6. Presentation (garage framing) is computed from the real model.
7. Atlas and region layouts are append-only; wheel builds can be partial (`--only`).
8. Headless test runs can hang at engine shutdown after PASS; the runner's watchdog reports it instead of masking it.
