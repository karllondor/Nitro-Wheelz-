# Nitro Wheelz: sound effects from user-supplied WAN videos

**Status: 17 authentic source-derived OGG files committed to the game source.** All files live in `game/assets/audio/` and load under `res://assets/audio/<name>.ogg`. All 17 binary Git blobs were SHA-1 verified against the uploaded conversation audio-pack ZIP before commit.

Source mapping (do not assume the WAN generator aligned every sound perfectly with timestamps):
- `1000076241.mp4` — tyres, drift, hydraulic handbrake (0–30 seconds)
- `1000076242.mp4` — turbo, blow-off, flutter, exhaust, limiter (0–30 seconds)
- `1000076358.mp4` — kerbs, guardrail collisions, gravel, wind (0–30 seconds)

The `start–end` columns below are the **cut boundaries**, not independent acoustic verification of the sound within each excerpt. Preview and trim any bad transitions before production.

| Filename (in `game/assets/audio/`) | Source | Cut | Intended use / translation |
|---|---|---|---|
| `barrier_hit.ogg` | `1000076358.mp4` | 10–14s | Strong collision with rigid track barrier; Impact event |
| `barrier_scrape_heavy.ogg` | `1000076358.mp4` | 14–19s | Continuous metal-on-metal scraping; Collision scrape |
| `barrier_scrape_light.ogg` | `1000076358.mp4` | 5–10s | Light barrier scrape; Low-impact contact |
| `curb_rumble.ogg` | `1000076358.mp4` | 0–5s | Tyres crossing blue/white kerbs; Kerb contact |
| `engine_limiter.ogg` | `1000076242.mp4` | 23–30s | High-RPM ignition cuts / limiter; Transient at high RPM (not engine idle) |
| `exhaust_pops.ogg` | `1000076242.mp4` | 17–23s | Three exhaust backfires; Discrete exhaust event |
| `exhaust_single.ogg` | `1000076242.mp4` | 13–17s | Single exhaust backfire; Throttle release / optional pop |
| `gravel_roll.ogg` | `1000076358.mp4` | 19–24s | Gravel / run-off shoulder; Loop while on gravel |
| `turbo_bov.ogg` | `1000076242.mp4` | 5–9s | Blow-off valve air release; Throttle lift with boost |
| `turbo_flutter.ogg` | `1000076242.mp4` | 9–13s | Compressor flutter; Boost release, optional |
| `turbo_spool.ogg` | `1000076242.mp4` | 0–5s | Turbocharger spool whistle; Boost rise |
| `tyre_corner.ogg` | `1000076241.mp4` | 5–10s | Mild turning squeal; Medium lateral slip, optional |
| `tyre_drift.ogg` | `1000076241.mp4` | 10–17s | Long rear-tyre drift squeal; Loop at high drift angle |
| `tyre_handbrake.ogg` | `1000076241.mp4` | 17–23s | Hydraulic handbrake rear lock/skid; Handbrake press event |
| `tyre_regrip.ogg` | `1000076241.mp4` | 23–30s | Tyre chirp on recovering grip; Drift ends / regain traction |
| `tyre_rolling.ogg` | `1000076241.mp4` | 0–5s | Ordinary asphalt rolling; Loop while moving |
| `wind_speed.ogg` | `1000076358.mp4` | 24–30s | Aerodynamic wind rush; Loop with increasing speed |

## Notes for Claude / Godot agent

Existing event mixer: `game/scripts/audio/drive_audio.gd`. It resolves the 17 exact filenames. After the Godot import phase, OGG streams are available in the built game without a manual path change.

The game currently triggers rolling tyres, drift, handbrake lock, tyre regrip, turbo spool/BOV, single exhaust pop, limiter proxy, curb hits, impacts, scrapes, gravel and wind. `tyre_corner.ogg`, `turbo_flutter.ogg` and `exhaust_pops.ogg` are prepared but need intentional event/rate-limit wiring.

**Do not treat `engine_limiter.ogg` as a continuous R6 engine loop.** The separate 30-second Engine Master was not included in these three uploads. This collection is transient and surface SFX, not a full engine soundtrack. Avoid reusing loud engine audio hidden in noisy clips as an RPM baseline.

Consider crossfading and true zero-crossing loops of `tyre_rolling`, `tyre_drift` and `wind_speed`, plus per-event cooldown to avoid repeated sample stacking. Godot's 2D audio mix is acceptable for mobile, but test gain and loudness on a real device.

Source media were supplied by the project owner, derived from WAN generations. The project owner controls the source content; do not imply that third-party samples are automatically licensed for external distribution.

The 17 original 16-bit WAV editing masters are also committed to the repository under [`audio_masters/`](../../audio_masters/), with filenames matching the OGG assets. Only the game-runtime OGG files belong under `game/`, keeping the Android APK smaller.
