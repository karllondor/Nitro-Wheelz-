extends Control
## Nitro Wheelz Track Editor beta: touch and mouse drag of spline knots,
## insert/delete, validate, save to user://, and play. Not a random generator.
const DNA = preload("res://scripts/world/track_dna.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")
const SOURCE: String = "res://tracks/shin_kawa_full_circuit.json"
const CUSTOM: String = "user://nitro_custom_track.json"
const LAST_SAVED: String = "user://nitro_editor_last_path.txt"

var data: Dictionary = {}
var selected: int = -1
var pointer: int = -999
var canvas: Rect2 = Rect2()
var world_mid: Vector2 = Vector2.ZERO
var pixels_per_metre: float = 1.0
var message_label: Label
var ready_to_play: bool = false
var last_length: float = 0.0
var zoom_level: float = 1.0
# View panning (metres) on top of the auto-fit centre, so zoomed-in edges
# of the circuit can be reached and edited.
var pan_offset: Vector2 = Vector2.ZERO
var base_mid: Vector2 = Vector2.ZERO
var base_ppm: float = 1.0
var base_span: Vector2 = Vector2(300,300)
var pan_pointer: int = -999
var pan_last: Vector2 = Vector2.ZERO
var touches: Dictionary = {}
var pinch_active: bool = false
var pinch_start_dist: float = 1.0
var pinch_start_zoom: float = 1.0
var pinch_anchor: Vector2 = Vector2.ZERO
const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 6.0
var add_mode: bool = false
var invalid_nodes: Dictionary = {}
var dialog_overlay: ColorRect
var name_input: LineEdit
var undo_stack: Array[Dictionary] = []
var drag_recorded: bool = false
var pending_drive: bool = false
var last_saved_path: String = ""
var last_saved_name: String = ""

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS
    var chosen: String = SOURCE
    if FileAccess.file_exists(LAST_SAVED):
        var candidate: String = FileAccess.get_file_as_string(LAST_SAVED).strip_edges()
        if candidate.begins_with("user://nitro_track_") and FileAccess.file_exists(candidate):
            var checked: Dictionary = DNA.read_track(candidate)
            if bool(checked.get("ok",false)):
                chosen = candidate
    elif FileAccess.file_exists(CUSTOM):
        chosen = CUSTOM
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(chosen))
    if not (raw is Dictionary):
        raw = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
        chosen = SOURCE
    data = raw
    if chosen == SOURCE:
        data["id"] = "player_custom_track"
        data["name"] = "MY CUSTOM CIRCUIT"
    else:
        last_saved_path = chosen
        last_saved_name = str(data.get("name","MY CUSTOM CIRCUIT"))
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
    if (data.get("control_points",[]) as Array).is_empty():
        base_mid = Vector2.ZERO
        base_span = Vector2(310,310)
        base_ppm = minf(canvas.size.x,canvas.size.y)/310.0
    else:
        base_mid = (smallest+largest)*0.5
        base_span = (largest-smallest).max(Vector2(60,60))
        base_ppm = minf(canvas.size.x*0.84/maxf(base_span.x,1.0),
            canvas.size.y*0.84/maxf(base_span.y,1.0))
    _apply_view()

func _apply_view() -> void:
    var limit: Vector2 = base_span*0.5+Vector2(80,80)
    pan_offset = pan_offset.clamp(-limit,limit)
    world_mid = base_mid+pan_offset
    pixels_per_metre = base_ppm*zoom_level
    queue_redraw()

## Zoom keeping the world point under `screen_pos` fixed (pinch / wheel).
func _zoom_at(screen_pos: Vector2, new_zoom: float) -> void:
    var anchor: Vector2 = _world_point(screen_pos)
    zoom_level = clampf(new_zoom,ZOOM_MIN,ZOOM_MAX)
    var ppm: float = base_ppm*zoom_level
    pan_offset = anchor-(screen_pos-canvas.get_center())/ppm-base_mid
    _apply_view()

