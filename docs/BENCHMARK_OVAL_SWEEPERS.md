# Nitro Wheelz v0.1.7 benchmark experiment (NOT A RELEASE)

Model: GPT-6. Godot version target: 4.7.2. Branch: agent/nitro-v0.1.7-benchmarks-hud.

Two independent evaluation courses:
- Oval: approximately 271 m, 24 m road, pair of 180-degree right sweepers; radius in the public DRIFTIT guide 24 m. Our Catmull-Rom rendition is only geometrically similar.
- Sweepers: approximately 295 m, 23 m road, five-direction-change feel with a short left flick. Our waypoint coordinates and exact radii are NOT DRIFTIT's; do NOT label it a 1:1 copy.

Public dimension/corner sources:
- https://driftit.app/guides/tracks/oval
- https://driftit.app/guides/tracks/sweepers

In test recordings compare per-camera km/h, visible pavement flow, speed at entry/apex/exit, response to handbrake, input timing, drift recovery and slip angle. Do not compare leaderboard times as a scientific handling metric across non-identical course geometry.

Changes: v0.1.6 Shin-Kawa remains selectable; Track DNA's near-neighbour skip is now distance-based (metres rather than indices) so short benchmarks cannot be falsely rejected. P0 safety still rejects self-crossings and width violations. Camera visual tuning reduces overhead framing and moves chase camera closer/steeper, without changing the numerical speed-zoom calibration.

All changes in this branch remain unmerged. A green CI result is NOT a completed phone playtest.
