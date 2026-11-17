# Starter 0.1.0 acceptance

## Demonstrated in GitHub CI
- Python structure, alignment and approved art manifest validation.
- Unit tests: unchanged art accepted, raw tamper rejected, manifest-rehash bypass rejected against trusted baseline, unregistered approved files rejected, deletion of file+manifest rejected, symlink attempt rejected.
- Version bump and release immutability unit tests.
- Godot 4.7.2 editor import and runtime smoke of boot, prototype and Xbox input-monitor scenes; InputMap keyboard+joypad synthetic event test.

## Needs local hardware
- Xbox Wireless Controller (Windows USB/Bluetooth, Ubuntu USB/Bluetooth, Android Bluetooth), hot plug, full triggers, D-pad and rumble.
- Android Back, touchscreen multitouch, safe areas, gamepad/touch handoff.
- Windows/Linux signed/unsigned exports, Android APK/AAB, Web export.
- Game feel, camera, frame-time and memory on representative devices.

## Release criteria
A successful source CI run is not a shipped game. For each platform distinguish BUILD GENERATED, INSTALL/LAUNCH TESTED and GAMEPLAY TESTED with evidence. First official version in VERSION is 0.1.0; tag/release is a separate publishing action. Never reuse a versioned artifact filename.
