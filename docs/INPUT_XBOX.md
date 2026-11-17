# Controller policy: Xbox Wireless Controller / Keyboard / Android touch

Default supported inputs: keyboard, Xbox controller via USB and Bluetooth, and Android touch when Android is a target. Touch-only games can opt out with an explicit reason in PROJECT_BRIEF.md. Do not use the Xbox Guide or Share buttons for gameplay.

## Generic actions
move_left/right/up/down: WASD/arrows + left stick. action_primary: Space/Xbox A; action_secondary: E/Xbox X. game_pause: Escape/Xbox Menu (Start). ui_accept, ui_cancel, ui_up/down/left/right are Godot built-in menu actions.

Use InputMap for basic actions. For precision driving, analog throttle/steer curves and trigger inputs can be read via a small per-game adapter, not a global racing driver. Choose an explicit gameplay mapping in the game brief; never overload A/B with menu commands in the same context.

## Hardware QA
- Windows USB and Bluetooth: axes, A/B/X/Y, bumpers, triggers, D-pad, Menu, focus.
- Ubuntu USB and Bluetooth: same; record driver and firmware where available.
- Android gamepad + touch: pairing, startup, unplug, Android Back, UI focus, duplicate tap prevention.
- Web when targeted: activation after first input, detection and fallback.
- Stick deadzone should be tuned, commonly 0.10–0.20; triggers are axes, not buttons.
- On disconnect release held actions, restore correct focus, don't let stick drift repeatedly switch glyphs.
- Show active device and raw axis values in dev/input_monitor.tscn.
- Rumble and device-specific glyphs optional, not blocking baseline.
No hardware claim without a QA row linked to device and video/log.

