# Nitro Wheelz v0.1.49 track review

Base `3f4f4c668c6c98983a55cec91c197f1984779cfc` on `integration/park-unified-rc` (PR #44). Review branch `feat/three-circuits-v0149`. Engine Godot 4.7.2.stable, commit `ed1daf0bf`. Implementation by Codex. Exact serving model identifier unavailable in the workspace.

| Built-in track | Track DNA length | Width | Knots | Mode |
| --- | ---: | ---: | ---: | --- |
| Driftwood Circuit | 3548.998 m | 24 m | 48 | Three-lap circuit |
| Testandori Raceway | 1350.999 m | 24 m | 71 | Three-lap circuit |
| Fuji Speedway Short | 1286.001 m | 24 m | 68 | Three-lap PRO circuit, 46 sectors |

## Geometry provenance

The owner's reference pack supplied three Track Editor JPEGs. Fetched GitHub history had no matching track JSON. The [earlier Driftwood claim](https://github.com/karllondor/Nitro-Wheelz-/issues/33#issuecomment-7135511775) documented a reconstruction but did not include its coordinates.

- Driftwood used the 12 visible editor knots in clockwise screen order, from the upper-left START toward the high apex. The original traced Catmull–Rom curve was sampled by arc length and refitted with 48 knots. The sparse reconstruction passed forward validation but rejected the reversed road near a short segment at a tight bend. The denser fit keeps both directions valid and preserves the major bends. The maximum source-knot-to-compiled-centre distance was 6.2 px (about 9.4 m).
- Testandori used the visible editor knots in order from the right-hand START, heading down. The fit kept the stacked hairpins and separated adjacent road corridors. Maximum source-knot deviation was 3.3 px (about 2.0 m).
- Fuji followed the reference's lower straight clockwise on the screen from START toward the right. The screenshot gives no width or elevations. The review uses the 24 m CIRCUIT width and the existing Sakura terrain generator with terrain/scenery seed 128601. The road profile solver produced a maximum grade of about 2.86%. The terrain evaluator accepted the road. Maximum source-knot deviation was 0.9 px (about 0.7 m). This is the owner's in-game reference layout reconstructed from a screenshot. The terrain, dimensions and provenance make no survey or official affiliation claim.

All three traces use image x/z orientation with no reflection. The start is knot 0. Scale was set using the full sampled closed-loop length, then confirmed in Godot. The [Driftwood](evidence/three-circuits/driftwood_circuit_overlay.jpg), [Testandori](evidence/three-circuits/testandori_raceway_overlay.jpg) and [Fuji](evidence/three-circuits/fuji_speedway_short_overlay.jpg) overlays mark the sampled centreline in pink and driving direction in yellow. The [Linux Godot viewport captures](evidence/three-circuits/linux-godot-runtime.jpg) show the editor and opening drive on each route at 720×1536 using Mesa llvmpipe.

## Integration and checks

`DRIVE → track selection`, `TRACK BUILDER → EDIT NODES → OPEN` and the native LAN lobby include the same three JSONs. The editor opens an editable copy and SAVE AS assigns a separate layout record ID. Fuji's PRO result uses the existing event summary and routes EDIT ROAD to the Node Editor. Its judged score stays in the event summary, following the existing PRO mode. Driftwood and Testandori use ordinary per-track bests and stars. LAN retains protocol 6, the game-version handshake and SHA-256 track verification. Use the same v0.1.49 review build on both devices.

The pinned regression suite includes `three_circuits_test`. It exercises menu selection, editor OPEN, SET START, REVERSE, AUTO-SMOOTH of already valid layouts, SAVE AS and reopen, real throttle launch on every route, the lap state machine through three simulated laps, reverse start-line protection, record isolation, and the PRO judge's sector award and re-entry gate. The existing multiplayer suite checks both start slots for every whitelisted circuit. Automated laps exercise progression by feeding progress samples. The owner checklist covers complete manually driven laps.

The Android review workflow uses `com.karllondor.nitrowheelz.review.pr<PR number>`, versionName 0.1.49 and versionCode 49. Its emulator job installs that APK, exercises the same checks and captures the six visible editor/race screens. See the draft PR checks for build and emulator status. Physical phone, paired Wi-Fi/hotspot and handset performance approval are pending.

## Owner playtest

1. Open DRIVE and choose **Driftwood Circuit**. Start toward the high apex. Take the central zigzags and complete three laps. Check the finish screen and your separate best.
2. Open **Testandori Raceway**. Start down the right side. Learn the close hairpins at low speed, then link them at drift speed. Switch between Chase and Top-down and check whether the adjacent lanes remain easy to read.
3. Open **Fuji Speedway Short**. Start right along the bottom straight. Compare the upper hairpin and S-bends with your reference. Drift through the coloured PRO sectors and check the result summary. Try backing into a sector you already passed.
4. In **TRACK BUILDER → EDIT NODES → OPEN**, compare all three silhouettes, then SET START, REVERSE and SAVE AS on a copy. Reopen it, tap DRIVE and return to the editor.
5. Install the same review APK on two devices. Host each new track, join over Wi-Fi or hotspot, compare the start positions and complete a race. Swap host roles. Record anything that feels tight or hard to read with track name, camera and a short clip.
