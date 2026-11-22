# Nitro Cockpit UX review (issue #28, DESIGN ONLY)

Owner report (via ChatGPT, #28 c7080744261 / c7080848490): menu navigation and in-race controls look visually confusing. Scope of this document: a
screenshot-grounded review, touch-ergonomics measurements, **two** mock-up directions and a menu-flow proposal. **No control, hit-box, HUD or menu code is
changed** (owner rule: design first, approval before code; the #17 camera stays on hold). Status: **DESIGN_PROPOSED, nothing implemented, phone NOT RUN.**

What I looked at: the real game, v0.1.38, rendered headless on a display at 720 x 1600 (9:20, the shape of the owner's 1080 x 2400 phone) by
`game/tests/capture_ux_review.gd` (7 menu pages, garage, race HUD chase + top-down, pause, PARK free drive). **I did NOT see the owner's 107 s recording**
(`1000077142.mp4`) or ChatGPT's QA clips: they are not in this environment; the findings below come from the game's own frames and code, and agree with the points
ChatGPT listed (startup icon, long menus, mixed HUD styles). Evidence: `docs/dev/handoffs/evidence/issue-28-*.jpg`, geometry `issue-28-touch-geometry-1080x2400.json`.

## 1. Findings (numbers refer to `issue-28-current-annotated.jpg`)
**Race HUD**
1. **Five visual languages in one frame**: a glass, skewed header with a minimap; an analogue chrome dial; photographic perforated metal pedals; a chrome joystick ball; a black
   handbrake lever with an NW plate. Each is good alone; together they do not read as one cockpit.
2. **PAUSE 7.7 x 4.9 mm and CAM 8.1 x 4.9 mm** (assuming 15.5 px/mm, see below): under the usual 9 mm (Android 48 dp) minimum in height. Deliberately small to avoid accidental taps, but they
   also sit in the hardest corner to reach.
3. **Score call-outs ("KERB CLIP x1.5", "WALL! CHAIN LOST") are stacked across the middle of the picture**, i.e. over the road ahead, at the moment of the most important decision.
4. **GAS, BRAKE and HANDBRAKE are all on the right side** (3 controls for one thumb) and the handbrake is the tallest control (13.1 x 46.5 mm, starting at 47 % of the height), so its top two thirds
   are out of easy thumb reach; it needs a finger the player may not have free while holding GAS.
5. **Speed and drift angle are separated**: a dial (labelled only to 160 km/h; ARCADE_PLUS cars now exceed 200, the needle stops at 200) and a small separate chip for the angle, which is
   the number a drift game cares about most.
6. **Steering ring is 24 mm in diameter**: usable but small for a primary control, with no visible dead-zone / reach hint.
7. **Pedals are good targets** (BRAKE 11.1 x 20.4 mm, GAS 11.0 x 29.4 mm) but their high-contrast perforated texture competes with the road for attention.

**Menus** (home / race setup / the rest in `issue-28-current-annotated.jpg` and the captures)
- M1 The big logo is repeated on every page and takes 25-30 % of the height; content is centred, not in the lower thumb zone.
- M2 RACE SETUP glows two primaries (TRACK and DRIVE) while CAR looks secondary; the real primary is not obvious.
- M3 **DEVELOPER is a first-level button on the player's home page** next to QUIT.
- M4 Getting to a race takes DRIVE > (TRACK) > (CAR) > DRIVE; the track list and the garage are separate full pages with their own BACK targets.
- M5 Garage: five car tiles with 6-8 pt labels, BACK / DRIVE both neutral; settings: tiny labels and sliders.
- M6 **Language is mixed**: all menus are English; the PARK tutorial is Polish (constant `LANG = "pl"` in `park_tutorial.gd`, owner's own wording) and there is **no language setting** at all.
- M7 The "STARS" chip says "0 STARS" per player while the approved design is five permanent stars per official track summed globally (not implemented yet): the profile area will need
  a second line / progress ("next unlock at N"), which the layouts below already reserve.

## 2. Touch ergonomics (1080 x 2400, `RaceTouch._layout`, portrait)
| control | size px | size mm (15.5 px/mm) | position (share of screen height) | comment |
|---|---|---|---|---|
| PAUSE | 119 x 76 | 7.7 x 4.9 | 12 - 15 % | below the 9 mm guideline, top corner |
| CAM | 125 x 76 | 8.1 x 4.9 | 12 - 15 % | the same |
| HANDBRAKE | 203 x 720 | 13.1 x 46.5 | 47 - 77 % | very tall, upper part out of reach |
| BRAKE | 173 x 317 | 11.1 x 20.4 | 85 - 98 % | fine |
| GAS (L shape) | 171 x 456 | 11.0 x 29.4 | 79 - 98 % | fine |
| STEER ring | 378 across | 24.4 across | centre 85 % | small for a primary control |
Assumption stated once: a 1080 x 2400 panel of about 69.7 mm width (6.5 - 6.7 inch phones, 395 - 405 ppi); the owner's phone model is not known, the ratios hold for any phone.
Guideline values used: Android Material 48 dp (about 9 mm), Apple 44 pt (about 7 mm), research targets of 9 - 10 mm for thumb taps (general UX guidance, not a game rule).

## 3. Direction A: NITRO COCKPIT (`issue-28-direction-A-cockpit.jpg`) - evolve what the owner approved
One hardware language: dark glass + chrome + neon rim for EVERYTHING (header, dial, keys, lever), pedals kept (the owner approved the L-shaped gas) but enlarged and aligned.
- Header: PAUSE and CAM move INTO the header strip as two 9 mm keys (no floating buttons); score call-outs become a compact feed under the header's left half, never over the road.
- Cluster: dial + drift angle in one unit (angle printed inside the dial, large), dial labelled to the real top speed of the car.
- Controls: steer ring 24 > 31 mm with a visible dead-zone ring; handbrake lever shortened (zone 52 - 76 % of the height) and labelled; pedals larger on one baseline.
- Menus: **home hub** (profile strip with total stars and the next unlock, a big CONTINUE card with one START, PARK and TRACK BUILDER as cards), **bottom navigation** (HOME / GARAGE / PARK / PROFILE / SETTINGS)
  in the thumb zone, logo only on the home page, DEVELOPER hidden behind 7 taps on the version label, **RACE SETUP as two carousels (track, car) and ONE DRIVE at the bottom**.
- Risk: low to medium. Mostly layout, sizes and one shared look; same touch model, so no relearning. Cost: HUD style + race_touch geometry + boot menu pages (one version).

## 4. Direction B: NITRO ARCADE (`issue-28-direction-B-arcade.jpg`) - game first, fewer things on screen
- HUD: one slim pill (lap, score, time) with the next-star bar as a hairline; minimap on demand; speed as big italic numerals with a thin drift-angle arc (no dial); call-outs as centred chips under the pill;
  PAUSE / CAM as 9.3 mm round icons in the two top corners (96 px discs).
- Controls: flat translucent pads in the thumb arcs (steer ring 25 mm; GAS 22 mm disc; BRAKE 14 mm disc; DRIFT as a 22 x 9 mm pill above GAS); the photographic pedals and the lever disappear.
- Menus: the same pages as today but ONE glowing primary at the bottom (RACE / DRIVE), logo only on home, DEVELOPER hidden, the track and the car shown as two summary cards with CHANGE.
- Risk: higher. Cleaner and quicker to read, but it drops the approved pedal / lever look, changes the muscle memory (DRIFT as a pill instead of a lever) and the owner liked the cockpit feel. Cost: larger.

## 5. Recommendation and what I need from the owner
Recommended: **A**, implemented in one version, taking two things from B that are independent of the look: the call-out placement and the 9 mm keys (both are in A already). Decide once (one message is enough):
1. Direction **A**, **B**, or A with specific elements of B?
2. Language policy: Polish everywhere, English everywhere, or a LANGUAGE setting (PL / EN)? (Today: menus English, PARK tutorial Polish.)
3. May DEVELOPER move behind 7 taps on the version label (players never see it; you still can)?
4. Should the HUD gauge follow the new top speeds (up to 225 km/h)? (A needs the dial scale to change: a HUD change, not part of the physics task.)
Not decided here, not implemented: any code change to controls, hit-boxes, menus or the HUD; the #17 camera.

## 6. How the review was made (reproducible)
`OUT_DIR=<dir> xvfb-run -a -s "-screen 0 720x1600x24" godot --path game --rendering-driver opengl3 --resolution 720x1600 --script res://tests/capture_ux_review.gd`
then `python3 tools/design/ux_mockups.py <dir> <out>`. The mock-ups are drawn over real frames (the clean-world capture) and are **not** screenshots of an implementation.
