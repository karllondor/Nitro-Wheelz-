# Interactive stunt playground handoff

**Feature branch** `feat/park-stunt-physics`. **Base** `3a577db0844d91439e99f262cc37bd115d0c44f7` from Park Multiplayer PR #41. Its history contains Park 2.0 PR #40 and Multiplayer Reliability PR #39. The environment follows the owner's provisional Park 2.0 layout.

## Drive and reset

Open **NITRO WHEELZ PARK → FREE DRIVE** or use **LOCAL MULTIPLAYER → HOST PARK**. In multiplayer, install the same protocol 4 review APK on both phones. Take the east road to the northern stunt slab. The three painted approaches run north. Use **PAUSE → RESET TRAINING OBJECTS** to restore all boxes, barriers and cones. The host has that action in LAN. Vehicle recovery returns the driver to the plaza and clears their air state.

| Ramp | Deck start (x, z) | Rise | Approach / marked landing length | Obstacle arrangement |
| --- | --- | ---: | ---: | --- |
| Small | (-92, -449) | 1.2 m | 85 / 49 m | Individual cartons |
| Medium | (-40, -448) | 2.4 m | 91 / 51 m | Two-layer stack |
| Large | (30, -449) | 3.8 m | 98 / 49 m | Two-layer cardboard wall |

The east obstacle pad contains a carton pyramid and three lightweight striped barriers. All props have an undamaged home pose. A glancing or slow impact moves less material than a fast square impact. The surrounding pavement is open for turnarounds and lower-speed passes.

## Physics and ownership

- `park_air.gd` owns the Park car's deck admission, vertical speed, pitch and landing. Drive onto the ramp from the marked side. The side faces and rear lip have the original planar contact response. Once airborne, the car follows its take-off planar velocity and a gravity arc. Vertical launch speed is capped at 5 m/s and constrained by the marked run-out at high speed. The normal drift model resumes on touchdown. The vehicle handling data and competitive race physics are shared unchanged.
- `park_stunt_world.gd` creates 33 placed props and a pool of at most 18 colliding rigid bodies. Boxes and barriers use simple cuboids. The car contact proxy sweeps position and height against visible props and applies a directional impulse. An untouched arrangement wakes as a whole when the pool has space. Bodies return to the pool after sleeping, leaving the play area or reaching the 12 s lifetime. Their settled visual pose stays until reset. Reserved collision layer 11 is stunt ground and layer 12 is active stunt props. The dormant props remain visual meshes and still respond to the car contact proxy.
- The existing cones retain their original lightweight contact and tip/slide behaviour. The LAN host simulates stunt rigid bodies for both drivers. The guest interpolates their received transforms as visuals. Player cars continue to use the established visual-only remote car path.

## Network and future collision or damage

`park_cones_sync_requested` now sends the current cone and stunt states on load or reconnect. `ParkEvent.RESET_TRAINING` already authorizes and orders a single reset across both. Use the existing room epoch and reset revision when adding new world interactions.

- `KIND_PARK_OBJECTS` contains an 11-byte epoch/revision/sequence header and 13 bytes per displaced object. Stable IDs are the ordered placements in `park_site.gd:stunt_props()`. Positions are quantized to 2.5 cm. The host sends up to 10 motion snapshots per second, plus reliable snapshots on settling and reconnect. A reliable reset fences off older packets. The codec caps the full snapshot at 479 bytes. Parking settled objects generates no periodic prop traffic.
- Park car snapshots extend the original 44 bytes with height and pitch, using 52 bytes at up to 20 Hz. Competitive snapshots remain 44 bytes. Jump height follows the existing interpolation clock. Host ignores paused poses and recovery discontinuities when evaluating guest stunt contact.
- `object_impact(id, driver_slot, position, impulse)` is the host-side observation for effects and future vehicle collision or cosmetic damage. In solo, driver slot is -1. The client remains the source of its own pose, so a later damage system should assess contact history and authoritatively validate actor and severity before emitting a damage event. Keep progression independent. No damage state, detached bumpers or vehicle-to-vehicle collision is implemented here.

## Reproduce

Pinned Godot 4.7.2.

```sh
godot --headless --path game --editor --import
godot --headless --path game --script res://tests/park_stunt_test.gd -- --bench
python3 tools/test_net_rounds.py --park
bash tools/run_godot_checks.sh
```

Capture with a display, GL Compatibility and the ordinary game scene.

```sh
OUT_DIR=/absolute/evidence godot --path game --audio-driver Dummy --resolution 1280x720 \
  --script res://tests/capture_park_stunts.gd
```

| Owner check | Action |
| --- | --- |
| Slow and fast launches | Take each ramp at crawl and at full throttle. Use Chase and Top-down. Confirm the car settles inside the marked run-out. |
| Clear and scatter | Jump over a formation, then use a slower pass to strike it. Drive through the pyramid and barriers, then reset. |
| Two phones | Launch from medium and large at the same time. Watch the other car's height and each other's cardboard hits. Reset as host, then test guest rejoin while props are displaced. |
| Recovery | Leave the site while driving. Confirm the driver returns to their plaza slot and the room's props remain in place. |
| Performance | Compare empty practice, normal plaza drifts and simultaneous impacts. Note handset, camera and whether the devices use Wi-Fi or hotspot. |

Physical handset timing and two-phone radio testing await the owner playtest.

## Automated evidence

Godot 4.7.2 on Linux. The stock Lada used the normal Park race scene. The nominal speed in these tests is the approach target. Distance is measured from the deck lip to touchdown.

| Ramp | 12 km/h apex / distance | 122 km/h apex / distance |
| --- | --- | --- |
| Small | 1.22 m / 2.9 m | 2.27 m / 37.7 m |
| Medium | 2.45 m / 4.0 m | 3.67 m / 45.1 m |
| Large | 3.86 m / 5.0 m | 4.66 m / 45.4 m |

The tracked cardboard wall moved by up to 4.03 m in the scripted ground impact. Negative controls cover approaching a ramp from the rear, clearing a wall above its contact volume, duplicate and truncated object packets, and a non-finite car height. Pool, sleep/cleanup and reset checks passed.

The Linux loopback harness used two game processes with separate profiles. Both host roles saw simultaneous medium/large jumps and both wall/stack impacts. The guest had zero simulated rigid bodies. The host sent 31 prop-state packets totalling 6,191 payload bytes in each measured impact sequence. The test also verified receiving the current object state on reconnect and resetting both peers.

### Linux headless physics monitor

AMD EPYC Linux container, six 1.05-second windows per case, 120 Hz physics, repeated independent setups. These are Godot physics monitor readings in milliseconds of engine physics frame work, sampled once per window. Maximum includes scheduling and runtime variance. This is a headless workload measurement.

| Case | Sample median | Sample max | Peak active props |
| --- | ---: | ---: | ---: |
| Empty practice | 1.954 ms | 17.163 ms | 0 |
| Normal plaza drifting | 0.942 ms | 2.457 ms | 0 |
| Jump plus pooled props | 1.804 ms | 3.772 ms | 18 |

The game capture and some repeated headless scene transitions printed ObjectDB/resource cleanup diagnostics at exit. Screenshots were written and gameplay assertions completed. Mobile rendering, radio latency and handset thermal behaviour remain outside these samples.
