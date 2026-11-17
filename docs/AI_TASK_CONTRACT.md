# AI Task Contract — scoped autonomous development

Before every task record: (1) intended player-visible outcome, (2) allowed files, (3) files explicitly protected, (4) branch/worktree, (5) measurable acceptance tests, (6) rollback SHA. Read AGENTS.md and relevant approved-art registry.

Agent may inspect, design, write scoped code and execute safe tests. Agent must not silently change design direction, engine version, input parity, approved references, dependencies or release history. Ask for owner approval before deleting anything significant, replacing protected assets, force-pushing, merging or publishing.

After task: provide file diff summary, exact model and environment when known, actual command outputs, result of Python/Godot/device checks, screenshots/video for visual tasks, all untested platforms, code provenance, known defects and next action. Update HANDOFF.md and CHANGELOG.md.

Reviewers reject unsupported PASS, hidden scope creep, unapproved asset alteration, or missing rollback path. CI guards cannot replace branch protection and human approval.