## Move the view by a screen-space drag delta.
func _pan_by(screen_delta: Vector2) -> void:
    pan_offset -= screen_delta/maxf(pixels_per_metre,0.0001)
    _apply_view()

func _fit_all() -> void:
    zoom_level = 1.0
    pan_offset = Vector2.ZERO
    _fit_view()

func _screen_point(p: Vector2) -> Vector2:
    return canvas.get_center()+(p-world_mid)*pixels_per_metre

func _world_point(p: Vector2) -> Vector2:
    return (p-canvas.get_center())/pixels_per_metre+world_mid

func _make_ui() -> void:
    var s: Vector2 = get_viewport_rect().size
    var scale: float = clampf(s.x/720.0,0.75,2.0)
    theme = STYLE.screen_theme(clampf(s.x/700.0,0.85,1.8))
    var logo := TextureRect.new()
    logo.name = "Nitro Wheelz brand mark"
    logo.texture = load("res://assets/brand/nitro_wheelz_logo.svg") as Texture2D
    # expand_mode must be set BEFORE size, or the SVG's native 620x349
    # minimum size wins and the logo overlaps the title/instructions.
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    logo.position = Vector2(s.x*0.03,s.y*0.008)
    logo.size = Vector2(s.x*0.30,s.y*0.070)
    logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(logo)
    var title := Label.new()
    title.text = "TRACK EDITOR  /  BETA"
    title.position = Vector2(s.x*0.36,s.y*0.022)
    title.size = Vector2(s.x*0.61,s.y*0.047)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    title.add_theme_font_size_override("font_size",int(24.0*scale))
    title.add_theme_font_override("font",STYLE.BOLD)
    title.add_theme_color_override("font_color",STYLE.WHITE)
    add_child(title)
    var instructions := Label.new()
    instructions.text = "DRAG nodes • DRAG empty map / 2 FINGERS = move & pinch zoom • ADD NODE then tap • ORANGE selected / RED invalid"
    instructions.position = Vector2(s.x*0.05,s.y*0.090)
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
    _button("FIT",0.832,0.486,0.112,0.042,Callable(self,"_fit_all"))
    _button("ZOOM +",0.832,0.534,0.112,0.042,func(): _zoom(1.25))
    _button("ZOOM -",0.832,0.582,0.112,0.042,func(): _zoom(0.8))
    _button("ADD NODE",0.05,0.746,0.28,0.065,Callable(self,"_add_point"))
    _button("DELETE NODE",0.36,0.746,0.28,0.065,Callable(self,"_delete_point"))
    _button("↶ UNDO",0.67,0.746,0.28,0.065,Callable(self,"_undo"))
    _button("VALIDATE",0.05,0.825,0.425,0.065,Callable(self,"_validate"))
    _button("SAVE AS...",0.525,0.825,0.425,0.065,Callable(self,"_request_save"))
    _button("START NEW",0.05,0.905,0.275,0.055,Callable(self,"_request_new"))
    _button("BACK",0.36,0.905,0.275,0.055,Callable(self,"_back"))
    _button("DRIVE",0.675,0.905,0.275,0.055,Callable(self,"_drive"))


func _save_undo_snapshot() -> void:
    undo_stack.append({
        "data":data.duplicate(true),
        "selected":selected,
        "add_mode":add_mode,
        "zoom":zoom_level,
        "last_saved_path":last_saved_path,
        "last_saved_name":last_saved_name
    })
    if undo_stack.size()>48:
        undo_stack.pop_front()

func _undo() -> void:
    if undo_stack.is_empty():
        _status("NOTHING TO UNDO",false)
        return
    var state: Dictionary = undo_stack.pop_back()
    data = (state["data"] as Dictionary).duplicate(true)
    selected = int(state["selected"])
    add_mode = bool(state["add_mode"])
    zoom_level = float(state["zoom"])
    last_saved_path = str(state["last_saved_path"])
    last_saved_name = str(state["last_saved_name"])
    pointer = -999
    drag_recorded = false
    _fit_view()
    _validate()

