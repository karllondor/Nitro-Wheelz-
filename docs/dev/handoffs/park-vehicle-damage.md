# Park vehicle interaction and cosmetic damage

Branch `feat/park-vehicle-damage` builds on the Interactive Playground commit `2766452366982639d2d46a161421cd9c0b2fdf98` (PR #42), which contains Park Multiplayer #41, Park 2.0 #40 and LAN Reliability #39. Feature tracking uses #27. Godot 4.7.2, Compatibility renderer. The implementing assistant is Codex, exact runtime variant unavailable.

## Driver experience

In the LAN Park lobby the host can switch **VEHICLE COLLISIONS** before starting. Both players see the mode. OFF is the default. ON enables planar pushes for every car. The pearl-white Lada 2106 is the damage test car, selectable in the ordinary garage. Solo Park also supports prop and wall damage. Competitive circuits continue using visual-only opponents.

A corner impact can release the nearer mount. A second sufficiently strong impact can tear off the remaining mount. Front and rear are independent. Park recovery and resetting training objects preserve the driver's damage. Stop in the striped workshop bay for 0.65 s at 1 m/s or less for free repairs. The owner of the serviced car sees the confirmation.

## Implementation

- The host projects each car to an oriented rectangle and uses the minimum overlap axis to resolve contact. The latest accepted guest pose is extrapolated up to 75 ms. Paused, stale, recovered and vertically separated cars do not exchange impulses. Only the host emits the ordered event that both drivers apply. Per-driver velocity change is capped at 12 m/s and separation at 0.49 m per event. Local driving remains client-simulated on both devices.
- White bumper geometry uses the production paint triangles and paint shader. `tools/car_factory/park_bumper_asset.py` generates the Park glTF; the importer resolves its vertex buffer from the original GLB. The generated model is selected only for Park white, including when the developer legacy model switch is active. Wheel, paint and other garage choices still use the car factory.
- Mount bits 1 and 2 represent left and right. An intact bumper has mask 3, a dangling bumper has mask 1 or 2, and mask 0 hides an absent bumper. Dangling motion is procedural about the surviving mount. A released bumper briefly uses one simple local rigid box, isolated from cars and props. At most four can exist for two drivers. They expire after seven seconds or on repair. Dust, uneven ground, curbs and ramp decks are not simulated for loose parts; cosmetic floor height is the pad datum.
- LAN protocol 5 reuses the existing Park event stream and join snapshot. The host sends bounded contact, mount break, detachment and service events. The guest reports its ordinary driving pose; the host checks static geometry, prop impacts and stopped dwell. No per-frame bumper or debris transforms are sent. The broken side and absence persist for observers, including reconnects. The cosmetic rest pose of a loose object can differ between peers. A replacement guest starts with fresh attachments.
- The experiment deliberately uses two 2D body footprints and a height gate. Very brief grazes between the 20 Hz network samples can be missed. The approach preserves the existing handling and competitive collision rules. Use the same build on both phones.

## Verification and repeatable capture

```sh
godot --headless --path game --editor --import
godot --headless --path game --script res://tests/park_damage_test.gd
python3 tools/test_net_rounds.py --damage
OUT_DIR=/tmp/park-damage godot --path game --resolution 1280x720 --script res://tests/capture_park_damage.gd
```

The two-process ENet test uses both host roles and both toggle positions. It checks a gentle hit, two stronger approaches, front and rear mount masks and visible debris on both peers, two independent service visits and free repair confirmation. The solo test drives into a real building, checks location and impact thresholds and the hinge pivot, drives with a missing bumper and rejects a rolling repair.

Desktop reference on Linux software OpenGL (llvmpipe), 1280 × 720, 48 wall-clock render intervals per state:

| State | Median | p95 |
| --- | ---: | ---: |
| Intact | 37.35 ms | 41.63 ms |
| Both dangling | 36.57 ms | 42.73 ms |
| Front debris, rear dangling | 36.49 ms | 41.56 ms |

These short stationary-camera samples describe this renderer and workload. For an actual phone, install the review APK, open **Developer → Park Damage Frame Test** and capture the result dialog. The debug harness also accepts `NITRO_PKG=<review-package> bash tools/android_park_damage_smoke.sh` on an already installed, connected handset. It writes screenshots, model and frame intervals to `builds/damage-android/`. CI runs the same APK probe on an API 35 emulator. Physical-phone, thermal and two-device hotspot measurements require hardware.

## Owner playtest

1. Select the white Lada on both phones. Host Park with collisions OFF. Cross paths and check that both cars pass through.
2. Return to the lobby, switch collisions ON and check the other phone displays ON. Nudge the parked partner, then make two stronger separated approaches. Watch the front of the striking car and the rear of the other. Drift in a circle after the first hit.
3. Reverse into a solid fixture, then approach the opposite corner. Compare the remaining attachment and missing bumper on both screens. Check that ordinary acceleration, handbrake and steering still work.
4. Roll through the workshop bay, then stop fully. Only the stopped driver should regain both bumpers. Check the confirmation and debris removal on each phone.
5. Swap host devices and repeat. Try side-by-side rubbing, a landing close to the other car and reconnecting while the host car is damaged. Record any persistent overlap, snap or frame hitch and the phone model.
