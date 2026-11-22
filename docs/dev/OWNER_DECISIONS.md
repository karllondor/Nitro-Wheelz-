# Owner decisions ledger (DRAFT FORMAT - proposed by Claude Code 2026-11-22, owner approval of the format pending)

Append-only. Newest entry for the same topic wins; never edit an old entry, add a new one that says `supersedes D-nn`.
Each entry: what was decided (one line), where the owner said it (GitHub comment id c...; the login is the owner's account
whoever typed it, see COMMUNICATION_AUDIT_20261122.md), its status, and what the CODE does.
Status words: APPROVED / PENDING / SUPERSEDED / NOT APPROVED / DONE. Code words: NOT IMPLEMENTED / CODE_READY / OWNER_QA / ACCEPTED.
This ledger is a convenience index, NOT proof that anything shipped (`COORDINATION_PROTOCOL.md`: only a merged SHA + phone proof is).

| ID | date | decision | source | status | code (at 2026-11-22) |
|---|---|---|---|---|---|
| D-01 | 11-22 | RED Lada 2106 = Mazda 13B rotary; WHITE Lada = BMW N20B20 2.0 turbo I4 (328i 245 PS / 350 Nm reference); Toyota 3S-GE NOT selected | #25 c7078765103, c7078787925, #26 c7078788172 | APPROVED | red done (v0.1.36); white NOT IMPLEMENTED (v0.1.36 wrongly gives it the 13B profile) |
| D-02 | 11-22 | Launch UX: tap the NW-crown icon -> the SAME owner-approved full-screen artwork -> game; no enlarged icon; black only as a documented fallback | #25 c7078839871 (supersedes c7078820094 black-first, c7078810848) | APPROVED | NOT IMPLEMENTED |
| D-03 | 11-22 | Nitro Wheelz Park = ONE large open flat paved surface, everything coexisting; START TUTORIAL or SKIP / FREE DRIVE into the same place; no barriers; orange movable cones that never stop the car; no gates | #27 c7079032468 (supersedes the "two zones" c7079015739 and #26 c7078949630) | APPROVED | CODE_READY on `agent/claude/issue-27-nitro-wheelz-park`, phone NOT RUN |
| D-04 | 11-22 | Park geometry: original elongated / flattened figure-eight as a miniature drift circuit for the weakest starter car, NOT a Warsaw replica; outline / dimensions / cone positions NOT approved | #27 c7079084120 | APPROVED (geometry open) | provisional layout in `park_layout.gd` |
| D-05 | 11-22 | Park centre logo = the existing full approved logo asset (`nitro_wheelz_logo.svg`, blob f9d7b56), flat on the pavement; not the NW launcher icon, no new logo | #27 c7079099058 | APPROVED | done, checked by `park_layout_test` |
| D-06 | 11-22 | Cones are lightweight movable props (tip / slide), never rigid; reset on lesson start is a suggestion | #27 c7078981596, c7079015739 | APPROVED (reset = suggestion) | done |
| D-07 | 11-22 | Five permanent one-time stars per official track; global cumulative total shown on the PLAYER CARD; not spendable; unlocks by global thresholds; thresholds / rewards UNDECIDED; no farmable stars in the Park; creator tracks do not mint global stars | #26 c7079211871, c7079223825, #24 c7079224174, #27 c7079276183 | APPROVED (numbers open) | NOT IMPLEMENTED (code still has 3-star tiers) |
| D-08 | 11-22 | Camera changes (#17) postponed pending owner review | owner chat 11-22, #27 c7079276183 | APPROVED | untouched |
| D-09 | 11-22 | PR #21 (coordination docs) merged into `ccr-91dad981-53kkbi` | owner chat, #25 c7076743555 | DONE | merged 2606538 |
| D-10 | 11-22 | Cars calibrated by real power-to-weight (ADR-010); later "cars far too weak at speed" -> audit; no shared-physics change without coordination | owner chat, #25 c7079276647 | PENDING (audit decision Q3) | v0.1.36 arcade ranking; audit in `docs/CAR_PERFORMANCE_AUDIT_20261122.md` (on the Park branch) |
| D-11 | 11-22 | OVAL / SWEEPERS to DEVELOPER only: NOT approved; track organisation deferred | #26 c7078927902 | NOT APPROVED | menu unchanged |
| D-12 | 11-22 | ONE version / one package per owner request (no separate updates per detail) | owner chat 11-22 | APPROVED | practice |
