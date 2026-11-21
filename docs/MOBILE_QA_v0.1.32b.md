# Nitro Wheelz v0.1.32b — owner phone feedback / QA handoff

**Status: candidate code on agent branch. Android/phone visual verification NOT RUN.**
Based on the owner's 21 November 2026 screenshots of v0.1.32. This document distinguishes proven code defects, defensive safeguards and aesthetic follow-ups. The earlier mobile QA report stays historical.

## A. First-drift rear wheel anomaly — OPEN ON PHONE

Observed: on the **first drift after loading a circuit**, black wheel-like shapes appear beside or behind the rear axle. The owner sees it in the top-down and Follow/Chase camera. A later run may differ. Images are supplied in the project conversation (do not treat the prior automated yaw result as proof of resolution).

**Current finding:** the v0.1.32 wheel_visual_test measured the rear rolling-pivot yaw at 0 degrees on all tested models. It does not measure each wheel mesh's projected silhouette, sidewall plane, or visible geometry on the Android renderer. Root cause remains unconfirmed.

Defensive code in v0.1.32b: factory GLB rear hub yaw is set explicitly to 0 every motion update, and wheel roll phases are wrapped within -PI..PI. This does not change car handling and does NOT count as a phone-verified fix.

**Acceptance test on the actual phone:** cold-launch the APK, select RYU-32 GLB, start Shin-Kawa and a terrain circuit, initiate the FIRST drift; take two screenshots before and during the wheel anomaly in both TOP-DOWN and CHASE. Repeat after RESTART and after switching cars. Enable DEVELOPER > TOUCH DIAGNOSTICS and record FL/FR/RL/RR values and a screenshot. If rear angles remain 0 but visible tyre plane moves, inspect GLB wheel root transforms, left/right face mapping, camber, wheel clearance and Android rendering, rather than modifying driving physics. Do not mark FIXED until visual confirmation.

## B. Player-visible Car Factory models

Default normal garage/race car for LADA RED, LADA WHITE and RYU-32 is the Blender GLB. E30 stays GLB. An opt-out comparison (DEVELOPER > CAR FACTORY GLB CARS: OFF) exposes the older procedural versions for diagnostics; an obsolete saved factory_test_models=false is ignored so existing installations see the new default. Physics, sounds and collisions remain unchanged.

The same per-car paint and wheel selection is applied in garage preview and race. Palette data live outside generated GLB JSON in game/cars/car_factory_cosmetics.json. LADA RED and WHITE have separate saved variants and signature presets; RYU-32's BLUE + STRIPES is a paint preset, not another vehicle or GLB. The stripes use the **existing provisional texture**, pending approved art.

Phone acceptance: change PAINT then WHEELS on EACH car, DRIVE, finish, return to garage, relaunch APK; choices persist with no shape/scale changes. SIGNATURE restores the per-variant original. DEVELOPER legacy fallback should only change appearance. Test RYU clean/striped and ensure only one GLB is loaded.

## C. Local top runs: rank | driver | car | points | stars | time

The top runs are **local device history**, not an online/multi-player leaderboard. The driver's nickname is editable in SETTINGS, saved locally, max 16 characters. Every new run stores the driver name and exact car variant at finish; older records without metadata visibly say UNKNOWN instead of being retroactively assigned to a current car. Date remains in underlying records for stable history but is not displayed. Rankings remain sorted by points, then time. The current run gets gold emphasis.

Phone acceptance: set a driver name, finish with one car, switch cars and do another run, revisit the same circuit; both rows retain the historical car and name, without date. Check portrait/landscape text and legibility at 690–720 px screen width.

## D. Track visual comparison — DESIGN FOLLOW-UP, NOT YET CODED

Owner finds prior TOP-DOWN Japanese circuit presentation more cohesive than newer wide terrain tracks. Preserve the better car-to-road scale, kerb readability, contrast, camera framing and sense of speed of the older screenshot; keep improved terrain elevation and distinctive scenery from the new system. Avoid identical wide empty road spans, default lookalike roadside scenery and generic houses. This is a targeted art/camera audit, **not** approval to revert terrain-first generation, change track layouts or overwrite approved references.

Required A/B: old vs new on the same phone and similar camera zoom, with matchable elevation/lighting. QA needs a designer-approved before/after rather than aesthetic assertions from code.

## Tests and release policy

- Static code inspection: completed; no Godot executable in this session.
- Godot import, automated GDScript tests, Android installation/first-drift camera QA: **NOT RUN** in this session.
- CI may run on a PR branch. Inspect its actual result before making release claims.
- Do not overwrite immutable v0.1.32 artifacts. Candidate is labelled v0.1.32b (SemVer prerelease stamp `0.1.32-b.1`). Merge/tag/release only after checks and owner approval.

MODEL: GPT-6.
