# Multiplayer reliability v2 and Park handoff

Issue #31. Review branch `feat/multiplayer-reliability-v2`, based on `integration/nitro-dev` at `9d3aab09e329bb342529c0ade8743f23339fa678`. The lobby identifies this preview as protocol 2. Both devices need the same review APK. Requested model GPT-6.2 Astra High. The executor identifies itself as GPT-6 Codex and does not independently expose the exact variant.

## What a player sees

The host can restart from pause, keyboard or results. Both cars return to separate grid slots, the HUD and input reopen, the scorer and lap state clear, and both games acknowledge the reset before the host schedules 3, 2, 1, GO. A local pause stops that car. Elapsed LAN time includes the pause and runs from the shared GO. Solo retains its first-throttle clock.

The first finisher sees both drivers immediately. The other driver can finish independently. Both boards sort by drift points, then by finish time, with grid slot as the stable tie-break. An unfinished row shows RACING or DNF and its last reported points. Finished rows survive a disconnect. These are session results with peer-reported scores. They never reach the progression or record store.

A bright cyan ground ring and outlined overhead name mark the opponent in either camera. The body retains its own paint, livery and wheels. A stripe selection is reconstructed from the sender's garage fields against the local catalog.

## Performance evidence

Godot 4.7.2 Linux headless, same countdown callback, same car and input, 30 measured batches of 600 calls after one warm-up batch. Values are microseconds per call, with percentiles across batch means.

| Countdown callback CPU | v0.1.45 base | Review branch |
|---|---:|---:|
| Median | 15.06 | 0.62 |
| p95 | 16.81 | 3.41 |

To repeat, import each checkout and run `godot --headless --path <checkout>/game --script <absolute-path-to-feature>/tools/bench_net_countdown.gd`. The base reapplied the countdown colour and label and evaluated a stationary remote pose every frame. The new path updates the countdown on a digit change, refreshes live text at 10 Hz and buffers poses while grid-locked. The lobby requests the race scene in the background. Both cars and their materials are instantiated before the load acknowledgement. Two process frames allow the scene to present before the countdown. GPU shader compilation can still occur on first drift.

The existing simulated link test still reports zero jumps above 0.5 m with the v0.1.45 adaptive receiver across 7 scenarios and 5 seeds, worst 0.35 m. Its historical comparison against v0.1.44 is 21 jumps. This branch retains the v0.1.45 receiver. No phone FPS, radio latency or end-to-end Android speedup was measured.

## Regression coverage

Run `bash tools/run_godot_checks.sh` with pinned Godot, or run `python3 tools/test_net_rounds.py` after importing the project. The latter starts two independent game processes with separate user profiles and real ENet sockets. Each host plays three rounds. Measured GO callback differences on local loopback were 7, 3, 5 ms with Karll hosting and 3, 2, 2 ms with Kevin hosting. The test checks visible countdown digits, a double restart, disabled client authority, both grid slots, clearing old lap/score/input state, delayed previous-round traffic, live result updates, points and time tie-breaks, a striped RYU-32 and both directions of disconnect. It sets final times and points at the finish presentation to make ranking cases deterministic. The regular race and lap tests cover driving and line crossings.

Headless Godot can report an existing ObjectDB warning during audio teardown. Two physical Android phones, hotspot radio, thermal frame pacing and visual readability still need owner testing.

## Owner test on two phones

| Test | Action | Expected |
|---|---|---|
| First tandem | Install the same review APK on both phones. Pick different cars, including a striped RYU-32. On home Wi-Fi, both press READY, then the host presses START. Hold GAS in the countdown. | Both see 3, 2, 1, GO, start in separate slots and stay still until GO. Record the first ten seconds on each phone if the car jumps. |
| Restart while driving | Drift and advance a lap. Pause the guest. Host pauses and confirms RESTART. Repeat three times, including once while the guest holds a pedal. | Both return to lap 1, zero points/time, empty combo, separate slots and a fresh countdown. No previous inputs or old car position should reappear. |
| Compare runs | Finish at different times. Give the slower driver more points. Restart from the host's result screen. | The first finisher sees the other driver still racing. Both final boards show the same driver names, cars, points and times. The higher score ranks first. |
| Camera and pacing | Switch between Chase and Top-down, side by side and a few car lengths apart. Compare the first start with a warm restart. | Each remote car keeps its livery and has a visible cyan ring and name. Report camera, first/repeat run, LINK word and which screen stutters. |
| Disconnect | Leave on one phone during countdown and again after one driver finishes. Re-create the room with the other phone hosting. | The survivor can drive or exit, unfinished peer shows DNF on results, completed rows remain, and a fresh room starts cleanly. |
| Hotspot | Disable mobile data, enable one phone's hotspot, join it from the other phone, and enter the host's local IP. Repeat with hotspot and game host roles exchanged where supported. | Both join and complete the same restart and finish checks with WAN off. Record the failing step and handset if the hotspot isolates clients. |

## For the Park multiplayer developer

- Reuse `NitroNetSession` for the roster, stable slot IDs, clock and disconnect signals. `round_restarted` means clear scene-local state, then call `report_loaded()`. Initial scene load uses `report_scene_ready()` after track, controllable car and remote visuals exist. The host sends the deadline only after both acknowledgements.
- Reliable START/RESTART/LOADED/COUNTDOWN/FINISH messages and 44-byte unreliable ordered snapshots carry a round ID. Preserve this boundary when adding Park events. Absolute clock values belong to one device and need the host offset on the joiner.
- Keep free drive separate from scored races. The four current circuit IDs are allowlisted and fingerprinted. Park needs an explicit mode and agreed layout identity, spawn slots, occupancy and session ownership before enabling it. A Park lesson overlay must not let one client reset the other's session.
- The remote car is visual-only. Replicated cone motion, shared tutorial state, mid-round join and host migration are outside this protocol. Decide ownership of those objects before adding messages. Leaving returns to the existing local-only flow.
