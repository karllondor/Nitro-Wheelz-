# Nitro Track DNA — P0 Architecture Experiment

**Version:** 0.1.5 proof of concept. This is a deterministic, spline-based geometry pipeline, not Wave Function Collapse and not yet a shipped community track editor.

## Canonical sources
- `game/tracks/shin_kawa_v2.json`: hand-designed ordered centreline control points and width data.
- `game/scripts/world/track_dna.gd`: data compiler, Catmull-Rom sampler and geometry validator.
- `game/scripts/world/drift_track.gd`: the rendered road, its visible barriers and matched collision geometry.

The canonical track is one **closed, oriented** loop. Width is interpolated per control-point interval; no separate meshes or hand-authored kerbs are required for each curve. The first point and tangent are the starting line. Each sample yields centre point, road half-width, both road edges and cumulative distance. A stable seed is reserved for future scenery placement but no randomness currently changes the playable corridor.

## Hard invariants (P0)
1. Inputs are finite; 8+ ordered knots, closed flag, no adjacent duplicates.
2. Width profile is either omitted or exactly one entry per knot. Range initially 12–34 metres.
3. Sample edges must be non-degenerate, avoid self-intersections and have enough turning radius for the specified width.
4. Two nonlocal track segments require clearance greater than the sum of their half-widths plus the corridor margin.
5. White edge lines, shoulder, tarmac, *rendered* blue/white walls, StaticBody3D wall triangles, and the analytic collision response all come from the **same** compiled left/right edge samples.
6. A failed edit must not replace the last known valid circuit.
7. Track closure and start line orientation are tested; invalid maps are not published.
8. The walls are static colliders for PhysicsServer users. The arcade car uses an analytic deterministic planar controller, so it resolves contact from identical edge segments.

## Test deliberately broken circuits
The headless Godot test rejects duplicated knots, an undersized width and a figure-eight circuit. It also checks rendered wall triangles match StaticBody3D triangle geometry, first northbound straight, both-side rebound and traversal of all sampled centreline positions without invisible walls.

## Community tracks (future — not implemented)
The proposed Track Creator will edit this JSON-equivalent source through validated in-memory changes, generate identical geometry on Android/PC/Web, and attach theme/chunk assets. Players will preview/check an entire loop before publication. Add moderation, track version hashing, seed, checkpoint validation and immutable leaderboard eligibility later.

## Important limitations
- No automatic repair: invalid tracks receive errors and must be edited. Silent repair could alter scoring and creator intent.
- Not a promise that every hand-designed geometry is visually attractive. Rendering screenshots and player tests remain mandatory.
- The roadmap includes P1 dynamic velocity-follow camera, P2 handling refinement, P3 scoring zones and P4 checkpoint-qualified laps; none are automatically achieved by this P0 implementation.
- Do not call a centreline position traversal a successful **player-driven** three-lap test.