func _close_dialog() -> void:
    if dialog_overlay != null:
        dialog_overlay.queue_free()
        dialog_overlay = null

func _modal_button(parent: Node,caption: String,action: Callable,scale: float) -> void:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size.y = 48.0*scale
    button.add_theme_font_size_override("font_size",int(20.0*scale))
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.pressed.connect(action)
    parent.add_child(button)

func _show_dialog(kind: String) -> void:
    _close_dialog()
    var s: Vector2 = get_viewport_rect().size
    var sc: float = clampf(s.x/700.0,0.90,1.65)
    dialog_overlay = ColorRect.new()
    dialog_overlay.name = "Single accessible editor modal"
    dialog_overlay.color = Color(0.005,0.004,0.011,0.71)
    dialog_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    dialog_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(dialog_overlay)
    var panel := PanelContainer.new()
    panel.position = Vector2(s.x*0.065,s.y*0.13)
    panel.size = Vector2(s.x*0.87,s.y*(0.25 if kind=="save" else 0.21))
    panel.custom_minimum_size = panel.size
    panel.add_theme_stylebox_override("panel",STYLE.modal_box(sc))
    dialog_overlay.add_child(panel)
    var margin := MarginContainer.new()
    for side in ["margin_left","margin_right","margin_top","margin_bottom"]:
        margin.add_theme_constant_override(side,int(15.0*sc))
    panel.add_child(margin)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation",int(10.0*sc))
    margin.add_child(stack)
    var title := Label.new()
    title.text = "SAVE TRACK" if kind=="save" else "START NEW TRACK"
    title.add_theme_font_size_override("font_size",int(24.0*sc))
    title.add_theme_color_override("font_color",Color(1.0,0.82,0.25))
    stack.add_child(title)
    var hint := Label.new()
    hint.text = "Give your circuit a name" if kind=="save" else "Unsaved edits will be replaced"
    hint.add_theme_font_size_override("font_size",int(16.0*sc))
    hint.add_theme_color_override("font_color",Color(0.86,0.84,0.92))
    stack.add_child(hint)
    if kind=="save":
        name_input = LineEdit.new()
        name_input.text = last_saved_name
        name_input.placeholder_text = "e.g. Welsh Mountain Drift"
        name_input.max_length = 42
        name_input.custom_minimum_size.y = 48.0*sc
        name_input.add_theme_font_size_override("font_size",int(21.0*sc))
        stack.add_child(name_input)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation",int(11.0*sc))
    stack.add_child(row)
    if kind=="save":
        _modal_button(row,"CANCEL",Callable(self,"_close_dialog"),sc)
        _modal_button(row,"SAVE",Callable(self,"_confirm_save"),sc)
        name_input.grab_focus()
    else:
        _modal_button(row,"CANCEL",Callable(self,"_close_dialog"),sc)
        _modal_button(row,"CIRCLE",Callable(self,"_choose_circle"),sc)
        _modal_button(row,"BLANK",Callable(self,"_choose_blank"),sc)

func _choose_circle() -> void:
    _close_dialog()
    _start_new_circle()

func _choose_blank() -> void:
    _close_dialog()
    _start_new_blank()


func _zoom(multiplier: float) -> void:
    # Buttons zoom around the canvas centre, keeping the current pan.
    _zoom_at(canvas.get_center(),zoom_level*multiplier)

func _request_new() -> void:
    _show_dialog("start")

func _start_new_circle() -> void:
    _save_undo_snapshot()
    var points: Array = []
    for i in range(16):
        var angle: float = PI+TAU*float(i)/16.0
        points.append([
            snappedf(cos(angle)*105.0,0.001),
            snappedf(sin(angle)*105.0,0.001)
        ])
    _replace_new_track(points,false)
    _validate()

func _start_new_blank() -> void:
    _save_undo_snapshot()
    _replace_new_track([],true)
    _status("BLANK • Tap the map to place 8+ control points",false)

