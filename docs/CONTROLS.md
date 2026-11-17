# Nitro Wheelz — control specification

InputMap must support keyboard, Xbox Wireless Controller USB/Bluetooth and portrait Android with true multitouch. A single drive_model.step() receives normalized steer [-1,1], gas/brake/handbrake [0,1].

| Action | Keyboard | Xbox | Android |
| -- | -- | -- | -- |
| Steering | A/D, arrows | Left stick | Analog touch area (left) |
| Throttle | W, Up | Right trigger RT | GAS (right bottom) |
| Brake | S, Down | Left trigger LT | BRAKE (right bottom) |
| Handbrake | Space | A | DRIFT above pedals |
| Camera | C | Y | upper-right camera touch region |
| Pause | Esc | Menu | upper-right pause touch region |
| Restart | R | pending in-menu binding | pending in-menu button |
| Main menu | M | pending in-menu binding | pending in-menu button |

Never use Xbox Guide or Share. Analog input requires deadzone ~0.12 for wheel/trigger. InputEventJoypadMotion right trigger axis=5 and left trigger axis=4 are standard mappings; physical controller and OS mapping need testing. Context-specific UI uses ui_* actions and focus restoration.

Virtual controls track independent pointer IDs so GAS + steering + DRIFT can overlap. Controller/keyboard action values are combined with touch values at race physics boundary, with the same numerical model. Touch control is currently a prototype, not full device-validated UI.

