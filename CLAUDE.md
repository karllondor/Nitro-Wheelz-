# Claude project entrypoint

Read AGENTS.md, PROJECT_BRIEF.md, docs/ART_LOCK.md and HANDOFF.md. AGENTS.md is authoritative; do not duplicate or contradict it. Verify whether your installed Claude Code already discovers AGENTS.md before adding imports.

Record the exact model and tool versions if actually observable. Do not invent test evidence or claim to have remembered previous projects.

See .claude/settings.json for conservative permissions; GitHub branch protection and CI provide stronger enforcement than local agent settings alone.


## Nitro Wheelz — required shared state check
Read `docs/dev/COORDINATION_PROTOCOL.md`, `docs/dev/WORK_STATE.json`, and `docs/dev/REVIEW_2026-11-21.md` BEFORE modifying game code. This prevents overwriting another agent's work (notably open/unmerged PR #15). Start with `git status`, `git fetch`, `gh pr list`, and `gh issue list` or equivalent connector actions; choose a non-overlapping issue branch. Use `docs/dev/HANDOFF_TEMPLATE.md` for your end-of-task report.
