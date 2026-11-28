# v0.1.54 final integration — report (Claude Opus)

```text
BRANCH: integration/stable-mobile-qa (PR #70) — exact SHA in the PR / #67 report
BASE: 9c827cd (v0.1.53, owner phone QA: all PASS except system BACK)
MERGED (merge commits, no squash): PR #72 7e87cb8 (scoring colours), PR #73 e72a086 (GAS + minimap), PR #71 9c295df (owner QA record)
CONFLICTS: tools/run_godot_checks.sh spec list (union kept: scoring_palette_test, gas_pedal_visual_test, minimap_marker_test).
  race_hud.gd auto-merged; both changes verified present (callout_color + OUTLINE_ALPHA, map_marker_spec).
```

| Area | Change in v0.1.54 | Proof |
|---|---|---|
| P0 system BACK | debounce 350 ms, two-press exit on the main menu, persistent BACK / pause log on DEVELOPER | `issue-65-back-20261128-claude.md`, headless test + mutation checks, emulator API 35 + 36 with navigation ON and gesture back |
| P1 scoring colours | from PR #72 unchanged | `scoring_palette_test` (scorer numbers identical, 6 accents, 4 presets) |
| P2 GAS + minimap | from PR #73 unchanged | `gas_pedal_visual_test` (touch layout hash identical), `minimap_marker_test` |
| P3 approved features | untouched: My Tracks, OPEN / SAVE / SAVE AS / RENAME / DELETE, results, garage, stars / PBs, HUD, circuits, builders, Park, LAN, time of day, physics; Forest Lab DEVELOPER-only, CLASSIC default (no-cost assertion) | full Godot suite |
| P4 one APK | `com.karllondor.nitrowheelz.review.pr45`, same certificate, 0.1.54 / 54, `QA_LAST_VERSION_CODE=53`; PRs into the QA branch no longer upload an installable APK | CI identity step, emulator upgrade from the owner's signed v0.1.53 |
| CI hygiene | tesseract OCR timeout 10 → 30 s (two flakes on PR #70 / #72) | — |

Remaining / not proven: owner phone for BACK (the cause on the phone is not reproduced; see the BACK handoff), GAS feel, colours on
the phone; Race setup BACK goes to the main menu (track selection is opened from Race setup; going back to it would loop) — owner may
want a different rule; #62 repeated KERB CLIP after WALL (deferred); #38 / #36 / #35 / #15 not part of this build.
Promotion plan: `docs/dev/MAIN_PROMOTION_PLAN.md`.
