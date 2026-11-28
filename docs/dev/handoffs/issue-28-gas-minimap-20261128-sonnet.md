# Issue #28 — GAS slanted face + pressed look, solid red minimap dot (Claude Sonnet handoff)

```text
ISSUE / CLAIM / OWNER: #28 (owner small HUD polish, comment 7230466162; v0.1.50 polish 7215120395; #25 GAS follow-up); CLAIM issuecomment-7236595116; owner karllondor
MODEL / TOOL VERSIONS: Claude Sonnet (claude-sonnet-5-5); Godot v4.7.2.stable.official.ed1daf0bf (headless + xvfb opengl3 for the frames)
BASE BRANCH + SHA: integration/stable-mobile-qa @ 9c827cd3e8ef62ddc0d68f7e72f3f1c4bad128b2 (PR #70 head, v0.1.53 / code 53)
WORK BRANCH + HEAD SHA: fix/hud-gas-face-minimap-marker — exact SHA in the draft PR
OTHER OPEN PRs REVIEWED: #69, #70, #71, #72 (scoring colours: other hunks of race_hud.gd)
PATHS TOUCHED: game/scripts/ui/race_touch.gd (pedal DRAWING only), game/scripts/ui/race_hud.gd (_minimap player marker only),
  NEW game/tests/gas_pedal_visual_test.gd, NEW game/tests/minimap_marker_test.gd, NEW game/tests/capture_hud_gas_minimap.gd,
  tools/run_godot_checks.sh (+2 specs), evidence + this file
PATHS NOT TOUCHED: _layout / _zone_at / gas_shape / all input code, brake, handbrake, joystick, physics, menus, boot.gd, garage,
  dialogs, scrolling, scoring, VERSION / versionCode / package / signing / CI APK identity
```

## GAS pedal
**Owner request:** restore the slanted mechanical face and a visible pressed animation; keep the full-height touch area and the
three-finger input accepted on v0.1.50; no mutation of the hit polygon while animating.

* The hit polygon (`gas_shape`) and every other layout rectangle are **byte-identical** to the base: sha256 of
  gas / gas_shape / brake / drift / joystick for eight screen sizes = `0d99d501…d725` on the base and on this branch (pinned in the test).
* The visible pedal is now `NitroRaceTouch.gas_visual(gas_rect, hit_shape, press)`: a parallelogram face leaning like the BRAKE
  (`PEDAL_SKEW`), a depth plate under it, drawn strictly inside the hit polygon (the inset is computed until every point is inside, so
  the picture never promises more than the touch area gives).
* `press` (0..1) pushes the face down onto the plate (the plate and the hit polygon do not move). It follows the input state
  (`throttle`) through `gas_press`, smoothed at 12 / s, so the animation never gates the input: the touch sets `throttle`
  immediately, the face sinks over ~80 ms and lifts after release. Pressed also lights the pink edge as before.
* Look: see `evidence/gas-minimap/gas_before_after.jpg` (DAWN / DAY / NIGHT, rest and pressed, left = base, right = this branch).
  The visible face is a little narrower than the hit area (by the lean); the hit area itself did not change.

## Minimap marker
**Owner request:** solid RED marker, no white stroke, independent of the HUD accent; start / finish marks and the white route
line stay visible.

* The dot is drawn from `NitroRaceHUD.map_marker_spec(u)`: a soft dark halo (`#000` @ 0.45, 10 u) under a solid red disc
  `Color(1.0, 0.10, 0.10)` of 7 u (was a pink 5.5 u dot with a white ring). Same red for all six accents and Club / Pro.
  Contrast >= 3:1 against the white route line, black and the HUD glass panel.
* `evidence/gas-minimap/minimap_closeup_night.jpg` and `minimap_before_after.jpg` (accents pink and cyan, DAWN / DAY / NIGHT).

## Tests (new, in `tools/run_godot_checks.sh`)
* `gas_pedal_visual_test`: layout hash; face inside the hit polygon at rest and pressed on eight sizes; lean like the BRAKE; large
  (>= 72 % of the width, >= 85 % of the height, face + plate >= 90 %); visible gradual sink onto a fixed plate; hit polygon unchanged
  by any press value; throttle immediate, press follows and releases; three-pointer steer + GAS + handbrake.
* `minimap_marker_test`: solid red, no light stroke, bigger than before, identical for six accents and three UI scales, contrast, the
  drawing code uses the spec and no longer strokes the dot, the white route line and START / FINISH remain.
* Existing `gas_pedal_shape_test` and `hud_layout_test` still pass.
* Mutation checks (each made a test FAIL): face spilling outside the hit polygon; unslanted face; no press travel; shrunk hit polygon;
  animation gating the input; minimap dot following the accent; white stroke back; white halo.

## NOT RUN
Owner phone (feel of the press, slant, dot visibility); the whole screen over the real 3D scene (frames use the real classes over the
lighting presets' sky colours); the question of the OS status / navigation bars overlapping the HUD (#28, v0.1.50 screenshots) — not
investigated here, no evidence of a reproducible safe-inset bug.

## Next safe action
Owner looks at GAS (rest, pressed, edge drag, steer + GAS + handbrake) and the minimap dot in one race; then the integration owner folds
this PR (and #72) into `integration/stable-mobile-qa` and raises versionCode. No APK is built from this branch for installation.
