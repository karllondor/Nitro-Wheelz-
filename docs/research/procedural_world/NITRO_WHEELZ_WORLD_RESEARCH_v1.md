# NITRO WHEELZ — TRACK ENVIRONMENT RESEARCH & PROCEDURAL ART DIRECTION v1.0

**Date:** 2026-11-20  
**Project context:** Phase A v0.1.23 (Japan Drift Town). Technical prototype accepted; artistic design rejected.  
**Purpose:** Guidance for Claude to replace unrealistic roadside buildings with convincing drift venues in Japan, while preserving tested gameplay and deterministic world generation. This is research-based art direction, not a claim that the existing code has been changed.

## 1. Executive decision

**Do not proceed with Phase B as originally scoped (more houses, shops, plots).** First perform a **Japan Environment Visual Reset**. Keep Phase A's adjacency mechanism, local chunk rebuild, deterministic seed, Undo and Builder/Race parity. **Change placement semantics** from `road tile -> house` to `track context + terrain + venue type + functional zone -> appropriately located scenic/support assets`.

Current failure observed in two user-recorded v0.1.23 videos (1000076584.mp4, 1000076585.mp4): repetitive, square, pitched-roof buildings immediately next to racing barriers; excessive pink/purple suburban lighting; mismatch with wooded Japanese drifting circuit. The user-supplied reference photographs emphasise: heavily forested topography; varied embankments; limited service buildings clustered in a paddock; narrow asphalt with safety/runoff/banking; visually dominant mountain panorama. The bright turquoise runoff in some reference photos is a visual *option*, not a universal Japanese track rule.

## 2. Reference reality: actual Japanese venues

### A. Ebisu Circuit, Nihonmatsu, Fukushima — PRIMARY VISUAL BENCHMARK
- Official venue documentation describes **ten courses**, among them Higashi, Nishi, Kita, School, and 1,200 m Touge. Its mapped courses are linked across hills by access roads; forest is the dominant backdrop. Official material also confirms facilities such as a petrol station and timed courses, while different layouts have different equipment.
- **Visual DNA:** forested slopes; height changes; earth cuttings; patches of exposed soil; old asphalt; narrow access roads; clusters of small pit/service structures; parked transport and project cars only at workable service pads; occasional blue/green corrugated roofs. Mature evergreen + deciduous trees, with seasonal variations.
- **Rule:** buildings are concentrated at designated course entrances or paddocks; hillside vegetation and terrain define most corners. Not a repeating row of houses parallel to every piece of road.
- **Caveat:** archival photos may show layouts before modifications: the official page distinguishes the current New South / Slide Park from the former South course.
- Official sources: https://www.ebisu-circuit.com/course.html and https://ebisu-circuit.com/areamap.html ; tourism: https://fukushima.travel/destination/ebisu-circuit/56

### B. Meihan Sportsland C Course, Yamazoe, Nara — GRASSROOTS/COMPACT
- Rural location; short technical course, famous outside wall/fast entry; simple viewing bank and paddock rather than huge modern pit buildings.
- **Visual DNA:** blackened tyre-marked asphalt, tyre stacks, pit wall, open asphalt paddock, small shade canopy, workshop vans, drift cars waiting, modest tiered viewing, banners only when an event is on, trees/hills beyond.
- **Rule:** use a few motorsport-specific structures and cars to make it believable; *no generic town*.
- Sources: https://www.motorsportradar.com/tracks/meihan-sportsland/ ; https://jdm4all.com/jdm-tracks/kansai-region/meihan-sports-land/

### C. Nikko Circuit, Tochigi — SMALL PROFESSIONAL/GRASSROOTS
- Compact drift/track-day venue, open hardstanding paddock and low utilitarian structures, spectator separation, trees and open land nearby.
- **Visual DNA:** flat/modestly rolling site, low pit garages/canopies, rectangular asphalt service yard, spectator rails, tyres and safety netting, grass + forest edge.
- **Rule:** best secondary Japanese environment after Ebisu, because it translates to a flatter track-building algorithm.
- Official site: https://www.nikko-circuit.jp/

