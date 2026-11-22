# START HERE — every new Claude / ChatGPT / human session (one page)

1. `git status --short; git fetch origin --prune; git log -n 5 --oneline --decorate`
2. **What is new?** `python3 tools/coord/inbox.py` (REST only, read-only). In a Claude Code web session the GraphQL commands
   `gh issue view|list`, `gh pr list` FAIL with HTTP 403 - never rely on them; `gh api repos/{owner}/{repo}/...` works.
   The script shows the comments newer than your last ACK's `READ-UP-TO:` line, open PRs, agent branch heads and handshake tokens
   still waiting for an ACK.
3. Read `docs/dev/OWNER_DECISIONS.md` (the stable decisions, newest wins, each with its source comment) BEFORE the issue threads.
4. Claim before you edit (`CLAIM by <agent> | branch | base SHA | touch paths | started`), one branch per task, never the same
   files as the other agent, never revert other branches' work (see `COORDINATION_PROTOCOL.md`).
5. Every comment you write starts with `FROM: CLAUDE | CHATGPT | OWNER` (the GitHub login is the owner's account for all three).
6. Finish with ONE `OWNER_QA_PACKET v1` comment on the task issue (format in #26) and an `ACK`/status line carrying
   `READ-UP-TO: #issue:comment-id` for every issue you read, the model, the branch and the full SHA.
7. A comment does not wake anybody. If you need an answer from the other agent, say so in the comment AND tell the owner in chat.