func _replace_new_track(points: Array,adding: bool) -> void:
    data = {
        "schema_version":1,
        "id":"player_custom_track",
        "name":"UNTITLED TRACK",
        "generator_version":1,
        "seed":0,
        "closed":true,
        "width_m":24.0,
        "control_points":points
    }
    selected = -1
    pointer = -999
    add_mode = adding
    zoom_level = 1.0
    pan_offset = Vector2.ZERO
    ready_to_play = false
    invalid_nodes.clear()
    last_saved_path = ""
    last_saved_name = ""
    _fit_view()
    queue_redraw()

func _request_save() -> void:
    _validate()
    if not ready_to_play:
        _status("FIX RED NODES FIRST • Cannot save invalid geometry",false)
        return
    pending_drive = false
    _show_dialog("save")

func _safe_slug(name: String) -> String:
    var clean: String = ""
    for i in range(name.length()):
        var ch: String = name.substr(i,1).to_lower()
        if ch in "abcdefghijklmnopqrstuvwxyz0123456789":
            clean += ch
        elif ch in " -_":
            if not clean.ends_with("_"):
                clean += "_"
    clean = clean.strip_edges().trim_suffix("_")
    if clean.is_empty():
        clean = "track"
    return clean.substr(0,40)

func _confirm_save() -> void:
    var title: String = name_input.text.strip_edges()
    if title.is_empty():
        _status("ENTER A TRACK NAME BEFORE SAVING",false)
        pending_drive = false
        return
    if not _persist_track(title):
        pending_drive = false
        return
    _close_dialog()
    if pending_drive:
        pending_drive = false
        ProjectSettings.set_setting("nitro/selected_track",last_saved_path)
        get_tree().change_scene_to_file("res://scenes/race.tscn")

func _persist_track(title: String) -> bool:
    _validate()
    if not ready_to_play:
        return false
    var slug: String = _safe_slug(title)
    var path: String = "user://nitro_track_"+slug+".json"
    data["id"] = "custom_"+slug
    data["name"] = title
    var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
    if file == null:
        _status("FAILED • Device storage unavailable",false)
        return false
    file.store_string(JSON.stringify(data,"  "))
    file.close()
    var compiled: Dictionary = DNA.read_track(path)
    if not bool(compiled.get("ok",false)):
        _status("FAILED • Saved file did not pass validator",false)
        return false
    var recent: FileAccess = FileAccess.open(LAST_SAVED,FileAccess.WRITE)
    if recent != null:
        recent.store_string(path)
        recent.close()
    last_saved_path = path
    last_saved_name = title
    _status("SAVED • "+title+" • %.0f m" % last_length,true)
    return true

func _button(text: String,xx: float,yy: float,ww: float,hh: float,action: Callable) -> void:
    var s: Vector2 = get_viewport_rect().size
    var button := Button.new()
    button.text = text
    button.position = Vector2(s.x*xx,s.y*yy)
    button.size = Vector2(s.x*ww,s.y*hh)
    button.add_theme_font_size_override("font_size",int(clampf(s.x/31.0,14.0,30.0)))
    STYLE.style_button(button,clampf(s.x/700.0,0.85,1.8))
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
    invalid_nodes.clear()
    if ready_to_play:
        last_length = float(result["length_metres"])
        _status("VALID • %.0f m / %.1f m width • closed loop" % [last_length,float(data["width_m"])],true)
    else:
        var errors: PackedStringArray = result.get("errors",PackedStringArray())
        for error in errors:
            _flag_problem_nodes(str(error))
        _status("INVALID • "+(str(errors[0]) if not errors.is_empty() else "Unknown geometry error"),false)
    queue_redraw()

func _flag_ring_sample(sample_index: int) -> void:
    if _point_count() == 0:
        return
    var knot: int = int(floor(float(sample_index)/float(DNA.SUBDIVISIONS)))%_point_count()
    # Segment belongs to two nearby editable nodes.
    invalid_nodes[knot] = true
    invalid_nodes[(knot+1)%_point_count()] = true

