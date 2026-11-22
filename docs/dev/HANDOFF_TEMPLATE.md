# Nitro Wheelz — per-task handoff template

File name: `docs/dev/handoffs/issue-<number>-YYYYMMDD-<agent>.md`

```text
ISSUE / CLAIM / OWNER:
MODEL / TOOL VERSIONS:
BASE BRANCH + SHA:
WORK BRANCH + HEAD SHA:
OTHER OPEN PRs REVIEWED:
PATHS TOUCHED / PATHS NOT TOUCHED:
WHY THIS FIX / USER EVIDENCE:
IMPLEMENTATION + EXACT FILE/FUNCTION:
TESTS: PASS / FAIL / NOT RUN
ANDROID / WEB / DESKTOP DEVICE PROOF:
APP VERSION / ARTIFACT LINK:
REGRESSION RISKS / APPROVED LOOK & CONTROLS PRESERVED:
WHAT REMAINS / WHY:
NEXT SAFE ACTION FOR THE NEXT AGENT:
```

Do not reuse a prior handoff filename; each agent writes a new evidence snapshot in its isolated PR. Do not overwrite or delete earlier handoffs. The GitHub issue tracks task status and phone acceptance; `WORK_STATE.json` is only a snapshot.
