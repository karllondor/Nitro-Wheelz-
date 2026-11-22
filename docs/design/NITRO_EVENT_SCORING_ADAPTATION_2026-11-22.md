# Nitro Wheelz — Event Judging & Points Adaptation (proposal v0.1)
Date: 2026-11-22
Task: ASTRA PRO / #29; GAME DESIGN PROPOSAL, NOT implemented or owner accepted. DO NOT CHANGE legacy 3-star awards or stored records until owner signs off and phone QA is complete.

## Core principle: borrow judging **observables**, not league score scale
Drift Masters 2026 solo qualifying: 60 LINE + 20 ANGLE + 20 STYLE (Initiation 5, Fluidity 10, Commitment 5), per-event judges' map with Outside Zones, Inside Clips, optional Touch & Go, long-zone sub-sectors; printed p6-9 of official PDF. DTS Winter 2025/26 OPEN: LINE, SPEED, ANGLE, STYLE, three 0–100 solo rounds averaged; numerical weights and spatial tolerances specified in the local briefing, not the public PDF. Sources in `docs/research/DRIFT_JUDGING_SOURCE_PACK_2026-11-22.md`, branch `docs/judging-source-pack-20261122`. Official DM map figures remain external links, not reused artwork.

Nitro must display *its own large arcade Drift Points* rather than 100 league points. Scoring needs two independently observable outputs:
- **NITRO POINTS**: the visible extensible numeric total (e.g. thousands), and its best-run record, later the 5-star source.
- **JUDGING QUALITY**: an internal normalized 0..1 evaluation of correct sectors/line/angle/flow/pace; retained for transparency and later star quality gates, **not an official DM/DTS 100-point score**.

## Existing v0.1.39 code (verified, critical)
`game/scripts/race/drift_scorer.gd`: drifting >=10° earns per-frame points proportional to speed*angle_factor*12*proximity_factor (edge <=4.2m -> max x1.5), live chain +0.1x/1.5s and +0.25x per left-right transition, multiplier capped at x5, bank after .9s no drift; chain lost on spin >=115° or wall hit. **Crucial defect for zone judging:** `edge_distance` is nearest road edge irrespective of proper OUTSIDE zone / inside clip, so driver can rack up edge bonus on the WRONG side of a turn.
`race_results.gd`: score thresholds for 3 stars are points/metre rates [2.0,4.5,7.5], 3 laps. `player_progress.gd` aggregates best stars of all known track IDs, including user tracks. DO NOT reuse that for future official 5-star unlocks until official-vs-custom registry migration is designed.
`race.gd::_drift_scoring` feeds `model.is_drifting()`, signed `model.drift_angle`, speed, nearest `edge_distance` into scorer. Introduce event judgement as NEW separate layer/adapter, preserve legacy race modes.

## Mode policy
| | Practice | Club | Pro |
| --- | --- | --- | --- |
| Painted event scoring zones | NONE | Procedural forgiving DTS-OPEN-inspired | Procedural precise DM-inspired |
| Road lane / edge stripes | remain in ROAD style | remain | remain |
| Normal arcade drift points | optional learning HUD, not official | yes | yes |
| Zone weighting | none | moderate | stronger |
| Scoring area | training, no eligible official record | unique marked judged curve sectors | unique marked judged curve sectors |
| Finish | free drive | solo judged track section | solo judged track section |
| Five-star awards | none | NOT NOW | NOT NOW |

## Procedural judged track map
From ROAD graph/spline, curvilinear coordinates `s` (along path), signed `d` (cross-road lateral), local half width `w(s)`, road height/camber, curvature `k(s)`, directions and valid collision ribbon:
1. Smooth curvature over metres, segment into STRAIGHT, ENTRY, ARC, TRANSITION, EXIT. NO scoring zone on STRAIGHTS. No zone on non-driftable curve; show owner a warning to adjust ROAD.
2. For each feasible corner, automatically derive zone(s) as [s_start,s_end, lateral edge target band, allowed car footprint, scoring weight], correctly flip sides for signed curvature. On a long arc subdivide into sectors with unique sequential IDs; avoid duplicate credit for clipping the same zone repeatedly.
3. OUTSIDE ZONE: evaluate signed rear outer tyre/rear quarter proximity to **designated OUTER EDGE** and actual fraction of the zone travelled while drifting; not simply car centre or nearest edge. Inside Clip: assess appropriate **front/nose-side vehicle footprint** approaching designated INNER clip while maintaining drift; using entire car transform prevents reward at the wrong side. A visual contact with cone is NOT required; hitting a cone/wall is not rewarded.
4. Touch & Go / initiation are optional only if geometry supports a safe reachable pass. No universal 'ideal mathematical line': generate a **drivable reference corridor** validated with actual weak/strong Nitro car handling, reachability, correct yaw and countersteer, and safety margin. For narrow Touge ROAD use physically reachable lower-speed and smaller-angle targets, not blanket pro-car values.
5. Each scored section has a deterministic `zone_id`, lane/edge target footprint, len_m, coverage and progress state, target angle/speed envelope, painted polygon, penalty flag, max award. One event mode may alter these values; **ROAD geometry unaffected**. ROAD edits regenerate all sections. Practice renders none.

