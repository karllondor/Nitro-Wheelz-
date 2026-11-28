# Issue #66 — scoring callout colours only (Claude Sonnet handoff)

```text
ISSUE / CLAIM / OWNER: #66; CLAIM issuecomment-7236405325; owner karllondor
MODEL / TOOL VERSIONS: Claude Sonnet (claude-sonnet-5-5); Godot v4.7.2.stable.official.ed1daf0bf (headless + xvfb opengl3 for the frames)
BASE BRANCH + SHA: integration/stable-mobile-qa @ 9c827cd3e8ef62ddc0d68f7e72f3f1c4bad128b2 (PR #70 head, v0.1.53 / code 53), refreshed before branching
WORK BRANCH + HEAD SHA: fix/scoring-feedback-palette-only — exact SHA in the draft PR
OTHER OPEN PRs REVIEWED: #69, #70, #71 (docs), #64 (Forest Lab, not touched)
PATHS TOUCHED: game/scripts/ui/race_hud.gd (callout_color + outline opacity), NEW game/scripts/ui/scoring_palette.gd,
  NEW game/tests/scoring_palette_test.gd, NEW game/tests/capture_scoring_palette.gd, tools/run_godot_checks.sh (+1 spec), evidence + this file
PATHS NOT TOUCHED: drift_scorer.gd, event_judge.gd, race.gd (byte-identical to the base), collision / zones / awards / timing,
  Forest Lab, menus, VERSION / versionCode / package / signing / CI APK identity, workflows
```

## What was wrong
`race_hud.gd _draw_callouts` coloured a callout red when its text contained LOST, gold when it began with BANKED and otherwise
with `STYLE.PINK_SOFT`, which follows the player's HUD accent. With the RED accent every bonus (TRANSITION, KERB CLIP, zone
bonuses) looked like a loss (see `evidence/scoring-palette/day_red_accent_white_cloud.jpg`, left).

## What changed (presentation only)
| Category | Colour | Texts the game prints today |
|---|---|---|
| PENALTY | RED `(1, .42, .42)` (unchanged value) | `WALL!  CHAIN LOST`, `SPIN!  CHAIN LOST`, `MISSED <zone>` |
| BANKED | GOLD `STYLE.GOLD` (unchanged value) | `BANKED  +N` |
| BONUS | NITRO VIOLET `#9774C8` (the colour suggested in #66) | `TRANSITION  +0.25x`, `KERB CLIP  x1.5`, `INIT / FLICK / OUTSIDE / CLIP  +20`, `WALL KISS  +12` |
| INFO | WHITE | anything else |

* `scoring_palette.gd` classifies from the event text on the HUD side, because the scorer / judge files are out of scope. An explicit
  `"category"` key on an event wins, so a later change to the scorer can pass the category without touching the HUD again.
* `WALL KISS +12` says WALL but is a positive extra: it is VIOLET, not red (a substring rule would get this wrong; a test pins it).
* The accent still colours the rest of the HUD; only the callouts are fixed. Texts are unchanged, so meaning never depends on colour alone.
* **Outline opacity 0.65 → 0.85** for all callouts. Reason found by the new test: with the old outline the violet reached only ~1.9:1 against
  the (outline-darkened) white cloud in DAY. With 0.85 it is >= 4:1 on every lighting preset's sky and on white cloud. This is a visible
  change to all four colours' outline (slightly darker), **pending the owner's look on the phone**. If the owner prefers the old outline,
  a lighter violet (e.g. `#B497EE`, ~2.9:1 at 0.65) is the alternative; the test will say which combination is acceptable.

## Tests
* NEW `scoring_palette_test` (in `tools/run_godot_checks.sh`):
  * reads the literal `_event("…")` texts of `drift_scorer.gd` and `event_judge.gd` — an unknown / unclassified new event text fails the suite;
  * classification samples for every printed text, explicit category and invalid category;
  * `hud.callout_color` for all six accents (pink, violet, cyan, lime, orange, red) returns the fixed colours; a bonus is never close to the loss colour;
  * the four colours are distinct (>= 0.30 RGB distance) and >= 4.5:1 on the dark outline; >= 3:1 against the outline-darkened DAWN, DAY (+ white cloud),
    GOLDEN HOUR and NIGHT sky and horizon colours of `race_environment.gd`;
  * the REAL `NitroDriftScorer` is driven through TRANSITION, KERB CLIP, BANKED and a WALL hit: its event texts classify correctly and its numbers
    `[total, banked, lost, transitions, clips, best chain] = [717, 1, 1, 1, 1, 717]` equal the base values (scorer file byte-identical).
* Mutation checks (each made the test FAIL): bonus colour follows the accent again; `WALL` as a penalty substring; a new unclassified scorer event text.
* NOT RUN: owner phone; a full race frame over the real 3D scene (the frames show the real HUD over the lighting presets' sky colours, not the 3D world).

## Evidence
`docs/dev/handoffs/evidence/scoring-palette/` — `before_after_presets_accents.jpg` (4 presets × accents pink / red / cyan, left = base `9c827cd`,
right = this branch) and `day_red_accent_white_cloud.jpg` (the reported case, DAY + red accent + white cloud). Capture tool:
`game/tests/capture_scoring_palette.gd` (OUT_DIR, TAG, optional ONLY=DAY).

## Next safe action
Owner looks at a drift with a bonus, a banked chain and a wall hit on the phone (any accent); then the integration owner folds this PR into
`integration/stable-mobile-qa` and raises versionCode (54). No APK is built from this branch for installation.
