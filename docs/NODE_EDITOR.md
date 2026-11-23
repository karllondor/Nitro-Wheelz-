# NODE EDITOR — open builder circuits, shape them, set the START (v0.1.42)

Owner request 2026-11-23 (chat): circuits made in the Terrain Builder or the 3D tile builder must be loadable in EDIT NODES to be shaped
further, and the START point must be settable ("or at least the first point you put on the map, direction = the next part").
Branch `agent/claude/node-editor-open-start` (stacked on `agent/claude/issue-31-local-multiplayer`, v0.1.41). Handoff:
`docs/dev/handoffs/node-editor-open-start-20261123-claude.md`. Code: `game/scripts/world/track_edit_tools.gd` (data helpers),
`game/scripts/ui/track_editor.gd` (UI), 3 small routing hunks (see below).

## What changed for the player
* **TRACK BUILDER → EDIT NODES** now opens the circuit you touched last — a circuit you just saved in the Terrain Builder, the 3D tile builder or this
  editor (before: only the last circuit saved from the node editor / tile builder; a Terrain Builder circuit was bounced back to the Terrain Builder).
* **OPEN…** (new button) lists every saved circuit with its type (TERRAIN • SAKURA, 3D TILES, NODES) and length, newest first, plus copies of the four
  built-in circuits (SHIN-KAWA, SHIN-KAWA • FULL CIRCUIT, OVAL, SWEEPERS: they open as an unsaved copy, the original is never changed). UNDO brings the
  previous circuit back.
* **Terrain circuits keep their landscape.** The map shows the terrain (blue = water / sea, shaded land, thin frame = the area where the Terrain Builder
  puts road). While you drag nodes the editor checks the road against that terrain: a stretch over water, over a sea cliff or in an impossible cutting is
  **red**, the status line says why ("TERRAIN • ROAD EDGE OVER THE CLIFF / SEA • MOVE THE RED NODES") and SAVE AS / DRIVE are refused until it is fixed.
  Valid circuits say "… • TERRAIN OK". SAVE AS re-solves the road heights on the saved landscape (exactly what the Terrain Builder does) and keeps the
  world (archetype + seed), so the race builds the same hills, bridges and scenery around the new road.
* **SET START:** tap a node, tap SET START → that node becomes the start line; the car starts there and drives towards the next node (the green arrow and
  the "START" label on the map show it). The road itself, its length and its heights are unchanged. **REVERSE** drives the same road the other way round
  (the start stays on the same node). Both are UNDO-able. Rule used by the race: start = knot 0, direction = towards knot 1 (unchanged).
* The button area has four rows now (nodes | start + fix | file | leave + drive); the map is a little shorter.

## Terrain builder interplay (one-way)
A circuit saved from the node editor is marked `builder.nodes_edited = true`: the tiles in the file describe the road as it was *before* you shaped the
nodes, so the Terrain Builder **refuses to load them** (it would replace your shaping by the old tiles). MY TRACKS > EDIT in the menu, EDIT TRACK in the
results screen and the Terrain Builder's own MY TRACKS list send such a circuit to the node editor instead. Circuits you did not shape keep opening in the
Terrain Builder as before. 3D-tile circuits already opened in the node editor; shaping them was already a one-way step (the race ignores their procedural
world when the road no longer equals the tiles, and keeps it when you only rotate the start or reverse).

## Not in this version
* **Point-to-point routes** (Terrain Builder "ROUTE") are not edited in the node editor (it works on closed loops): OPEN lists them, tapping one opens them
  in the Terrain Builder as before.
* Builders themselves still start a loop on "the first longest straight, counter-clockwise" (deterministic save / load); the start of a built circuit is
  changed here with SET START. If you want the Terrain Builder / 3D builder to put the start on the **first tile you place** instead, that is a separate,
  small change in `terrain_track.canonical_loop` / `track_grid.loop` (and #29 owns those files) — say so.
* No overlay of the Terrain Builder's yellow/orange "buildable with a structure" classes; only the hard refusals (water, cliff, impossible cut / fill) are red.

## Data details
* `NitroTrackEditTools.rotate_start(data, i)` / `reverse_direction(data)` apply one permutation to `control_points`, `widths_m` and `elevation.knot_heights`
  (so knot heights follow their nodes) and keep `start_index = 0`.
* `fit_terrain(data, field)`: `DNA.compile` → `road_profile.solve` on the field rebuilt from `world.archetype` + `world.terrain_seed` → new
  `elevation.knot_heights` → `terrain_track.evaluate`; flagged nodes = the two knots of every sample classified "unbuildable".
* Cost (desktop, headless): field bake ≈ 0.25–0.35 s, road solve ≈ 20 ms; the editor shows a short "LOADING TERRAIN" card when it opens a terrain circuit on a
  device and validates after every release of a node.
* Which circuit opens: explicit marker (`user://nitro_editor_last_path.txt`, written by MY TRACKS > EDIT, results > EDIT TRACK and by every save) — or, for
  TRACK BUILDER > EDIT NODES (`nitro/editor_open_latest`), the newest saved closed circuit / the marker if it is newer.

## Tests
`node_editor_open_test` (new, in `tools/run_godot_checks.sh`): kind detection, OPEN list (terrain + 4 built-in copies), a terrain circuit opens with its field,
picture and "TERRAIN OK"; SET START (knot 0 / knot 1 / heights / identical road and length / heading to the next node), REVERSE (heading flips, length kept),
UNDO; a road slid onto the sea is refused with red nodes, a terrain message and no save; SAVE AS keeps the world, re-solves heights (one per node), marks
the circuit node-shaped, is buildable and compiles with heights; the race builds the terrain and starts on knot 0 towards knot 1; the Terrain Builder refuses
the file and the boot menu routes it to the node editor (untouched terrain circuits still go to the Terrain Builder); EDIT NODES asks for the latest circuit;
built-in circuit opens as a copy, flat circuits save with the start on knot 0; the four button rows have no overlap and are finger sized.
Existing `editor_geometry_test`, `editor_results_test`, `track_builder_test`, `terrain_builder_test`, `builder_touch_test`, `track_records_test`, `main_menu_test` still pass.
**NOT proven:** finger feel and the layout on a phone, the busy card timing on a device, open routes.
