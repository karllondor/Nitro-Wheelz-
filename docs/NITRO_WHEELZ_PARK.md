# NITRO WHEELZ PARK (issue #27, v0.1.37)

ONE big open flat paved surface: donuts, two figure-eights, a longer flattened eight, orange cones that never stop the car, the full
NITRO WHEELZ logo painted flat in the middle. Two ways in to the SAME place: **START TUTORIAL** (guided lessons) and
**FREE DRIVE = SKIP TUTORIAL** (no lessons, no gates, no scoring). Main menu: PARK. Status: CODE_READY, **phone NOT RUN**,
layout PROVISIONAL (owner has not approved outline, dimensions or positions).

## What the player gets
- **No walls, no kerbs, no collider.** Paint is paint. A far invisible soft edge (30 m outside the paving, silent, no shake) only keeps the
  car in the world. No lap, no finish, no score, no stars, no records: the Park never feeds the star total or a leaderboard.
- **Cones** (80, one draw call): movable props. A touched cone is pushed along the car's motion, tips over and slides to a stop;
  the car is never affected (no physics body, `park_layout_test` proves the car state is identical with and without cones). Cones
  return to their guide positions at the start of every lesson and on RESTART; SKIP leaves cones and paint exactly as they are.
- **The logo:** the existing approved full logo (`assets/brand/nitro_wheelz_logo.svg`, git blob f9d7b56..., unchanged and checked by
  `park_layout_test`), rasterised 1:1 at 1488 x 838 px into `nitro_wheelz_logo_pavement.png` (tools/art/render_logo_svg.gd, scale 2.4)
  and laid flat at the centre, 36 m wide, "up" = north (reads from the start). A light wear shader (`pavement_paint.gdshader`) roughens
  the paint with sparse specks; outline, colours and proportions are untouched. Not the NW launcher icon.
- **Tutorial (optional):** 10 lessons, each judged by what the car and the REAL controls did (never a tap or a timer):
  GAS -> steering -> BRAKE -> HANDBRAKE -> first slide -> DONUT left -> DONUT right -> large eight -> small eight -> the long eight.
  The next lesson starts by itself the moment the manoeuvre is really done. Exercise lessons open with a dimmed schematic with arrows
  (the car stands still until a tap, or 8 s); then driving is unobstructed, with a lesson card in the header, pulsing highlights on the
  real touch targets (the L-shaped GAS, BRAKE, HANDBRAKE, joystick), an off-screen arrow + distance to the exercise, a light beacon over
  it, a demonstration ghost on the ideal line (toggle DUCH), POMIŃ (skip), OD NOWA (repeat). Polish text = the owner's own hints
  (English in the table too, `park_tutorial.gd` `LANG`). Hints after 15 s without progress; a calm remark when a cone is hit.
- **Pause menu** gets one row: TUTORIAL ON (tap = skip) / OFF (tap = start at the first open lesson).
- **Saved:** `user://nitro_park.cfg` (completed lesson ids). The PARK page offers START / CONTINUE n/10 / RESTART TUTORIAL.

## Layout (all in `scripts/park/park_layout.gd`, PROVISIONAL, metres, x east / z south)
Pad: rounded rectangle 340 x 260 m. Logo centre (0, 0), 36 x 20 m. Start (0, 30) facing north. Donut rings radius 10 m at (+-105, 0)
(left = counter-clockwise). Large eight: circles R 15, spread 1.35, at (-70, 80). Small eight: R 9 at (70, 80). Long flattened eight
(the miniature circuit): R 18, spread 2.6, at (0, -80), 314 m, curves >= 18 m radius, corridor 7 m with cone lines every 9 m,
yellow dashed centre line with direction chevrons. Radii are not arbitrary: a starter car on the real drive model holds a drift circle at
r = 5 - 9 m (measured on the E30, the weakest car, and the Lada), and follows the long route at 35 - 45 km/h inside the corridor.

## How the code is organised
`park_layout.gd` data + eight geometry + cone list | `park_track.gd` (`NitroParkTrack extends NitroDriftTrack`: pad, paint, logo; talks to
`race.gd` through the normal track interface: no walls, width "infinite", no finish) | `park_cones.gd` | `park_detectors.gd` (Orbit /
Eight / Route / FirstSlide, pure logic) | `park_tutorial.gd` (state machine + lesson table) | `park_guide.gd` (UI) | `park_ghost.gd` |
`park_progress.gd` | `park_controller.gd` (the glue; created by `race.gd` only for the Park). `race.gd` changed in 6 small places
(class choice, controller hooks, freeze, restart, pause row), `race_hud.gd` (park mode: gauge + angle only), `race_pause.gd`
(extra row), `boot.gd` (PARK page, the Park is never "the track you last raced"). Circuits, the track registry and the drive model are untouched.

## Detection (tolerance based)
Donut: >= 320 deg of rotation in the asked direction around the cone, inside a ring of 0.22 R .. 1.7 R, drifting (slip >= 14 deg) at least 50 % of the
time, resets after 2 s outside the ring. Eight: both lobes >= 235 deg in their own directions (nearest-lobe assignment), >= 1 transition and the slip
side flips between the lobes, drifting >= 35 %. Route: >= 92 % of the line driven in either direction, >= 70 % of the time inside the corridor,
drifting >= 12 %. First slide: slip >= 18 deg for 0.6 s then < 8 deg for 0.5 s. Controls: GAS held >= 1 s while moving; steering both sides >= 0.4 s
while moving; BRAKE from >= 22 km/h losing >= 8 km/h; HANDBRAKE at >= 20 km/h.

## Tests (headless) and measurements
`park_layout_test` (layout, no collider, logo asset + proportion + flat + centred, eights are eights, route radius, cones, starter car follows the
route, soft edge, cones never change the car), `park_tutorial_test` (detectors on real drive-model runs, state machine, persistence, cones, ghost, race scene,
menu). Performance on this container (headless): layout cones 1.2 ms, track build 5.8 ms, cones build 1.4 ms, cone step 4.9 us per tick, pad + paint + logo 1,318
triangles (environment excluded) + 80 cones in one draw call (80 x ~110 triangles). NOT measured: any frame rate on a phone.

## NOT RUN / open
Everything on a phone (touch prompts, readability of the card and the buttons at real size, the beacon and arrow, cone feel, free-drive feel, the font
fallback for Polish letters on the device). Eights and the long route are proven FEASIBLE for a starter car by a path follower, and the detectors on synthetic
trajectories; a scripted DRIVER that drifts a full eight on the real model was not built, so "a human can drift the eights with the starter car" is NOT proven.
Open owner decisions: pad outline / size / cone positions, the exact exercise thresholds, whether the white Lada (N20) should be the starter car here.
