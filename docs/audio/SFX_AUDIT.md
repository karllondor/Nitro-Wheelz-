# SFX audit — the 17 recorded clips (v0.1.20)

Measured on 2026-11-19 with ffmpeg (EBU R128 loudness) and librosa (spectrograms, onset and band-energy timelines) on `game/assets/audio/*.ogg` and the matching `audio_masters/*.wav`. No one listened to these in this container; the content column is read from spectrograms and band energy. **Owner listening on Android is still required before the audio is approved.**

All 17 files: mono, 22,050 Hz, 4–7 s, loud masters (−6.5 to −11 LUFS for most). Many decode above full scale (clipped samples: `engine_limiter` 798, `exhaust_single` 319, `exhaust_pops` 311, `turbo_bov` 307, `wind_speed` 58, `tyre_handbrake` 57).

## Why v0.1.19 sounded chaotic
1. `exhaust_pops` was retriggered on every physics tick while `afterfire > 0.9` (~0.12 s ≈ 14 restarts).
2. Clips were played whole (4–7 s), but the useful sound is often a fraction in the middle. Example: in `tyre_handbrake` the squeal is at 1.9–4.3 s, so the sound lagged the handbrake by ~2 s.
3. Several "single" clips contain several events (`turbo_bov` = two blow-offs, `exhaust_pops` = three long bursts over 6 s).
4. Loops were not loopable: `tyre_drift` has engine hum at 0–1 s and 5.5–7 s, so the drift squeal dropped out every 7 s; `gravel_roll` swells and fades.
5. `tyre_rolling` and `tyre_corner` contain an engine hum (60–200 Hz harmonics), not tyre noise — a second "engine" on top of the synth.
6. `engine_limiter` is 7 s of continuous high-rev engine audio, played for the whole 7 s even after the limiter ended.
7. Few cooldowns and no priorities: impacts, scrapes, pops, turbo and tyre one-shots stacked freely.

## Per clip
| clip | len | LUFS | content (from spectrogram) | decision | game cut (start + length) | trigger |
|---|---|---|---|---|---|---|
| tyre_rolling | 5.0 | −11.1 | engine hum only (f0 ≈ 58 Hz) | **not used** → synth road noise | — | — |
| tyre_corner | 5.0 | −11.5 | engine hum + rev sweep | **not used** | — | — |
| tyre_drift | 7.0 | −7.9 | hum 0–1 s, clean squeal ~1.1 kHz 1.0–5.5 s, hum | loop of the squeal | 1.10 + 4.30, 0.25 s crossfade | rear slip angle (loop gain) |
| tyre_handbrake | 6.0 | −7.4 | hum, squeal 1.94–4.34 s | one-shot | 1.92 + 1.40 | handbrake pulled at speed (edge) |
| tyre_regrip | 7.0 | −6.6 | hum, squeal 1.45–5.24 s | end of the squeal as a short release | 4.85 + 0.45 | a drift of ≥ 0.6 s ends |
| turbo_spool | 5.0 | −11.6 | rising whistle 0.17–4.96 s | one-shot | 0.17 + 2.20 | turbo cars: throttle stamped from closed |
| turbo_bov | 4.0 | −6.5 | two blow-offs (0.72–1.8, 2.79–3.9) | first blow-off | 0.70 + 1.15 | turbo cars: lift after ≥ 1 s of boost |
| turbo_flutter | 4.0 | −10.7 | low flutter 0.77–3.98 s | **not used** (stacked on every lift) | — | — |
| exhaust_single | 4.0 | −7.7 | rev sweeps + two roars | crisp onset of the 2nd burst | 2.21 + 0.35 | lift-off, 30–60 km/h, high revs |
| exhaust_pops | 6.0 | −8.0 | three long bursts over 6 s | one burst | 2.63 + 0.60 | once per afterfire window, > 60 km/h |
| engine_limiter | 7.0 | −7.2 | continuous high-rev engine | **not used** (synth does the limiter per car) | — | — |
| curb_rumble | 5.0 | −17.4 | periodic thumps 0.46–2.65 s | one-shot | 0.45 + 1.30 | wheels run onto a kerb (edge) |
| barrier_hit | 4.0 | −11.0 | broadband impact 0.36–2.31 s | one-shot | 0.30 + 1.50 | wall impact ≥ 3 m/s |
| barrier_scrape_light | 5.0 | −24.7 | quiet metallic ring, transient at 2.96 s | short touch | 2.92 + 0.60 | wall touch 1.2–3 m/s |
| barrier_scrape_heavy | 5.0 | −11.9 | steady broadband scrape 0.48–3.29 s | loop | 0.55 + 2.70, 0.20 s crossfade | body sliding along a wall |
| gravel_roll | 5.0 | −15.3 | gravel crunches 1.5–3.3 s | loop | 1.45 + 1.90, 0.25 s crossfade | off the asphalt |
| wind_speed | 6.0 | −11.0 | steady wind from 1.6 s | loop | 1.70 + 3.80, 0.40 s crossfade | speed above ~60 km/h |

Cuts are defined in `game/assets/audio/sfx_spec.json` and built from the WAV masters by `tools/build_sfx.py` (equal-power loop crossfades, fades, peak −3 dBFS, Vorbis q5) into `game/assets/audio/processed/` (13 files, ~0.2 MB). The original 17 OGG files are unchanged. Runtime levels, cooldowns and priorities live in `drive_audio.gd` (`EVENTS`).
