# ChatGPT <-> Claude communication audit (issue #26, 2026-11-22)

Written by Claude Code (an actual running session, model `claude-sonnet-5-5`, session `session_01XDNUq8gYtCvKNGBffzhg2g`) at the
owner's request (#26 comment 7079313229). Everything marked VERIFIED was done in this session with evidence below; what only ChatGPT
did is marked as such; what I could not test is UNTESTED. Nothing here claims that ChatGPT has read anything.

## 1. COMMUNICATION HEALTH REPORT
| check | status | evidence / who |
|---|---|---|
| READ issues + comments (GitHub -> Claude) | **VERIFIED** (REST) | #24 (2 comments), #25 (9), #26 (16 + my ACK), #27 (6 + my claim) read with ids through `gh api repos/.../issues/N/comments` and `tools/coord/inbox.py` |
| READ with the commands the protocol / handshake name (`gh issue view 26 --comments`, `gh issue list`, `gh pr list`) | **FAILED** | HTTP 403 "GitHub GraphQL is not available from Claude Code sessions" (all three, run in this session). The documented steps cannot be followed as written |
| READ repo files written by ChatGPT (PR #21: `docs/dev/*`, WORK_STATE.json) | **VERIFIED** | fetched, read, PR #21 merged on the owner's instruction (merge 2606538) |
| WRITE (Claude -> GitHub) | **VERIFIED** | #26 comment 7079367605 (ACK), #27 comment 7079397895 (claim), #25 / #24 comments earlier today, REST `POST .../comments` |
| ACK of the handshake `NW-QA-HANDSHAKE-20261122-A` | **VERIFIED written** | #26 comment 7079367605 (model, branch, full head SHA, problems, recommendations) |
| ChatGPT RECEIVES / reads my ACK | **UNTESTED** | needs a ChatGPT comment quoting `head=465f7e1` back; none exists yet |
| QUESTION ROUTING (Claude question -> issue -> owner in Polish) | **UNTESTED end to end** | the format `OWNER_QA_PACKET` (#26) exists; no packet has gone through it yet. I post the first ones in #27 / #25 |
| ANSWER RECEIPT (owner -> ChatGPT -> issue -> Claude) | **VERIFIED (read side)** | `OWNER_ANSWER #25.Q1` (c7078765103, c7078787925) and the owner decisions c7079211871, c7079223825 were read and are applied |
| SESSION CONTINUITY (a posted request reaches a session by itself) | **FAILED (by design)** | no Claude session existed between my last comment (09:12 UTC) and the owner starting this one (~12:45 UTC): the ChatGPT probe of 11:42 UTC waited about 3 h. A GitHub comment does not start or wake an agent |
| OWNER_QA_PACKET | **UNTESTED** | format defined in #26; first use pending |

## 2. What is broken, fragile, outdated, duplicated, too complicated (specific)
1. **Commands that cannot run (FAILED).** `COORDINATION_PROTOCOL.md` ("Required FIRST action") and the #26 handshake use `gh pr list`,
   `gh issue list`, `gh issue view`. In Claude Code web sessions GraphQL is refused, only REST works. An agent following the protocol
   literally stops at step 1 or silently skips the check ("NEVER assume there are no open PRs").
2. **Authorship is invisible.** Every comment in #24 - #27, including mine, is posted by the owner's accounts (`karllondor`, and a
   second account `fottokarll` on the Park clarifications). A reader cannot tell the owner's words from ChatGPT's paraphrase from
   Claude's own status. "OWNER DECISION ... via ChatGPT" is therefore only as good as the relay; some entries mix a decision with
   ChatGPT's recommendation in one paragraph.
3. **#26 does five jobs** (dashboard, mailbox, decision log, QA queue, handshake) in 28 KB and 17 comments with chains of "supersedes"
   (the Park alone was redefined four times: Oval/Sweepers -> a pad -> two zones -> one surface). An incoming agent must replay all of
   it in order and still might act on a stale body.
4. **Inconsistent question ids.** `#25.Q1` names the white-engine question, the owner's answer and a "removed old question" line;
   `#25.Q2` is the splash in three comments with two supersedes. No single place says which question is open.
5. **A handoff file silently corrupted for hours (FAILED, repaired).** `docs/dev/handoffs/issue-19-20261122-claude.md` was 1,410,881 bytes:
   one sentence had been inserted before every character (5,304 times) by an automatic edit - found by ChatGPT's lineage check, not
   by any guard. Repaired from the file itself (5.3 KB, content restored, nothing lost; commit on the Park branch).
6. **Stale snapshots.** `WORK_STATE.json` says "observed version 0.1.33" and lists PR / issue states by hand; the protocol itself says it is
   not proof. It duplicates information that lives in the issues and drifts.
7. **The handshake presupposes a running agent.** "Reply on your next session" is correct, but the status words (`DISPATCHED` = "Claude has
   received it") are easy to read as "Claude is working on it"; ChatGPT's own comment already warns about it - good.
8. **The owner is the transport.** Nothing connects the two agents; the owner starts each session. That is fine, but the process should
   be designed around it (batching, no waiting) instead of around an imagined live link.

## 3. Is there a supported way to improve communication between separate sessions without pretending they are connected live?
- **ChatGPT <-> Claude Code: no live channel exists** (VERIFIED by what the tools of this session offer: GitHub REST, repository files,
  `send_message` only between Claude sessions, scheduled tasks and PR-event subscriptions inside Claude Code). The honest model is an
  **asynchronous mailbox with receipts**: GitHub issues + repository files, each side polling when its session starts.
- Mechanisms that exist on the Claude side and could shorten the delay (all UNTESTED here, read from the tool descriptions):
  (a) `subscribe_pr_activity` - PR comments / CI / reviews are delivered into a RUNNING session as turns (not issue comments, not new
  sessions); (b) **scheduled tasks** (`create_trigger`: cron, each firing starts a fresh Claude session in this environment with a stored
  prompt) - could run `tools/coord/inbox.py`, post an ACK and a short triage, nothing else; (c) `send_later` (a reminder to the same session).
  (b) is major automation: it runs with the owner's GitHub identity, costs a full session per run and can act on instructions from
  comments, so it needs the owner's explicit approval, a strictly read-and-report prompt and a rate limit. Not created.
- On the ChatGPT side it depends on its connectors; what it demonstrably does: read / write issues and branches, open PRs.

## 4. Concrete recommendations (smallest first; the first five are implemented in this branch, coordination-only)
1. **REST startup** - `tools/coord/inbox.py` (read-only, REST): open issues, comments newer than my last ACK, markers (CLAIM, OWNER_ANSWER,
   OWNER_DECISION, OWNER_QA_PACKET), handshake tokens without an ACK, open PRs, agent branch heads. Tested live against this repo.
2. **Watermark in the ACK, no local state** - every ACK / status comment carries `READ-UP-TO: #issue:comment-id`; the next session starts there.
3. **Authorship line** `FROM: CLAUDE | CHATGPT | OWNER` and, for relayed decisions, the owner's own words in quotes.
4. **Decision ledger** `docs/dev/OWNER_DECISIONS.md` (draft with the 12 decisions of today, each with the source comment id): newest wins,
   append-only; #26 stays an index + QA inbox, details live in the task issue.
5. **Corruption guard** in `tools/check_project.py` (CI "Foundation checks"): a `docs/dev` file over 64 KB or with one line repeated over
   30 % fails. Proven not blind on a corrupted copy.
6. **`START_HERE.md`** one page for every new session; **protocol v1.1 addendum** (REST, authorship, ACK, async delivery, ledger).
7. *Needs owner approval:* a scheduled read-and-report task (see section 3b); a WORK_STATE.json generated from the API instead of hand edited;
   ChatGPT adopting the `FROM:` line and replying `RECEIVED <token> head=<sha7>` to close the loop.

## 5. Verified / failed / untested (short)
- VERIFIED: REST read of 4 issues / 33 comments; REST write (ACK, claim, status); PR #21 read + merged; inbox script; corruption guard;
  ancestry of #16 / #18 / #19 / #20 / #24 in the v0.1.36 head (`merge-base --is-ancestor`, 9 branches).
- FAILED: the documented GraphQL commands; automatic delivery / waking; the 1.4 MB handoff (now repaired).
- UNTESTED: that ChatGPT read my ACK; the OWNER_QA_PACKET round trip; scheduled tasks and PR subscriptions; ChatGPT writing a `FROM:` line.
- Two-way communication is NOT established until a ChatGPT comment quotes `head=465f7e1` (or any later fact only a reader of my ACK knows).
