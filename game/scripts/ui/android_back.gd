extends Node
## Android system BACK (issue #65 / #59, v0.1.52). Godot's default `quit_on_go_back` closed the whole game from any
## screen (an unsaved editor layout included). It is now off (project.godot) and this autoload turns BACK into:
##  1. an open confirmation card (group "nitro_modal") -> CANCEL it (never confirms, never touches files);
##  2. otherwise the screen's own Escape / ui_cancel path, which every screen already has: menu pages go to their
##     parent page (main menu: leave the game, as Android expects), the garage goes back, a race opens PAUSE,
##     the builders and editors cancel the current tool. Screens that handle BACK themselves (the multiplayer lobby)
##     join the group "own_go_back" and are left alone.

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        handle_back()

## Returns what was done ("modal", "own", "cancel") for tests.
func handle_back() -> String:
    var modals: Array = get_tree().get_nodes_in_group("nitro_modal")
    for i in range(modals.size()-1,-1,-1):
        var m: Node = modals[i]
        if is_instance_valid(m) and m.is_inside_tree() and not m.is_queued_for_deletion() and m.has_method("cancel"):
            m.call("cancel")
            return "modal"
    var scene: Node = get_tree().current_scene
    if scene != null and scene.is_in_group("own_go_back"):
        return "own"
    var ev := InputEventAction.new()
    ev.action = "ui_cancel"
    ev.pressed = true
    Input.parse_input_event(ev)
    var up := InputEventAction.new()
    up.action = "ui_cancel"
    up.pressed = false
    Input.parse_input_event(up)
    return "cancel"