### D. Okuibuki Motor Park, Maibara, Shiga — SKI-RESORT EVENT VENUE
- **Not a permanent conventional closed-loop racetrack:** organiser uses extensive paved ski-resort car parks for gymkhana/drift events and temporary competition layouts; forest and rising mountains surround the site.
- **Visual DNA:** broad asphalt pads, sweeping temporary curves, line markings, portable concrete barriers, bright pop-up tents and banners, support lorries, floodlights, mountains, access switchbacks, seasonal ski-lift context where visible.
- **Rule:** suitable for drift arena/pro events; no residential buildings, and not the same geometry as Ebisu mountain course.
- Official: https://www.okuibuki.co.jp/green/motorpark/ ; 2026 FD Japan programme: https://formulad.jp/race/2026/

### E. Gunma Cycle Sports Center (Gunsai), Minakami, Gunma — CLOSED MOUNTAIN ROAD/TOUGE
- A forested winding road course used for scheduled motorsport activity, unlike a big circuit with permanent pit complexes.
- **Visual DNA:** narrow road cut into a hill, steel guardrails, blind crests, forest canopy, slope-retaining walls, minimal roadside facilities, support vehicles at course start/end only.
- **Rule:** entirely different **route/touge** archetype, not necessarily a loop. Implement later, if the driving and track data model support point-to-point runs.
- Official: https://www.gunsai.jp/circuit/

### F. Fuji Speedway / modern competition — BIG EVENT MODE
- Modern dedicated motorsport facilities can have substantial paddocks, grandstands, pit buildings, timing gantries, media positions, emergency infrastructure.
- **Visual DNA:** engineered safety areas, sponsor wall, flag points, full timing and race-day setup, spectator stands at selected viewing sections, service entry separate from racing line. Far skyline/hills can carry the Japan identity.
- **Rule:** select **Pro Event** variation only; don't scatter a pit building every 20 m.
- Official Formula Drift Japan 2026 venues: https://formulad.jp/race/2026/

## 3. Scene archetypes are not countries

Use three orthogonal controls:
1. `region/biome`: Japanese Tohoku forest; Kansai rural; alpine; Welsh coast; desert; industrial Europe.
2. `venue_archetype`: mountain circuit, small drift academy, stadium circuit, temporary parking-lot event, closed-road touge, industrial exhibition, street event.
3. `event_state`: practice day (quiet), grassroots meet (some tents/cars), championship event (crowds/banners/large support team).

A Japanese venue might be an empty mountain track, a grassroots rural course, or a televised competition. **Japan does NOT mean cherry trees, Japanese suburban houses, torii gates, neon and lanterns together.** These can appear only with believable setting/context. Most of the Japanese atmosphere in reference photos comes from the landform and vegetation, not iconography.

## 4. World placement: functional zones

These distances are **initial game-art tuning suggestions in metres, NOT real-life track safety standards**. The actual no-build envelope should depend on course width, speed/trajectory, outside of drift corners, barriers, elevation, player camera, and playtesting.

- `A_DRIVEABLE`: exact existing road, kerbs, wall/collision. Preserve existing Track DNA / physics / scoring / barriers.
- `B_CLEARANCE`: broad clear or protected zone between road and anything substantial. Add only suitable safety assets. Start with generous clearance; enlarge on high-speed outside corners and where an out-of-control car would travel. Never put trees, houses, spectators or concrete decoration in hazardous open areas.
- `C_TRACK_EDGE`: low grass/dirt, graded verge, tyres/barriers behind the clearance as appropriate, drainage ditch, embankment, safety fence, service gate. Use variation driven by terrain and curvature.
- `D_LANDSCAPE`: forest clusters, exposed cuts, rocks, retaining slopes, bushes and distance fog. Landscape massing fills most of view, not buildings.
- `E_PADDOCK`: 1–2 larger connected asphalt/hardstanding parcels, ideally near a start/finish or access road. Garage bays/canopy, tyre stack, tool container, service trucks, trailers, parking slots, pits/tech building, a few small Japanese utilitarian sheds.
- `F_EVENT`: grandstand or viewing terrace at a **safe** vantage point, control/commentator tower with sightline, track marshals behind barriers, ambulance and fire vehicle at designated access. Optional footbridge only if the site geometry and clearance support it.
- `G_DISTANT_SETTLEMENT`: occasional distant village lights and roofs on horizon/valley, NEVER a ring of suburbs along raceway. No houses in Phase A replacement.

**Ordering:** first terrain and no-build envelope; then functional zones; then deterministic clusters; then decorative detail, all validated against real road and barriers.

## 5. Specific Japanese art direction — Ebisu Forest, first playable world

