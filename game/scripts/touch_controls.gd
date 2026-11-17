extends Control

# Screen-space multitouch input adapter for the *prototype only*.
var touches: Dictionary = {}
var pressed: Dictionary = {}

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process_input(true)
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            _set_touch(event.index, _action_at(event.position))
        else:
            _set_touch(event.index, "")
    elif event is InputEventScreenDrag:
        _set_touch(event.index, _action_at(event.position))

func _action_at(pos: Vector2) -> String:
    var screen := get_viewport_rect().size
    if pos.y < screen.y * 0.55:
        return ""
    var center := Vector2(screen.x * 0.17, screen.y * 0.78)
    var delta := pos - center
    if pos.x < screen.x * 0.38 and delta.length() < minf(screen.x, screen.y) * 0.24:
        if absf(delta.x) > absf(delta.y):
            return "move_right" if delta.x > 0 else "move_left"
        return "move_down" if delta.y > 0 else "move_up"
    if pos.x > screen.x * 0.64:
        return "action_primary" if pos.x > screen.x * 0.82 else "action_secondary"
    return ""

func _set_touch(index: int, action: String) -> void:
    var previous := str(touches.get(index, ""))
    if previous == action:
        return
    if touches.has(index):
        touches.erase(index)
    if previous != "":
        var remaining := false
        for value in touches.values():
            if value == previous:
                remaining = true
        if not remaining:
            Input.action_release(previous)
    if action != "":
        touches[index] = action
        Input.action_press(action)
    queue_redraw()

func _exit_tree() -> void:
    for action in ["move_left", "move_right", "move_up", "move_down", "action_primary", "action_secondary"]:
        Input.action_release(action)
    touches.clear()

func _draw() -> void:
    var screen := get_viewport_rect().size
    var origin := Vector2(screen.x * 0.17, screen.y * 0.78)
    var radius := minf(screen.x, screen.y) * 0.115
    for delta in [Vector2(-1,0), Vector2(1,0), Vector2(0,-1), Vector2(0,1)]:
        draw_circle(origin + delta * radius * 0.8, radius * 0.40, Color(0.55, 0.65, 0.85, 0.38))
    draw_circle(Vector2(screen.x * 0.91, screen.y * 0.79), radius * 0.62, Color(0.95, 0.44, 0.15, 0.47))
    draw_circle(Vector2(screen.x * 0.74, screen.y * 0.79), radius * 0.54, Color(0.3, 0.75, 0.85, 0.44))