## Proposed measurable quality signals (Nitro original, not league numeric weights)
Within each unique crossed scored section i:
- `L_i` line accuracy 0..1: signed inside/outside correctly reached; weighted spatial distance, longitudinal coverage and consistency. A momentary touch doesn't earn a whole long zone. Missing entire zone = 0. Outer long zone can have several sub-sectors.
- `A_i` angle quality 0..1: appropriate sustained actual **slip angle** while progressing forward and controlling direction, subject to car physics and allowed envelope. Do not reward a wheel steering angle alone or uncontrolled over-rotation.
- `F_i` flow/style 0..1: initiation in window, controlled transition in proper direction, sustained valid drift, no harsh correction/spin; legitimate multi-turn transitions recognized once.
- `V_i` pace quality 0..1: reasonable corner-specific speed and flow rather than top-speed contest; benchmark against feasible vehicle envelope or balanced event category. No bonus for driving 220 km/h into a 40 km/h bend.

Suggested initial tunable weighting (**NITRO proposal, NOT official DTS or DM**) for QA and comparison:
| Mode | LINE | ANGLE | FLOW / STYLE | PACE |
| Club | 0.40 | 0.25 | 0.20 | 0.15 |
| Pro | 0.55 | 0.20 | 0.15 | 0.10 |
`Q_i = wL*L_i + wA*A_i + wF*F_i + wV*V_i`, after valid-drift and road-eligibility checks. DM LINE being 60/100 is a design rationale for Pro line emphasis, not a mandate to reproduce those numbers on-screen.

## NITRO POINTS adapter — proposed, not calibrated
Keep existing arcade combo feedback, but event-scored sections must be **bounded by route progress** so users cannot farm donuts in one sector.
- `B_i` = base Nitro scorer points during FIRST valid forward traversal of sector i, **excluding the legacy arbitrary-nearest-edge proximity bonus**; at most `BMAX_i` (a reproducible cap from sector metres and actual baseline driver runs; once per lap/attempt).
- `ZMAX_i` = mode-dependent technical zone award budget from actual section length/complexity and calibrated reference laps; if section not feasible -> no zones and no zone bonus.
- `T_i = clamp(0.5*A_i + 0.3*F_i + 0.2*V_i, 0,1)`.
- `ZoneBonus_i = round(ZMAX_i * L_i * T_i)`. A zone missed (L_i=0) gives **zero** zone award even if held big angle. An outside-zone *subsector* is counted at most once; a brief skim gives partial `L_i`.
- `EventPoints = sum_i [ B_i + ZoneBonus_i ] - bounded(event-specific penalties)`. Integer NITRO POINTS; no artificial 100-point ceiling. Existing chain multiplier remains in `B_i`, but its attributable points must be **capped by unique positive segment progress**; not counted again for cycling backward/restarting same section.
- In Pro, missing zones gives higher lost potential (larger `ZMAX_i` share and tighter spatial tolerance); in Club lenient line score and gentler penalties allow learning and success. Do not scale a Pro zone reward to impossible reference angle or speed.

**A simpler alternative for first prototype:** keep numeric current `NitroDriftScorer.total` as **FREESTYLE POINTS** (unchanged for comparison), compute `ZoneBonus` and `EventPoints` in a separate sandbox-only `NitroEventScorer`, display breakdown; no replacement of global highscores, 3-star storage or even gameplay score in existing race modes until owner approves. This is the preferred low-risk vertical slice.

## Error treatment (proposal)
- On-line valid zone fill: award partial -> full section score, mark visually on asphalt and UI; display '+... ZONE', '% zone fill' and sector-completion indicator.
- Wide-but-not-target slip: base drift points may remain; zone bonus 0/partial. The zone must NOT be credited simply for driving over a painted band at 0°.
- Wrong edge / reverse direction / standstill / donut farming inside single zone: no new zone points after the single allowed forward crossing; zero zone quality for wrong-side pass.
- Missed clip or low angle: reduce that section's technical award; don't auto-zero whole lap.
- Wall/obstacle contact, spin, off-asphalt: break current chain; possibly invalidate current section; make full-run invalidation an owner decision (Pro) rather than silently importing DM's 'incomplete run' rule into Nitro. Club must remain forgiving.
- Avoid numeric points on non-event straights except optionally legacy freestyle HUD: they must not increase Club/Pro judged score if not a valid scored section.
- A (REAL_POWER_TEST) diagnostics: no records/stars, regardless of new EventPoints.
- ROAD public centre/edge lane markings are NOT scoring zones.

