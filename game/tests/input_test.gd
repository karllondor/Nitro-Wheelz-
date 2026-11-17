extends SceneTree
const REQUIRED := [
    "move_left","move_right","move_up","move_down",
    "action_primary","action_secondary","game_pause"
]
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for action in REQUIRED:
        if not InputMap.has_action(action):
            _fail("Missing action: " + action)
            return
        var key_found := false
        var gamepad_found := false
        for event in InputMap.action_get_events(action):
            if event is InputEventKey:
                key_found = true
            if event is InputEventJoypadButton or event is InputEventJoypadMotion:
                gamepad_found = true
        if not key_found or not gamepad_found:
            _fail("Need keyboard + controller mapping: " + action)
            return
        if InputMap.action_get_deadzone(action) > 0.25:
            _fail("Analog deadzone too large: " + action)
            return
    var event := InputEventJoypadButton.new()
    event.button_index = JOY_BUTTON_A
    event.pressed = true
    Input.parse_input_event(event)
    await process_frame
    if not Input.is_action_pressed("action_primary"):
        _fail("Synthetic Xbox A did not map to primary action")
        return
    event.pressed = false
    Input.parse_input_event(event)
    print("PASS: keyboard and pad actions, deadzones and synthetic Xbox A")
    quit(0)

func _fail(message: String) -> void:
    printerr("FAIL: " + message)
    quit(1)

