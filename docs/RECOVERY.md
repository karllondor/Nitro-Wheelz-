# Recovery and agent resilience

Before risky work: note current commit and build version, create a dedicated branch/worktree, verify git status, and preserve approved artifacts. Never run reset --hard or force push as an automated recovery shortcut.

After a bad change: inspect git diff/status, identify exact commit and failing test, revert the feature commit/PR rather than rewriting protected history. Use release artifacts from previous immutable tag if player testing must continue.

Run agents from repo root, not a home-directory session. For long local terminal tasks use tmux; capture HANDOFF.md at session end. Record command evidence, current SHA, known broken tests, artifact location and next action. CI and release metadata survive chat/session loss.