- Main theme: **mountainside drift park in Fukushima, late summer/early autumn, daytime or golden hour.** Natural green and brown with slight atmospheric coolness at distance. Light gray maintenance buildings, corrugated metal roof blue/teal **only where appropriate**, yellow/orange safety items, neutral dark asphalt. Avoid excessive magenta tint and pink trees everywhere.
- Landform: 2–4 recognisable large hill masses; cuttings/embankments around bends; distant ridge across sky; rough service roads rising away from racing route; forest density varying by visibility.
- Forest: Japanese cedar/cypress-like conifers and broadleaf forms, foliage clusters with different shapes/scale; occasional maple or cherry if season fits; negative space for views. Distance LOD / impostors / instancing.
- Track detailing: irregular rubbered-in lines, tyre-wall segments, metal guardrails where appropriate, metal safety fence only where required, curbs not universal, patches of weathered tarmac and clipped grass.
- Paddock landmark: a single site-localized compound with low metal sheds, roof canopies, pit bays, team vans, parked drift cars, tyre piles, access gate, small sign, one control position, realistic lighting.
- Event overlay: practice day 0–few people; grassroots 1–3 tents + groups, championship more flags / broadcast structures / protected spectators. **People are not repeated static mannequins on every road segment.** Small palette-varied billboards/animations in carefully placed distant spectator clusters or omit entirely.
- Authentic details as accents only: Japanese-language functional wayfinding (パドック paddock, ピット pit, 立入禁止 no entry), vending machine at paddock, small roadside mirrors along access roads, utility poles where plausible. Do not add shrine gates or architecture clichés to a mechanical service complex.

## 6. What to model: realistic modular asset catalogue

### P0 / P1 (must show in the first visual test)
- `terrain_hill_lowpoly`, `terrain_cutting`, `embankment`, `retaining_wall`, `drainage`, `service_access_road`
- `tree_sugi_A/B/C`, `tree_broadleaf_A/B/C`, `mixed_tree_cluster`, `shrub_cluster`, `rock_group`
- `crash_barrier_type`, `armco_segment`, `safety_fence`, `tyre_stack`, `kerb_style`
- `paddock_asphalt_patch`, `pit_canopy`, `workshop_low_metal_01`, `service_portakabin`, `pit_garage_row_short` (ONLY inside paddock)
- `team_van`, `car_trailer`, `parked_drift_car`, `tyre_rack`, `cone`, `tool_cart`
- `access_gate`, `marshal_post`, `small_control_tower`, `signage`, `lamp_pole`

### P2 / optional depending on event
- `ambulance_static`, `fire_rescue_vehicle_static`, `recovery_truck`, `marshal_highvis_orange`
- `viewing_bank`, `small_grandstand`, `portable_commentary_platform`, `media_camera`, `temporary_tent`, `sponsor_flags`
- `pedestrian_bridge` only if a strong camera-visible landmark, geometry/safety permit, and mobile rendering remains acceptable.

### Not in default Japan Forest
- Generic family houses, suburban fences, shops, vast residential blocks, repeated street lamps at every corner, amusement-park rides, permanent neon everywhere, identical cherry blossoms in continuous rows.

## 7. Generator logic (preserve and extend Phase A)

1. Read existing drivable track geometry and collision polygons. Do not infer clearance exclusively from tile centres.
2. Derive local section features: straights, corners, high-risk outer arcs, interior islands, start/finish proximity, available contiguous flat/open pads, and potential viewpoint directions.
3. Reserve continuous `NO_BUILD` areas; account for banking/camera sightline. Buildings, trees, stands and spectator proxies must never intersect.
4. Build deterministic coarse **terrain context first** (`biome_seed`, `terrain_mask`, `distant_hills`), then group scenic assets using a blue-noise/Poisson-like pattern rather than a rigid module per tile.
5. Find **one** sufficiently large paddock zone that can connect via a safe service road. If no such polygon exists, generate only a small remote entrance/services area, or omit paddock rather than force impossible placement. If absolutely no space, keep the landscape clean.
6. Choose event-dependent optional scene landmarks (stand, commentary booth) based on sightlines and unoccupied valid pad area.
7. Chunk and cache only affected sectors; prefer stable global seeds + stable spatial IDs so edits do not reshuffle distant scenery. Do not rebuild a whole forest on each stroke.
8. Reuse same world data in Builder and Race; UNDO/REDO restores geometry AND environment deterministically.
9. Separate scenery generation from game performance and scoring. No accidental collision on playable road.

