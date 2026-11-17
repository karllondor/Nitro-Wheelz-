# Optional production modules — never force into every game

These are requirements to consider when a game needs them; none is a built-in framework in v0.1.0.

## Saves and migrations
Store save schema_version separately from game version. Use atomic temp-write + rename, validate saved input, preserve backup and provide explicit forward migration steps. Test upgrading a real previous save; never delete saves on parse failure. On Android use user://, not an absolute desktop path. Cloud sync and save encryption require a specific product decision.

## Audio
Define master/music/SFX/ambient buses and independent volume controls before scaling audio. Avoid rapid looping or overlapping effects; respect mute/background focus. Track licenses and sample source. Implement shared audio manager only when needed.

## Accessibility and localisation
UI readable on phone and TV; touch targets large enough; adjustable font scale and contrast; captions for meaningful sounds; avoid colour-only status; optional reduced motion/flash and remappable controls. Use translation keys and UTF-8 rather than hard-coded dynamic text when multiple languages become a target.

## Crash diagnostics
Record game version, git SHA, OS/device, renderer and a redacted error trace. Never record credentials, private files or personal player data without an explicit privacy design. Provide opt-in diagnostic export and a clear reproduction path.

## Gameplay replay / regression
Record timestamped normalized input actions and a deterministic seed for a small fixed-step reference scene. Replay must assert player state and no softlocks. Recordings/screenshot diffs provide additional evidence, never replace in-engine behavior verification.

## Input rebinding / pad glyphs
Keep built-in ui_* navigation distinct from gameplay. Per-game mapping and glyph prompts should follow active device without reacting to minor stick drift. Allow changing bindings only after user-facing conflicts are resolved.

## Optional online/telemetry/multiplayer
Not permitted by default. Scope privacy, networking, abuse handling, latency, persistence and update compatibility before implementation.

## 3D asset tools
Use tools/blender_validate.py as a non-blocking source check; decide scale, pivots, UVs, materials, LOD and collision per game. Manual cinematic approval and device performance still required.

Each optional module needs a design brief, implementation owner, acceptance tests and measured justification before it is enabled.
