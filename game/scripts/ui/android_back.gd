extends Node
## Android system BACK (issue #65 / #59 v0.1.52, owner phone report on v0.1.53 fixed in v0.1.54).
## Godot's default `quit_on_go_back` closed the whole game from any screen. It is off (project.godot) and this autoload turns
## the system BACK (button, key or gesture: Godot 4.7 receives all of them through androidx OnBackPressedDispatcher and sends
## NOTIFICATION_WM_GO_BACK_REQUEST) into:
##  1. an open confirmation card (group "nitro_modal") -> CANCEL it (never confirms, never touches files);
##  2. otherwise the screen's own Escape / ui_cancel path, which every screen already has: menu pages go to their parent page,
##     the garage goes back, a race opens / closes PAUSE, the builders and editors cancel the current tool. On the main menu
##     the game is left only after a SECOND BACK (boot.gd go_back), never on one press. Screens that handle BACK themselves
##     (the LAN lobby, the Tree Designer) join the group "own_go_back" and are left alone.
## v0.1.54 ROOT CAUSE (reproduced on the Android 16 / API 36 emulator; this APK targets SDK 36): ONE system BACK reaches the
## game TWICE - once as the key press and once through the predictive-back callback when it is released (258 ms and 2 ms apart
## in CI). v0.1.53 took the second one on the main menu as "leave the game", so BACK in DEVELOPER closed the game on the owner's
## phone; API 35 delivers it once, which is why CI never saw it. A BACK within DEBOUNCE_MS of the previous one is now ignored
## (long enough for a normal press-and-release), and the main menu needs a second deliberate BACK anyway. Every BACK and every
## pause of the app is written to user://back_events.log (shown in DEVELOPER). See docs/dev/handoffs/issue-65-back-20261128-claude.md.
const DEBOUNCE_MS: int = 700
const LOG_PATH: String = "user://back_events.log"
const LOG_KEEP: int = 24

var _last_ms: int = -100000
var _log: PackedStringArray = []

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    if FileAccess.file_exists(LOG_PATH):
        _log = FileAccess.get_file_as_string(LOG_PATH).strip_edges().split("\n",false)
    record("APP START v%s" % str(ProjectSettings.get_setting("application/config/version","?")))

func _notification(what: int) -> void:
    match what:
        NOTIFICATION_WM_GO_BACK_REQUEST:
            handle_back()
        NOTIFICATION_APPLICATION_PAUSED:
            # The app goes to the background. Right after a BACK this means the system (not the game) left the game.
            record("APP PAUSED %d ms after the last BACK" % (Time.get_ticks_msec()-_last_ms) if _last_ms > 0 else "APP PAUSED")
        NOTIFICATION_APPLICATION_RESUMED:
            record("APP RESUMED")

## Returns what was done ("modal", "own", "cancel", "ignored") for tests and the log.
func handle_back() -> String:
    var now: int = Time.get_ticks_msec()
    if now-_last_ms < DEBOUNCE_MS:
        record("BACK ignored (duplicate %d ms after the previous)" % (now-_last_ms))
        return "ignored"
    _last_ms = now
    var modals: Array = get_tree().get_nodes_in_group("nitro_modal")
    for i in range(modals.size()-1,-1,-1):
        var m: Node = modals[i]
        if is_instance_valid(m) and m.is_inside_tree() and not m.is_queued_for_deletion() and m.has_method("cancel"):
            m.call("cancel")
            record("BACK -> card closed (%s)" % _where())
            return "modal"
    var scene: Node = get_tree().current_scene
    if scene != null and scene.is_in_group("own_go_back"):
        record("BACK -> screen's own handler (%s)" % _where())
        return "own"
    record("BACK -> ui_cancel (%s)" % _where())
    var ev := InputEventAction.new()
    ev.action = "ui_cancel"
    ev.pressed = true
    Input.parse_input_event(ev)
    var up := InputEventAction.new()
    up.action = "ui_cancel"
    up.pressed = false
    Input.parse_input_event(up)
    return "cancel"

## Lets a test pretend the previous BACK was long ago (the debounce uses the real clock).
func forget_last_back() -> void:
    _last_ms = -100000

func _where() -> String:
    var scene: Node = get_tree().current_scene
    if scene == null:
        return "no scene"
    var page: Variant = scene.get("page_name")
    return scene.scene_file_path.get_file().get_basename()+("/"+str(page) if page != null and str(page) != "" else "")

## One line of the persistent BACK log (also printed for adb logcat -s godot as NITRO_BACK).
func record(line: String) -> void:
    var stamp: String = Time.get_datetime_string_from_system(false,true)
    var entry: String = "%s %s" % [stamp,line]
    print("NITRO_BACK "+entry)
    _log.append(entry)
    while _log.size() > LOG_KEEP:
        _log.remove_at(0)
    var f := FileAccess.open(LOG_PATH,FileAccess.WRITE)
    if f != null:
        f.store_string("\n".join(_log)+"\n")
        f.close()

func log_lines(count: int = 6) -> PackedStringArray:
    return _log.slice(maxi(0,_log.size()-count))
