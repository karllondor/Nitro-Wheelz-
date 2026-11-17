# NITRO WHEELZ
### JAPAN DRIFT NIGHTS

**A skill-based arcade drift racer:** Japanese-inspired circuits, difficult but learnable oversteer, clean stylized 3D and two selectable cameras. Developed in Godot 4.7.2 for Windows, Linux and Android.

**Status: v0.1.1 MOBILE POLISH.** A first playable test build, not a finished racing game. No proprietary assets or DRIFTIT source code are used.

## Concept
Nitro Wheelz combines:
- **DRIFTIT-like mechanical principles:** a separately implemented deterministic two-axle car model, rear traction hysteresis, power oversteer, handbrake and assisted countersteering. Its developer-published numeric parameters provide initial tuning targets, not a claim of identical code or handling.
- **Japanese drift-circuit culture:** original fictional layouts inspired by Ebisu, Nikko and Meihan; the first track is Shin-Kawa Drift Park.
- **NIGHTRIDEPL and Drift Games cultural references:** the passion of collecting, building and tuning individual JDM cars, atmospheric night sessions and garages. There is no official partnership or branded car pack.
- **Clean HD-2.5D presentation:** actual 3D roads and cars with readable, selectively stylized surfaces. Default camera high top-down like the user's DRIFTIT mobile screenshots; chase camera is an option.

## Launch
Open game/project.godot in Godot **4.7.2 stable**, press F5, choose **START DRIFT SESSION**. For engine checks use:

```bash
python3 -m unittest discover -s tests -v
python3 tools/check_project.py
bash tools/run_godot_checks.sh
```

## Controls

| Action | PC | Xbox Wireless Controller | Android |
|---|---|---|---|
| Steering | A/D or ←/→ | Left stick | Joystick left |
| Throttle | W or ↑ | RT | GAS |
| Brake | S or ↓ | LT | BRAKE |
| Drift/handbrake | Space | A | DRIFT |
| Camera top-down/chase | C | Y | On-screen camera region |
| Pause | Escape | Menu | Top-right pause region |
| Restart | R | optional menu later | pause/menu later |
| Main menu | M | pending UI focus | pending UI focus |

InputMap runs through a single vehicle model regardless of device. Touch actions are pointer-ID-aware, allowing simultaneous steering, gas and drift. Android controls and controller connection must still be verified on a real device.

## Currently implemented
- Original two-contact-patch planar physics controller at 120 Hz with two 240 Hz substeps
- Public-reference starting grip values, hysteresis, handbrake, rear torque/traction trade-off and sliding-only countersteer assist
- One procedural fictional Japanese drift circuit, marker stripes, low-poly pines, barriers and car
- Drift scoring, speed and slip HUD, three-lap progression, persistent tyre marks and off-track slowing
- Overhead orthographic and behind-car chase cameras (same vehicle physics)
- Xbox/keyboard/touch bindings, input monitor, Godot smoke and deterministic physics regression tests
- Karll Game Starter quality, approved-asset guardrails, SemVer and release tooling

## Not yet built
Final branded/licensed vehicles, garage collecting, tuning, NIGHTRIDE/Drift Games packs, progression/saves, nitro boost, replay ghosts, real Japanese circuits, production-grade audio/VFX, online leaderboards and signed Android exports.

Future official creator packs require licensing/permission. Real auto body styles shown in reference material do not grant rights to use their brands or unique liveries.

## Evidence and release
See docs/PHYSICS_REFERENCE.md, docs/ART_DIRECTION.md, docs/CONTROLS.md and docs/QA_MATRIX.md. Every test should be marked PASS/FAIL/NOT RUN. Versioned artifacts use Nitro-Wheelz_v0.1.1_Platform and are never overwritten.