**Important limitation:** if existing Track DNA and road surface are entirely flat, full multi-level hairpin roads cannot be delivered by environment mesh alone. Layered distant hills and cuttings can be faked around a flat track now; real road elevation requires a separate, carefully planned Track DNA/physics/camera feature, not a stealth change in this art pass.

## 8. Asset styles: toy-like but recognisable

Use **stylised semi-low-poly / die-cast model aesthetics**: clear readable silhouettes, deliberately simplified geometry, realistic composition and scale relationships. Buildings should be recognisable as sheds and paddock garages, not cubes with triangular roofs. Use limited high-quality materials and detail decals. Natural environment should carry more visual mass than small prop clutter. From top view, terrain colours and forest massing must read; from chase camera, road edge and safety zone must stay readable.

## 9. Mobile performance constraints

Earlier Phase A reports 77.7k vertices / 3.7k tree elements and ~225 ms full world build, ~76 ms edit on server. These are local measurements, **not Android performance guarantees**.

- Use GPU instancing (Godot MultiMesh or equivalent rendering approach) for repeated trees, guardrail parts, vegetation and small props.
- LOD/HLOD by screen size; impostors for distant trees; avoid thousands of separate draw calls; collapse/substitute unseen backside details; keep materials shared.
- Avoid full rebuild while drawing; update on release or with scheduled local preview; ensure clear UX and no long stall.
- Benchmark on actual target Android device with the same track and camera from the uploaded videos; record FPS, 1% lows, input-to-update latency, resident memory and scene build time. No unsupported mobile claim.

## 10. Other worlds — identity by geography + venue, not random props

| World | Real-world reference basis | Defining visual signature | Venue type |
|---|---|---|---|
| Japan: Ebisu Forest | Ebisu, Fukushima | Sugi forest, cut hills, old asphalt, compact low paddock | Mountainside complex |
| Japan: Meihan Grassroots | Meihan C course, Nara | Black tyre-marked asphalt, wall-ride, tiny paddock and stand | Rural technical circuit |
| Japan: Okuibuki Alpine | Okuibuki, Shiga | Wide ski resort parking/temporary circuit, green mountains, tents | Pop-up competition |
| Japan: Gunsai Touge | Gunsai, Gunma | Mountain road, steep slopes, rock walls, almost no buildings | Closed-road time attack (later feature) |
| Finland: Forest Circuit | Ahvenisto, Hämeenlinna (2026 Drift Masters) | Spruce/pine woodland, lake country, weathered asphalt | Race circuit |
| Latvia: Riga Forest | Biķernieki, Riga (2026 Drift Masters) | Dense woodland enclosing the competition course | Race circuit |
| Germany: Iron Yard | Ferropolis, Gräfenhainichen (2026 Drift Masters) | Monumental bucket-wheel excavators, floodlights, open industrial hardstand | Industrial event |
| UK: Driftland | Lochgelly, Fife | Reconfigurable drift-only asphalt, grassy banks, small pit structures | Purpose-built practice |
| Wales: Coast | Anglesey Circuit / Trac Môn (landscape reference, not a claim of drift events) | Sea, cliffs, grassy coastal hills, strong wind | Coastal circuit fantasy |
| USA: Long Beach | Formula Drift, California | Temporary street course, skyline, palm trees, concrete wall, grandstands | Closed city streets |
| Original: Red Desert | Art direction, not a named real venue | Red rock, dry earth, bright sky, industrial paddock | Desert motorsport park |
| Original: Autumn Highlands | Art direction inspired by British landscapes | Heather, mist, pine forest, stone cuts and slate | Remote mountain drift |

Sources: https://dm.gp/articles/general/drift-masters-2026-the-next-chapter-begins/ ; https://www.formulad.com/schedule/2026/long-beach ; https://www.driftlanduk.com/ ; https://www.angleseycircuit.com/ (landscape example; verify site event details separately).

## 11. First milestone: JP FOREST V1 (visual reset)