func _flag_problem_nodes(message: String) -> void:
    # Convert validator's sampled geometry segments back to editable knots.
    # Do not invent precision: highlight the two nearest source nodes.
    var regex := RegEx.new()
    var a: int = -1
    var b: int = -1
    if message.contains("samples "):
        regex.compile("samples ([0-9]+)/([0-9]+)")
        var match_samples: RegExMatch = regex.search(message)
        if match_samples != null:
            a = int(match_samples.get_string(1))
            b = int(match_samples.get_string(2))
    elif message.contains("segments "):
        regex.compile("segments ([0-9]+) and ([0-9]+)")
        var match_segments: RegExMatch = regex.search(message)
        if match_segments != null:
            a = int(match_segments.get_string(1))
            b = int(match_segments.get_string(2))
    elif message.contains("at sample "):
        regex.compile("at sample ([0-9]+)")
        var match_sample: RegExMatch = regex.search(message)
        if match_sample != null:
            a = int(match_sample.get_string(1))
    elif message.contains("knot ") or message.contains("control points at "):
        regex.compile("(?:knot |control points at )([0-9]+)")
        var match_knot: RegExMatch = regex.search(message)
        if match_knot != null and _point_count() > 0:
            var knot: int = int(match_knot.get_string(1))%_point_count()
            invalid_nodes[knot] = true
            invalid_nodes[(knot+1)%_point_count()] = true
    if a >= 0:
        _flag_ring_sample(a)
    if b >= 0:
        _flag_ring_sample(b)


func _drive() -> void:
    _validate()
    if not ready_to_play:
        _status("FIX RED NODES FIRST • Cannot drive an invalid track",false)
        return
    pending_drive = true
    _show_dialog("save")

func _reset_shape() -> void:
    _save_undo_snapshot()
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
    if n < 2:
        add_mode = true
        _status("ADD NODE ACTIVE • Tap the map to place each waypoint",true)
        return
    _save_undo_snapshot()
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
    _save_undo_snapshot()
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
    # Zoom buttons overlap the canvas; do not accidentally add road knots.
    var size: Vector2 = get_viewport_rect().size
    if pos.x > size.x*0.81 and pos.y > size.y*0.475 and pos.y < size.y*0.65:
        return
    var radius: float = maxf(17.0,get_viewport_rect().size.x*0.031)
    var closest: float = radius
    var found: int = -1
    for i in range(_point_count()):
        var d: float = pos.distance_to(_screen_point(_node_position(i)))
        if d < closest:
            closest = d
            found = i
    if found < 0 and add_mode:
        _save_undo_snapshot()
        var world: Vector2 = _world_point(pos)
        var points: Array = data["control_points"]
        points.append([snappedf(world.x,0.01),snappedf(world.y,0.01)])
        data["control_points"] = points
        selected = points.size()-1
        pointer = -999
        _validate()
        if points.size() < 8:
            _status("%d/8 NODES • Continue placing nodes to close the loop" % points.size(),false)
        elif ready_to_play:
            add_mode = false
        return
    selected = found
    pointer = pointer_index if found >= 0 else -999
    drag_recorded = false
    if found < 0:
        # Empty canvas: one-finger drag pans the zoomed view.
        pan_pointer = pointer_index
        pan_last = pos
    queue_redraw()

func _drag_touch(pos: Vector2,pointer_index: int) -> void:
    if pan_pointer == pointer_index and pointer == -999:
        _pan_by(pos-pan_last)
        pan_last = pos
        return
    if pointer != pointer_index or selected < 0:
        return
    var world: Vector2 = _world_point(pos)
    if not drag_recorded and world.distance_to(_node_position(selected)) > 0.05:
        _save_undo_snapshot()
        drag_recorded = true
    var pts: Array = data["control_points"]
    pts[selected] = [snappedf(world.x,0.01),snappedf(world.y,0.01)]
    data["control_points"] = pts
    _invalidate()

