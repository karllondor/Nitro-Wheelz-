# Archived recorded sound effects (not used by the game)

The owner's 17 recorded effects (cut from three WAN-generated 30-second videos):
`ogg/` holds the 17 Godot-ready OGG clips that shipped in v0.1.12–v0.1.20,
`wav_masters/` the matching 16-bit WAV editing masters, `manifest.json` and
`SFX_CATALOG.md` their original description.

**Status (v0.1.21): retired from gameplay.** The integration never sounded right
(see `docs/audio/SFX_AUDIT.md`), so the owner decided the car sound is the
procedural synth only (`game/scripts/audio/engine_synth.gd`).

This folder is outside the Godot project (`game/`), so Godot never imports these
files and no export (Android, Web, desktop) contains them. `audio_regression_test.gd`
fails if any recorded effect reappears inside `game/` or any extra audio player
appears in a race. Do not move them back without the owner's approval.
