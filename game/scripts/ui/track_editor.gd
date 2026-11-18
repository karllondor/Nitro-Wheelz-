extends Control
## Nitro Wheelz Track Editor beta: touch and mouse drag of spline knots,
## insert/delete, validate, save to user://, and play. Not a random generator.
const DNA = preload("res://scripts/world/track_dna.gd")
const SOURCE: String = "res://tracks/shin_kawa_full_circuit.json"
const CUSTOM: String = "user://nitro_custom_track.json"

var data: Dictionary = {}
var selected: int = -1
var pointer: int = -999
var canvas: Rect2 = Rect2()
var world_mid: Vector2 = Vector2.ZERO
var pixels_per_metre: float = 1.0
var message_label: Label
var ready_to_play: bool = false
var last_length: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CUSTOM if FileAccess.file_exists(CUSTOM) else SOURCE))
    if not (raw is Dictionary):
        raw = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    data = raw
    data["id"] = "player_custom_track"
    data["name"] = "MY CUSTOM CIRCUIT"
    data["closed"] = true
    data.erase("widths_m")
    data["width_m"] = clampf(float(data.get("width_m",25.0)),18.0,28.0)
    _fit_view()
    _make_ui()
    _validate()

func _fit_view() -> void:
    var s: Vector2 = get_viewport_rect().size
    canvas = Rect2(s.x*0.045,s.y*0.155,s.x*0.91,s.y*0.48)
    var smallest := Vector2(INF,INF)
    var largest := Vector2(-INF,-INF)
    for item in data.get("control_points",[]):
        var p := Vector2(float(item[0]),float(item[1]))
        smallest = Vector2(minf(smallest.x,p.x),minf(smallest.y,p.y))
        largest = Vector2(maxf(largest.x,p.x),maxf(largest.y,p.y))
    world_mid = (smallest+largest)*0.5
    var span: Vector2 = largest-smallest
    pixels_per_metre = minf(canvas.size.x*0.84/maxf(span.x,1.0),canvas.size.y*0.84/maxf(span.y,1.0))
    queue_redraw()

func _screen_point(p: Vector2) -> Vector2:
    return canvas.get_center()+(p-world_mid)*pixels_per_metre

func _world_point(p: Vector2) -> Vector2:
    return (p-canvas.get_center())/pixels_per_metre+world_mid

func _make_ui() -> void:
    var s: Vector2 = get_viewport_rect().size
    var scale: float = clampf(s.x/720.0,0.75,2.0)
    var background := ColorRect.new()
    background.color = Color(0.022,0.028,0.038)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    move_child(background,0)
    var title := Label.new()
    title.text = "NITRO WHEELZ / TRACK EDITOR BETA"
    title.position = Vector2(s.x*0.05,s.y*0.025)
    title.size = Vector2(s.x*0.90,s.y*0.06)
    title.add_theme_font_size_override("font_size",int(23.0*scale))
    title.add_theme_color_override("font_color",Color(0.99,0.95,0.98))
    add_child(title)
    var instructions := Label.new()
    instructions.text = "DRAG white nodes to shape road • Select a node to add/delete"
    instructions.position = Vector2(s.x*0.05,s.y*0.098)
    instructions.size = Vector2(s.x*0.9,s.y*0.042)
    instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    instructions.add_theme_font_size_override("font_size",int(15.0*scale))
    instructions.add_theme_color_override("font_color",Color(0.74,0.76,0.83))
    add_child(instructions)
    message_label = Label.new()
    message_label.position = Vector2(s.x*0.06,s.y*0.653)
    message_label.size = Vector2(s.x*0.88,s.y*0.072)
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.add_theme_font_size_override("font_size",int(16.0*scale))
    add_child(message_label)
    _button("ADD NODE",0.05,0.746,0.425,0.065,Callable(self,"_add_point"))
    _button("DELETE NODE",0.525,0.746,0.425,0.065,Callable(self,"_delete_point"))
    _button("VALIDATE",0.05,0.825,0.425,0.065,Callable(self,"_validate"))
    _button("SAVE TRACK",0.525,0.825,0.425,0.065,Callable(self,"_save"))
    _button("RESET SHAPE",0.05,0.905,0.275,0.055,Callable(self,"_reset_shape"))
    _button("BACK",0.36,0.905,0.275,0.055,Callable(self,"_back"))
    _button("DRIVE",0.675,0.905,0.275,0.055,Callable(self,"_drive"))

func _button(text: String,xx: float,yy: float,ww: float,hh: float,action: Callable) -> void:
    var s: Vector2 = get_viewport_rect().size
    var button := Button.new()
    button.text = text
    button.position = Vector2(s.x*xx,s.y*yy)
    button.size = Vector2(s.x*ww,s.y*hh)
    button.add_theme_font_size_override("font_size",int(clampf(s.x/31.0,14.0,30.0)))
    button.pressed.connect(action)
    add_child(button)

func _status(txt: String,valid: bool) -> void:
    message_label.text = txt
    message_label.add_theme_color_override("font_color",Color(0.55,0.95,0.77) if valid else Color(1.0,0.43,0.50))

func _invalidate() -> void:
    ready_to_play = false
    _status("CHANGED • Validate before driving",false)
    queue_redraw()

