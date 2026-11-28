# Promoting the stable QA build to `main` (prepared for v0.1.54 — NOT executed, owner approval required)

## Facts (28 Nov 2026)
* `main` = `018efa1` (v0.1.6). It **is an ancestor** of `integration/stable-mobile-qa`, so promotion needs no conflict resolution.
* `integration/stable-mobile-qa` (PR #70) contains, by git ancestry: PR #9–#14, #30, #32, #39–#45, #58, #63, #64 (Forest Lab, DEVELOPER only),
  #69, #71, #72, #73 and the earlier `ccr-91dad981-53kkbi` / `integration/nitro-dev` lines.
* NOT contained (stay open for a separate owner decision, nothing in v0.1.54 depends on them): #15 (v0.1.32b mobile feedback, 32 commits;
  its garage / records parts were ported earlier), #35 (Linux / Web QA), #36 (PC / Web HUD; its content reached v0.1.48 by another route),
  #38 (visual lab Fuji AE86).
* `main` has no branch protection; the Android workflow builds the **production** package `com.karllondor.nitrowheelz` on pushes to `main`.

## Gate (all required)
1. Owner phone PASS of the v0.1.54 checklist on the ONE QA app (`com.karllondor.nitrowheelz.review.pr45`, versionCode 54).
2. CI green on the exact QA SHA (foundation, godot, android + identity, desktop, web, emulator upgrade test).
3. Owner writes "APPROVED: promote <SHA> to main" in #67.

## Procedure (after the gate)
1. Freeze `integration/stable-mobile-qa` at the approved SHA `S` (no pushes while promoting).
2. `git tag -a qa-v0.1.54 S -m "Owner-approved QA build v0.1.54"` and push the tag.
3. Open ONE PR `integration/stable-mobile-qa` → `main`, titled "Promote v0.1.54 (owner-approved QA) to main", listing the PRs above.
4. Merge with **"Create a merge commit"** (never squash, never rebase: squash would erase the per-PR history and SHAs referenced in
   issues; rebase would rewrite 300 commits). Because `main` is an ancestor, the merge commit's tree is identical to `S`.
5. Verify: `git diff S origin/main` prints nothing; CI on `main` is green.
6. The production package build from `main` is **not** distributed — switching the owner from the QA app to the production app is a
   separate release decision (saves live per package; a migration step would be needed).
7. Close the superseded stacked draft PRs (#44, #45, #58, #63, #64, #69, #70) with a comment "promoted via <PR> / qa-v0.1.54"; leave
   #15, #35, #36, #38 open for review.
8. After promotion new work branches from `main`; the QA channel (`tools/qa_channel.env`) keeps its package and certificate.

## Rollback
`main` before promotion is `018efa1`; reverting the single merge commit (`git revert -m 1 <merge>`) restores it without force-pushing.
