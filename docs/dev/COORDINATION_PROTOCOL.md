# Nitro Wheelz — Shared AI Development Protocol v1.0

**Applies to ChatGPT/Codex, Claude Code, automation agents and human developers.**
**Owner:** Karll. **Development integration target:** `ccr-91dad981-53kkbi`, not stale `main`.
**Purpose:** no lost changes, silent overwrites, repeated fixes or false PASS claims.

## Which records are authoritative

1. **Owner-approved scope:** `docs/DECISIONS.md`, `docs/ART_LOCK.md`, current task brief and explicit owner feedback.
2. **Actual code state:** commit SHA, Git diff, tests, Android device evidence. Descriptions and chat claims cannot replace code.
3. **Single shared issue queue:** GitHub Issues; each bug/feature has one issue with owner, reproduction, touched files, acceptance.
4. **Open PRs:** inspect all before making overlapping changes. Unmerged does NOT mean lost; do not discard or blindly reapply.
5. **`docs/dev/WORK_STATE.json`:** searchable snapshot/index, NOT an automatic lock and NOT proof a fix shipped.
6. **Per-task handoff notes** in `docs/dev/handoffs/`; `HANDOFF.md` and `CHANGELOG.md` are release summaries, not a replacement for issues and PRs.

## Required FIRST action in every new Claude / ChatGPT session

From the real repository checkout:

```bash
git status --short
git branch --show-current
git rev-parse HEAD
git fetch origin --prune
git log -n 8 --oneline --decorate
gh pr list --state open --base ccr-91dad981-53kkbi
gh issue list --state open
```

If `gh` is unavailable use GitHub connector/REST; NEVER assume there are no open PRs. Read `CLAUDE.md`, `AGENTS.md`, `docs/dev/COORDINATION_PROTOCOL.md`, `docs/dev/WORK_STATE.json`, and the relevant issue. Look at uncommitted/untracked work before switching branch or regenerating assets. If unclear whose WIP exists, STOP and report the exact paths and SHA. Do not reset/clean forcefully.

## Exclusive task ownership (soft lock with conflict detection)

- Claim a GitHub issue by a visible issue comment: `CLAIM by <agent> | branch <branch> | base <SHA> | touch paths <glob...> | started <date>`. Assign the issue when possible.
- Only ONE agent edits overlapping production paths at a time. A second agent must comment `BLOCKED: conflict with #...` and work elsewhere.
- A claim is not an eternal lock. When abandoned, explicitly release/reassign with a comment. Check claims BEFORE each new session; do not silently assume they expired.
- Each task uses a dedicated branch: `agent/claude/issue-18-minimap`, `agent/chatgpt/issue-19-stream`, etc. No direct concurrent pushes to the shared development branch.
- Write `docs/dev/handoffs/issue-<N>-<date>-<agent>.md` in the task branch. Do not have two agents rewrite one shared handoff file. Work-state JSON changes belong in that task's PR, after reconciling the current base.

## Finish and integrate

- Create a PR targeting `ccr-91dad981-53kkbi`, link the issue, list all changed files, base/head SHAs, model, passed tests, actual device/browser tests, evidence screenshots, and known blockers. Mark Android `NOT RUN` unless tested on a real handset.
- Fetch and compare current target before merging; ensure PR is mergeable, CI is green, and no approval-locked asset/physics/UI is accidentally changed. If the target advanced, rebase or merge normally; no `--force`, silent `git reset --hard`, or replacing shared files from a stale branch.
- **Human owner approval required for merge/push to release/production.** Especially respect existing `AGENTS.md` no-push/no-merge policy; do not treat a completed PR as a shipped APK.
- After approved integration, note exactly which commit and artifact contains the fix; only close the issue after acceptance tests. A previous phone screenshot showing a regression reopens the issue, even if headless tests pass.
- When two PRs overlap, **diff both** and selectively port needed changes. Do not merge an entire old versioned PR wholesale if it would roll back `VERSION`, workflow files or newer systems.

## Active divergence — IMPORTANT

- **PR #15** `agent/nitro-v0.1.32b-mobile-feedback` is OPEN, unmerged and currently has conflicts with newer dev. It contains Car Factory garage/cosmetics, driver records and proposed rear-hub safeguards. Those changes were not automatically available in v0.1.33. Protect them; review selectively against current HEAD. See https://github.com/karllondor/Nitro-Wheelz-/pull/15
- **Issue #16** Android wheel visual still open. Rear pivot yaw=0 in automated tests is NOT sufficient; look at actual mesh and phone screenshots.
- **Issue #18** point-to-point minimap phantom closing segment (confirmed code defect).
- **Issue #19** Ojców stream / bridge overlap (phone report; geometry investigation needed).
- **Issue #20** vegetation sway vs jitter (shader has sway; actual visual concern pending verification).

## Handoff format

```text
MODEL / TOOL VERSIONS:
BASE SHA / CURRENT SHA / BRANCH:
ISSUE(S) / OWNERSHIP CLAIM:
FILES CHANGED (and files not touched):
USER-APPROVED SCOPE / NEW DECISIONS / REJECTED DECISIONS:
IMPLEMENTED (code refs) / NOT IMPLEMENTED:
TESTS PASS / FAIL / NOT RUN:
CAPTURES, SEED, TRACK ID, DEVICE BUILD:
REGRESSIONS / UNMERGED PR DEPENDENCIES:
NEXT EXACT COMMAND/ACTION FOR OTHER AGENT:
```

**Single rule:** An agent cannot call something DONE until its own code, tests, CI status and necessary phone proof are linked to a specific merged SHA.
