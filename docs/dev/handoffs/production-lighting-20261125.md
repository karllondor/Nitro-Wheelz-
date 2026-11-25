# Production lighting and time of day

Review branch `integration/park-unified-rc`. Version **0.1.47**, Android version code **47**. Starting commit `6964b904c85fb07eebc013315c2c4f9c7400a210`. The exact build commit is the production-lighting PR head. Verify with `git rev-parse HEAD`; the downloadable review evidence records the expanded SHA and APK checksum. Accepted scope retains #30, #32 and #39–#43. PR #38 (`2f0617f54a7bc2066294b51ef63eb058993bc535`) was used for calibration and the operating principles of scene lighting, retained stock materials and model-local spots.

## Runtime operation

- Races use the four-position selector in **Your Race** after choosing an official or saved custom circuit. DAY is the initial value. The preset is locked for the race and any rematch. In LAN it is selected by the host in the existing ready room. Editor quick-drive keeps the current session's selection.
- Park puts the same selector in **Pause**. Solo drivers and the LAN host can switch without replacing the scene. A guest can read the selection. The time update touches environmental resources and vehicle lights, preserving the current pose, camera, course, training objects and damage state.
- **Vehicle Lights** is in Pause in every driving mode. AUTO turns on position lights and headlights at DAWN and NIGHT. ON and OFF override position/headlights. BRAKE and HAND BRAKE are separate inputs ORed into one STOP state, so releasing either one alone keeps STOP active. Keyboard, controller and touch use the existing actions. Each LAN driver selects their own mode.

| Preset | Key light | Ambient | Default lamp state |
| --- | --- | --- | --- |
| DAWN | Warm low sun, 10° elevation, azimuth +38° | Cool violet-blue, pink horizon, depth haze | ON |
| DAY | Original track key and existing daylight materials | Original track resources | OFF |
| GOLDEN HOUR | Warm orange sun, 17° elevation, azimuth −64° | Warm ambient, depth haze | OFF |
| NIGHT | Blue key at 48°, low energy | Low blue ambient and dark sky | ON |

## Calibration and renderer

The failed lab used **1.9** energy per spot, **29 m** range, a **32°** cone, and an approximation of car lens geometry. Flat driving surfaces used unshaded materials, which did not receive light. The old lamp quads also competed with source geometry and switched separately from material emission. The new system retains the production textures and paint, with a lighting response on plaza, road and circuit asphalt. The road shader receives real directional and spot light and calibrates diffuse response at grazing angles with a smooth near-field reduction. The paired night render measured a +39.7, +26.5, +17.1 and +8.6 change in 8-bit asphalt luminance at 10, 20, 30 and 40 m respectively. Its footprint comes from the two renderer spots on the body, so steering, drift angle, pitch and camera position do not drive a projected graphic.

Per spot **15.2** energy (**8×**), **54 m** range, **18.5°** half-angle, **2.35°** down, **2°** outward toe, range attenuation **0.72**, angle attenuation **0.84**. Source `car_lamps.gd`. Both spots have shadows disabled. Renderer is the existing Godot 4.7.2 GL Compatibility on desktop, Android and Web. Up to four active local spots in a two-player session. Dawn and Golden Hour use a limited-distance two-split directional shadow. Night and the original Day avoid that additional pass. World environment resource, material copies and four per-car standard lens fallback materials are allocated once during scene setup. The setup rebinds after a streamed custom terrain build.

| Vehicle | Headlamp (±X, Y, Z), metres local | Tail lens centre (±X, Y, Z) | Lens source |
| --- | --- | --- | --- |
| Red Lada | 0.640, 0.540, −2.041 | 0.590, 0.536, 2.038 | GLB atlas, round headlights |
| Pearl-white Lada | 0.595, 0.553, −2.043 | 0.578, 0.549, 2.038 | GLB atlas, rectangular headlights |
| RYU-32 | 0.660, 0.570, −2.180 | 0.515, 0.663, 2.193 | GLB atlas |
| E30 | 0.650, 0.460, −2.156 | 0.492, 0.647, 2.089 | GLB atlas |
| RYU-32 FLAME test asset | 0.660, 0.570, −2.180 | 0.620, 0.610, 2.193 | Approximate lens fallback, owner fit QA pending |

The production lenses use the emission texture and local position masks. The white Lada fixtures are part of the fixed fascia, above the detachable bumper meshes. They stay physically attached when bumpers hang or detach. Procedural fallback cars reuse separate lamp and tail mesh materials, with a shared mount per body family. The physical Android acceptance car is the pearl-white Lada. Other cars still need the same level of hardware visual tuning.

## LAN

Protocol **6**. WELCOME, INFO, START and PARK_OPEN carry the preset enum. The current host alone can send a reliable round-scoped PARK_TIME during free roam. Late joiners receive the current value through both the handshake and open-state. Position/headlight and STOP booleans use two spare bits in the existing 20 Hz snapshot flags field, with no extra payload bytes per position update. Change detection limits shader updates. The session and spawn/recovery model are shared with the current Park. Existing collision, damage, cones, service and stunt messages remain in place.

## Reproduce and review

```sh
godot --headless --path game --editor --import
godot --headless --path game --script res://tests/production_lighting_test.gd
python3 tools/test_net_rounds.py --park
python3 tools/test_net_rounds.py --damage
bash tools/run_godot_checks.sh
OUT_DIR=/absolute/evidence godot --disable-vsync --path game --audio-driver Dummy \
  --resolution 1280x720 --script res://tests/capture_production_lighting.gd
```

The evidence package records the four preset views at a fixed spawn and camera, paired headlights ON/OFF captures, matched rear-lamp states, normal interface captures, LAN runtime captures and local rendering samples. Metrics are software GL on Linux. Physical Android FPS, heat, glare, colour and two-device Wi-Fi remain owner acceptance items. The production-lighting test and real two-process ENet tests cover controls and authoritative state. Godot can report ObjectDB cleanup warnings when some workshop or race scenes exit.

| Owner playtest | Action |
| --- | --- |
| Four presets | In Park free drive, pause and switch through all four. Observe the last selected view on resume. Check cones and damaged bumper positions before and after switching. |
| Brightness and direction | In NIGHT and DAWN, check the beam on the asphalt while parked and drifting, in Chase and Top-down. Try an approach to the technical circuit and a ramp. Toggle OFF at NIGHT and ON at DAY. |
| Rear lamps | With a second phone behind the white Lada, test BRAKE, HAND BRAKE and both together. Release only one first. Repeat in DAY and with lights OFF. |
| Two devices | Install the same review APK, host NIGHT and join. Change to DAWN in Park. Guest uses manual OFF and BRAKE. Reconnect and confirm the live time, lights on the other car, props and damage. |
| Performance | Compare DAY, NIGHT with one car, NIGHT with two cars and NIGHT while scattering stunt props. Record phone model, camera mode and the circumstances of any frame drop. |

The [v0.1.48 platform handoff](platform-integration-20261125.md) follows review PR #44 into the PC/Web HUD and platform integration. The calibration and phone acceptance requirements above apply to the release candidate.
