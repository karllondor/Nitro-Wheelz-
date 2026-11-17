extends SceneTree
const REQUIRED := [
    "move_left","move_right","move_up","move_down",
    "action_primary","action_secondary","game_pause",
    "steer_left","steer_right","throttle","brake","handbrake","camera_toggle"
]
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for action in REQUIRED:
        if not InputMap.has_action(action):
            _fail("Missing action: "+action)
            return
        var key_found: bool = false
        var controller_found: bool = false
        for mapping in InputMap.action_get_events(action):
            if mapping is InputEventKey:
                key_found = true
            if mapping is InputEventJoypadButton or mapping is InputEventJoypadMotion:
                controller_found = true
        if not key_found or not controller_found:
            _fail("Missing keyboard or Xbox binding for "+action)
            return
        if InputMap.action_get_deadzone(action) > 0.25:
            _fail("Too large input deadzone: "+action)
            return

    var button := InputEventJoypadButton.new()
    button.button_index = JOY_BUTTON_A
    button.pressed = true
    # In headless CI there is no connected joypad, so sending raw hardware
    # events into Input.parse_input_event can be ignored. Check the map itself.
    if not InputMap.event_is_action(button,"action_primary",true):
        _fail("Xbox A missing from primary action map")
        return
    if not InputMap.event_is_action(button,"handbrake",true):
        _fail("Xbox A missing from handbrake map")
        return

    var rt := InputEventJoypadMotion.new()
    rt.axis = JOY_AXIS_TRIGGER_RIGHT
    rt.axis_value = 1.0
    if not InputMap.event_is_action(rt,"throttle",true):
        _fail("Xbox RT missing from throttle map")
        return
    Input.action_press("action_primary")
    await process_frame
    if not Input.is_action_pressed("action_primary"):
        _fail("Synthetic logical action press failed")
        return
    Input.action_release("action_primary")
    print("PASS: keyboard + Xbox mappings, deadzones, logical action input")
    print("NOT RUN: physical Xbox USB/Bluetooth device behavior")
    quit(0)

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)