## Concrete owner-facing example (EXPLANATORY, not balanced targets)
One 100 m marked sweeper:
A) high angle + arbitrary wrong edge -> baseline arcade chain 2100, zone completion L=0 -> ZoneBonus 0.
B) slightly lower angle + full correct OUTSIDE zone -> baseline arcade chain 1650, zone completion L=0.95 and T=0.88. For *illustrative* ZMAX=1000, technical award round(1000*0.95*0.88)=836, EventPoints 2486. B beats A by running the intended line.
The target max award must be derived from game telemetry, NOT finalised at 1000 in this example.

## Five-star bridge — ARCHITECTURE ONLY, no migration yet
Once final official owner-designed tracks are driveable and events calibrated:
- Five one-time non-spendable stars per official course/event configuration: threshold achievement based on **best judged NITRO EVENT POINTS** and optionally mandatory minimum line-sector coverage to prevent high freestyle score from bypassing zones.
- Stars for each official `track_id + scoring_profile_id + scoring_version` must be scoped to a **published official event**, not user-custom tracks, procedural random seeds, Park Practice or diagnostic REAL_POWER_TEST. Keep existing owner requirement 5 **per official track**: do NOT assume separate 5-star wallets for Club and Pro; decide later whether one event provides official stars, or best score across approved modes. No double-counting Club and Pro on one track.
- Reward at most first-time newly met thresholds, never spend stars or farm the same milestone. Use stored best achieved star bitmap/level per stable official track; avoid erasing legacy saves.
- Five numerical score thresholds are calibrated later from scripted drive traces (weak car + strong car, beginner/average/expert) and owner phone tests on FINAL tracks. Don't compute thresholds on currently unapproved Shin-Kawa or on the 2026-11-22 reference route.
- Score model `event_scoring_version` must be in persisted results/ghost records to handle balancing updates without corrupting leaderboards.

## Required QA tests before owner review
1. Straight: centre/edge public road paint remains, ZERO event scoring sections.
2. Long left sweeper: correct side, several sector awards; wrong edge at high slip earns no zone bonus.
3. Right turn: normal offset sign flips, inside clip awarded only from correct side/car footprint.
4. S-turn: reliable transition, no double-award or false straight-sector credit.
5. Same exact road: Practice no zones; Club generous but real judgement; Pro tighter and demonstrably different scoring budget.
6. No drift / zero slip but driving over zone: ZERO zone bonus.
7. Standing donut in one zone or driving backwards over same zone: no extra repeated sector reward.
8. Full-length outer zone skim once vs sustained filling: sustained filling scores higher.
9. Weak car can credibly earn Club judged points; strong car cannot gain disproportionate high-speed bonus alone.
10. Off-road collision/spin breaks chain and deducts appropriate section, but Club is not automatically total zero.
11. A mode diagnostic cannot write stars/results.
12. Old three-star score paths, old personal records and saved runs are unchanged by the preview.
13. Change road -> deterministic regeneration, stable IDs; reload -> same geometry, scoring and zone paints.
14. Android HUD clearly shows NITRO EVENT POINTS / zone cue without overwhelming mobile controls, with rendering in actual game camera.
15. Test total against BASELINE scorer using captured deterministic traces so old feel and new line correctness can be compared.

## Pending owner decisions (ask after playable QA)
1. Should Club be a forgiving judged solo course and Pro be stricter using the **same** visible high-score currency, with separate event-mode scoreboards? Recommendation yes.
2. Should a Pro spin invalidate only the current sector or the entire judged attempt? Recommendation start current sector; keep full-run invalidation as optional Pro rule for later.
3. In later progression, should official five stars belong to Club only, Pro only, or one shared best official track result? **Do not pick or build now.**
4. Confirm zone marking colours/line readability after real mobile screenshot test.

## Boundaries
Do not hand-place/edit zones. No five-star implementation, rewards, score record overwrite, main merge, live release or unapproved track redesign. Astra's Android prototype should demonstrate **the two score layers, zone coverage, instant transparent feedback, and replay-safe deterministic calculation** on a disposable reference route. Owner acceptance remains phone pending.
