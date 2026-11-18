# Nitro Wheelz — Track DNA v0.1.5 P0 test build

Model: GPT-6
Date: 2026-11-18
Development branch: agent/nitro-v0.1.5-trackdna-p0
Repo: https://github.com/karllondor/Nitro-Wheelz-

## Scope: P0 geometry, not full P0-P7 brief
Canonical track layout: game/tracks/shin_kawa_v2.json.
Compiler/validator: game/scripts/world/track_dna.gd.
Runtime rebuild, walls, exact matching StaticBody collider and deterministic car contact: game/scripts/world/drift_track.gd.
Negative controls and collision face identity tests: game/tests/track_dna_test.gd.

Rejected by generator: wrong schema, open-loop flag, too few or duplicate controls, road width under 12m/over 34m, too small radii, zero-length segments, self-intersecting centreline/wall offsets, nonlocal road corridor overlap.

## Deliverables/gates
- Godot import + smoke, input, driving, visual and TrackDNA tests: TO CHECK
- Web export / Android ARM64 debug APK: TO CHECK
- Desktop export: NOT RUN; preset needed
- Physical-device 3 laps, scenery, collisions, UI: NOT RUN
- Full dynamic camera P1 and LINE/ZONES/ANGLE/COMBO P3 are NOT IMPLEMENTED in this slice

No game-wide handling tuning or approved Lada redesign. Track algorithm outputs are deterministic. Unsuccessful in-memory rebuilds do not damage the current playable track.
