# Nitro Wheelz — WAV editing masters

These 17 **16-bit PCM WAV** clips were cut from the user's three 30-second WAN-generated videos. Filenames align 1:1 with the Godot-ready OGG clips in [`game/assets/audio/`](../game/assets/audio/).

- `barrier_hit.wav`
- `barrier_scrape_heavy.wav`
- `barrier_scrape_light.wav`
- `curb_rumble.wav`
- `engine_limiter.wav`
- `exhaust_pops.wav`
- `exhaust_single.wav`
- `gravel_roll.wav`
- `turbo_bov.wav`
- `turbo_flutter.wav`
- `turbo_spool.wav`
- `tyre_corner.wav`
- `tyre_drift.wav`
- `tyre_handbrake.wav`
- `tyre_regrip.wav`
- `tyre_rolling.wav`
- `wind_speed.wav`

Use WAV for manual fades, normalization, new loops, crossfades and audio editing. **Do not move this folder into `game/`**: the OGG versions are the runtime assets. Full origin, time ranges, purpose and caveats: [SFX catalog](../docs/audio/SFX_CATALOG.md).

Source videos: `1000076241.mp4` (tyres), `1000076242.mp4` (turbo/exhaust), `1000076358.mp4` (track/collision).

No continuous Engine Master file was supplied; `engine_limiter.wav` is an RPM-limiter effect, not the engine idle/rev loop.