The **same existing 24-tile test track** must show:
- no houses beside track;
- a convincing rolling forest/mountain backdrop on BOTH follow and top cameras;
- embankments/cuttings and varied vegetation clustered around road safely;
- **one** intentional paddock compound with 1–3 coherent functional structures and service vehicles, not repeated building frontage;
- proper tirewall/armco/curbs/lines as supported by existing physics/collisions;
- stable Builder/Race parity and local deterministic update;
- no regression to 24 existing tests, plus scenic rules tests;
- actual APK and Web captures, matched camera positions, performance logs on real Android.

### New automated scene tests

- `no_residential_buildings_in_JP_FOREST`
- `no_assets_inside_road_or_swept_safety_zone`
- `paddock_placement_uses_contiguous_lot_or_omits`
- `buildings_only_inside_paddock_or_authorized_event_zones`
- `stable_seed_no_remote_shuffle_after_edit`
- `undo_restores_world_hash`
- `all_track_rotations_supported`
- `long_straight_not_wall_of_garages`
- `safe_spectator_site_or_none`
- `top_and_follow_camera_visual_readability`
- `mobile_target_BENCHMARKED_not_estimated`

### Art-review board: mandatory comparisons
1. Real Ebisu aerial vs generated top-down at same general scale.
2. Real Ebisu low-angle roadside vs generated follow camera.
3. Paddock closeup vs real small grassroots paddock (Nikko/Meihan).
4. Same test track in three environment variants (forest, grassroots, alpine temporary).
5. Before/after of v0.1.23 with no changes to scoring, controls or physics.

## 12. Prioritisation and 'definition of done'

- **P0**: remove residential roadside placement; rezone assets as functional sports site; simple forest/backdrop; preserve functioning edit generator.
- **P1**: actual relief/scenic environment, clustered paddock and appropriate roadside safety context; two visually distinct views; independent Biome/Venue/Event config.
- **P2**: event overlay, spectator proxies, support/emergency vehicles, enhanced terrain, season/weather and richer props; optimisation based on Android profiler.
- **Later**: point-to-point mountain roads, persistent elevation/road banking, broader world library.

**Stop for visual approval** after P1. No claim that the world is done based only on unit tests.

## 13. Research links and supporting visual references

- Ebisu official courses: https://www.ebisu-circuit.com/course.html
- Ebisu area map: https://ebisu-circuit.com/areamap.html
- Fukushima Tourism Ebisu overview: https://fukushima.travel/destination/ebisu-circuit/56
- Fukushima Tourism drift experience: https://fukushima.travel/blogs/drift-taxi-experience-at-the-ebisu-circuit-/148
- Meihan grassroots layout, pads & stands: https://www.motorsportradar.com/tracks/meihan-sportsland/
- Nikko official site: https://www.nikko-circuit.jp/
- Okuibuki official motor park: https://www.okuibuki.co.jp/green/motorpark/
- Gunma Cycle Sports Center official: https://www.gunsai.jp/circuit/
- Formula Drift Japan 2026 venue schedule: https://formulad.jp/race/2026/
- Drift Masters 2026 world venue gallery: https://dm.gp/articles/general/drift-masters-2026-the-next-chapter-begins/
- Scottish Driftland: https://www.driftlanduk.com/
- Formula Drift Long Beach: https://news.formulad.com/2026/fd-news/conor-shanahan-wins-round-1-of-2026-formula-drift-pro-championship-in-long-beach/
- Anglesey coastal circuit images as visual, not drift-specific reference: https://racecollective.com/tracks/anglesey-circuit/

## 14. Message to implementation agent

> **STOP original Phase B content direction.** Phase A v0.1.23 passes technical checks, but its residential town art direction fails the real drift-circuit brief. Do not generate a suburb, generic homes or shopfronts along the track. Preserve track geometry, physics, camera controls, deterministic chunk updates, Undo, and Builder/Race parity. Build a new research-accurate Japan/Ebisu-style forest motorsport environment with terrain mass, cut slopes, tree clusters, access roads and ONE believable paddock complex. Treat professional event infrastructure as an optional overlay. Separate `biome`, `venue_archetype` and `event_state` and enforce no-build/safe spectator zones. Render BEFORE/AFTER from top and follow cameras, plus paddock detail, and run on Android before claiming performance. Stop after the first successful visual reset for art approval.

**Document scope disclaimer:** the precise scene placement, performance architecture and design distances are project proposals, not facts claimed by sources. Circuit facts and current event venue references are linked above. Exact physical circuit layouts should not be copied 1:1 without design/license review; create original levels inspired by authentic environments.
