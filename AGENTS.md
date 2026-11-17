# Agent contract (Codex, Claude and other AI developers)

Before work, inspect README.md, PROJECT_BRIEF.md, docs/TECH_SPEC.md, docs/ART_LOCK.md, docs/DECISIONS.md, HANDOFF.md and current git status. State the exact model when known; otherwise say unknown. Run from repository root, never from an unrelated home directory.

## Non-negotiable
- Never modify an approved reference in-place. New approved versions have a new stable ID, new path and explicit human approval.
- Never remove a manifest entry, bypass the protected-art gate or hide a failed test.
- Never delete, force-push, reset --hard, change main, push, merge or publish without owner authorization.
- Work in isolated agent/* branches/worktrees where possible; avoid two agents editing the same scene.
- Preserve game genre, pinned engine, renderer, project identity, approved visual style and target platforms.
- No copying proprietary code/assets; REA research must distinguish observations from hypotheses and independently implemented mechanics.
- Inspect first, implement the smallest testable slice, run checks, report what was **NOT RUN**.
- Never infer working Android/Windows/Xbox support from headless scripts alone.
- Ask for approval before substantial destructive/irreversible action; prefer reversible changes.

## Definition of Done
1. Scope and acceptance tests identified, files changed are within scope.
2. Python checks pass; Godot import/smoke tests run where Godot is available.
3. Negative controls are verified for new safety gates.
4. Required hardware/browser tests have evidence, else explicitly NOT RUN.
5. Approved assets untouched and manifest comparison against protected base passes.
6. CHANGELOG.md, HANDOFF.md and QA_MATRIX.md reflect actual evidence.
7. Report model, branch/commit, tests, device/OS, remaining blockers and next action.

## Interface
Keyboard and Xbox controller support by default, touch on mobile-target games. Menu uses built-in ui_* actions, gameplay actions are context-specific. Xbox Guide and Share buttons cannot be required. See docs/INPUT_XBOX.md.

## Handoff response
MODEL | BRANCH/COMMIT | FILES | TESTS (PASS/FAIL/NOT RUN) | DEVICE | EVIDENCE | APPROVED ART | BLOCKERS | NEXT ACTION

