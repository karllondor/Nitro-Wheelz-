# Issues #67 / #68 — stable mobile QA integration (v0.1.53) — Claude Opus handoff

```text
ISSUE / OWNER: #67 stable integration, #68 one-APK policy; owner karllondor
MODEL / TOOL VERSIONS: Claude Opus (claude-opus-5-5); Godot v4.7.2.stable.official.ed1daf0bf; keytool (OpenJDK) for certificates
BASE: fix/android-ux-rescue-v0152 (v0.1.52, #65/#59), itself on PR #63 head b3a2cab
WORK BRANCH: integration/stable-mobile-qa — exact SHA in its draft PR / #67 report
NOT TOUCHED: scoring, drift zones, vehicle physics; main; no release
```

## PR DAG audit (28 Nov 2026, remote heads)

| PR | Branch @ head | Version / code | Package in CI | In this candidate? |
|---|---|---|---|---|
| — | `main` @ 018efa1 | 0.1.6 / 7 | `com.karllondor.nitrowheelz` | base of history only (stale) |
| — | `integration/nitro-dev` @ 9d3aab0 | 0.1.45 / 45 | `.dev` | yes (ancestor) |
| #42 / #43 | `feat/park-stunt-physics` @ 2766452, `feat/park-vehicle-damage` @ 6964b90 | 0.1.45 | `.review.pr<N>` | yes (ancestors via #44) |
| #44 | `integration/park-unified-rc` @ 3f4f4c6 | 0.1.48 / 48 | `.review.pr44` | yes |
| #45 | `feat/three-circuits-v0149` @ 7865d41 | 0.1.49 / 49 | `.review.pr45` | yes |
| #58 | `fix/qa-hotfix-v0150` @ 73a03ca | 0.1.50 / 50 | `.review.pr45` | yes |
| #63 | `feat/my-tracks-management-v0151` @ b3a2cab | 0.1.51 / 51 | `.review.pr45` | yes |
| (new) | `fix/android-ux-rescue-v0152` | 0.1.52 / 52 | `.review.pr45` | yes |
| #64 | `feat/sonnet-forest-lab` @ 4df2461 | 0.1.50 / 50 | `.forestlab` | merged as DEVELOPER-only, default CLASSIC; `.forestlab` lane removed |
| #39 / #40 / #41 | multiplayer v2 / park v2 / park multiplayer | — | — | yes (ancestors of #63) |
| #36, #35, #38 | PC/Web HUD, Linux/Web QA, visual lab Fuji AE86 | — | — | not ancestors by git; the PC/Web HUD content was integrated in v0.1.48 per its changelog; #38 NOT included |
| #66 | Sonnet scoring colours | — | — | no branch exists yet — integrate when Sonnet opens it |

Signing: every QA build since v0.1.50 uses the persistent key (CI log of run 46024506424: "SIGNING: persistent debug key");
certificate read from the v0.1.51 APK: SHA-256 `CD:1A:…:7B:E2` (`tools/apk_identity.py`).

## What was integrated

* v0.1.52 Android UI rescue (see `issue-65-20261128-claude.md`).
* Forest Lab (#54, PR #64): `scripts/world/forest_lab/*`, the shader, Tree Designer scene, 3 tests, the terrain_scenery hook,
  DEVELOPER > FOREST LAB / FOREST DENSITY / TREE DESIGNER. Merge conflicts: CHANGELOG (both kept), run_godot_checks spec
  list (union). Removed: the `.forestlab` package and artifact lane. Added: a CLASSIC no-cost assertion in
  `terrain_forest_lab_test.gd` (no lab material, mesh or chunk is built in CLASSIC), Android BACK for the designer.
* ONE QA channel: `tools/qa_channel.env`, workflow lane + identity check, docs `docs/dev/QA_CHANNEL.md`.

## Recommended safe path for `main` (needs owner approval, NOT done)

`main` is at v0.1.6; every later version lives on the stacked PR chain. Recommended: after owner phone PASS of this
candidate, open ONE PR `integration/stable-mobile-qa` → `main` (merge commit, no squash, so the chain history and
per-PR SHAs stay traceable), tag it `qa-v0.1.53`, then close the superseded draft PRs (#44, #45, #58, #63, #64, the
v0.1.52 PR) with a link to that PR. The production package `com.karllondor.nitrowheelz` is NOT switched until a
separate release decision.