func _validate() -> void:
    var result: Dictionary = DNA.compile(data)
    ready_to_play = bool(result.get("ok",false))
    if ready_to_play:
        last_length = float(result["length_metres"])
        _status("VALID • %.0f m / %.1f m width • closed loop" % [last_length,float(data["width_m"])],true)
    else:
        var errors: PackedStringArray = result.get("errors",PackedStringArray())
        _status("INVALID • "+(str(errors[0]) if not errors.is_empty() else "Unknown geometry error"),false)
    queue_redraw()

func _save() -> void:
    _validate()
    if not ready_to_play:
        return
    var file: FileAccess = FileAccess.open(CUSTOM,FileAccess.WRITE)
    if file == null:
        _status("FAILED • Storage unavailable",false)
        return
    file.store_string(JSON.stringify(data,"  "))
    file.close()
    var check: Dictionary = DNA.read_track(CUSTOM)
    if not bool(check.get("ok",false)):
        _status("FAILED • Saved circuit failed geometry check",false)
        return
    _status("SAVED • MY CUSTOM CIRCUIT • %.0f m" % last_length,true)

func _drive() -> void:
    _save()
    if not ready_to_play or not FileAccess.file_exists(CUSTOM):
        return
    ProjectSettings.set_setting("nitro/selected_track",CUSTOM)
    get_tree().change_scene_to_file("res://scenes/race.tscn")

func _reset_shape() -> void:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    if raw is Dictionary:
        data = raw
        data["id"] = "player_custom_track"
        data["name"] = "MY CUSTOM CIRCUIT"
        selected = -1
        _fit_view()
        _validate()

func _back() -> void:
    get_tree().change_scene_to_file("res://scenes/boot.tscn")

func _add_point() -> void:
    var pts: Array = data["control_points"]
    var n: int = pts.size()
    var idx: int = selected
    if idx < 0:
        var longest: float = 0.0
        for i in range(n):
            var d: float = Vector2(float(pts[i][0]),float(pts[i][1])).distance_to(
                Vector2(float(pts[(i+1)%n][0]),float(pts[(i+1)%n][1])))
            if d > longest:
                longest = d
                idx = i
    var a := Vector2(float(pts[idx][0]),float(pts[idx][1]))
    var b := Vector2(float(pts[(idx+1)%n][0]),float(pts[(idx+1)%n][1]))
    var p: Vector2 = (a+b)*0.5
    pts.insert(idx+1,[snappedf(p.x,0.01),snappedf(p.y,0.01)])
    data["control_points"] = pts
    selected = idx+1
    _invalidate()

func _delete_point() -> void:
    var pts: Array = data["control_points"]
    if selected < 0 or pts.size() <= 8:
        _status("SELECT A NODE • Keep at least 8 nodes",false)
        return
    pts.remove_at(selected)
    data["control_points"] = pts
    selected = -1
    _invalidate()

func _point_count() -> int:
    return (data["control_points"] as Array).size()

func _node_position(i: int) -> Vector2:
    var item: Array = data["control_points"][i]
    return Vector2(float(item[0]),float(item[1]))

func _start_touch(pos: Vector2,pointer_index: int) -> void:
    if not canvas.has_point(pos) or pointer != -999:
        return
    var radius: float = maxf(17.0,get_viewport_rect().size.x*0.031)
    var closest: float = radius
    var found: int = -1
    for i in range(_point_count()):
        var d: float = pos.distance_to(_screen_point(_node_position(i)))
        if d < closest:
            closest = d
            found = i
    selected = found
    pointer = pointer_index if found >= 0 else -999
    queue_redraw()

func _drag_touch(pos: Vector2,pointer_index: int) -> void:
    if pointer != pointer_index or selected < 0:
        return
    var world: Vector2 = _world_point(pos)
    var pts: Array = data["control_points"]
    pts[selected] = [snappedf(world.x,0.01),snappedf(world.y,0.01)]
    data["control_points"] = pts
    _invalidate()

func _release_touch(pointer_index: int) -> void:
    if pointer == pointer_index:
        pointer = -999
        _validate()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            _start_touch(event.position,event.index)
        else:
            _release_touch(event.index)
    elif event is InputEventScreenDrag:
        _drag_touch(event.position,event.index)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _start_touch(event.position,-2)
        else:
            _release_touch(-2)
    elif event is InputEventMouseMotion:
        if pointer == -2:
            _drag_touch(event.position,-2)

func _draw() -> void:
    draw_rect(canvas,Color(0.065,0.087,0.105,0.92),true)
    draw_rect(canvas,Color(0.45,0.48,0.58,0.75),false,2.0)
    if _point_count() < 3:
        return
    var line := PackedVector2Array()
    for i in range(_point_count()):
        line.append(_screen_point(_node_position(i)))
    line.append(line[0])
    var road_px: float = float(data.get("width_m",25.0))*pixels_per_metre
    draw_polyline(line,Color(0.20,0.22,0.27,0.88),road_px,true)
    draw_polyline(line,Color(0.95,0.95,0.98,0.8),2.0,true)
    for i in range(_point_count()):
        var point: Vector2 = _screen_point(_node_position(i))
        draw_circle(point,10.0,Color(1.0,0.17,0.48) if i == selected else Color(0.94,0.94,0.96))
        draw_circle(point,4.0,Color(0.035,0.041,0.050))
    var origin: Vector2 = _screen_point(_node_position(0))
    draw_circle(origin,15.0,Color(0.19,0.85,0.44,0.8))