func _release_touch(pointer_index: int) -> void:
    if pan_pointer == pointer_index:
        pan_pointer = -999
    if pointer == pointer_index:
        pointer = -999
        drag_recorded = false
        _validate()

func _input(event: InputEvent) -> void:
    if dialog_overlay != null:
        return
    if event is InputEventKey and event.pressed and event.ctrl_pressed and event.keycode == KEY_Z:
        _undo()
        get_viewport().set_input_as_handled()
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            touches[event.index] = event.position
            if touches.size() == 2:
                _begin_pinch()
            elif not pinch_active:
                _start_touch(event.position,event.index)
        else:
            touches.erase(event.index)
            if pinch_active and touches.size() < 2:
                pinch_active = false
                pan_pointer = -999
            _release_touch(event.index)
    elif event is InputEventScreenDrag:
        touches[event.index] = event.position
        if pinch_active and touches.size() >= 2:
            _update_pinch()
        else:
            _drag_touch(event.position,event.index)
    elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
        if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _zoom_at(event.position,zoom_level*1.2)
            return
        if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoom_at(event.position,zoom_level/1.2)
            return
        if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
            pan_pointer = -3 if event.pressed else -999
            pan_last = event.position
            return
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _start_touch(event.position,-2)
            else:
                _release_touch(-2)
    elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
        if pan_pointer == -3:
            _pan_by(event.position-pan_last)
            pan_last = event.position
        elif pointer == -2 or pan_pointer == -2:
            _drag_touch(event.position,-2)

func _begin_pinch() -> void:
    # Two fingers: cancel any knot drag and pinch-zoom/pan the view.
    pinch_active = true
    pointer = -999
    pan_pointer = -999
    drag_recorded = false
    var pts: Array = touches.values()
    var a: Vector2 = pts[0]
    var b: Vector2 = pts[1]
    pinch_start_dist = maxf(a.distance_to(b),1.0)
    pinch_start_zoom = zoom_level
    pinch_anchor = _world_point((a+b)*0.5)

func _update_pinch() -> void:
    var pts: Array = touches.values()
    var a: Vector2 = pts[0]
    var b: Vector2 = pts[1]
    var mid: Vector2 = (a+b)*0.5
    zoom_level = clampf(pinch_start_zoom*a.distance_to(b)/pinch_start_dist,ZOOM_MIN,ZOOM_MAX)
    var ppm: float = base_ppm*zoom_level
    pan_offset = pinch_anchor-(mid-canvas.get_center())/ppm-base_mid
    _apply_view()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO,get_viewport_rect().size),Color(0.015,0.012,0.026),true)
    draw_rect(canvas,Color(0.062,0.049,0.093,0.92),true)
    draw_rect(canvas,Color(1.0,0.16,0.56,0.65),false,2.0)
    var n: int = _point_count()
    if n <= 0:
        return
    var line := PackedVector2Array()
    for idx in range(n):
        line.append(_screen_point(_node_position(idx)))
    if n >= 8:
        line.append(line[0])
    if n >= 2:
        var road_px: float = float(data.get("width_m",25.0))*pixels_per_metre
        draw_polyline(line,Color(0.20,0.22,0.27,0.88),road_px,true)
        draw_polyline(line,Color(0.95,0.95,0.98,0.8),2.0,true)
    # The white first node also represents start/finish.
    var origin: Vector2 = line[0]
    draw_arc(origin,15.0,0.0,TAU,32,Color(0.19,0.85,0.44,0.8),2.5,true)
    for idx in range(n):
        var point: Vector2 = line[idx]
        # Selection wins orange; invalid knots otherwise red; neutral white.
        var tint: Color = Color(1.0,0.56,0.09) if idx == selected else (
            Color(1.0,0.12,0.17) if invalid_nodes.has(idx) else Color(0.94,0.94,0.96))
        draw_circle(point,10.0,tint)
        draw_circle(point,4.0,Color(0.035,0.041,0.050))
