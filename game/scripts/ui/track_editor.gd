extends Control
## Nitro Wheelz Track Editor beta: touch and mouse drag of spline knots,
## insert/delete, validate, save to user://, and play. Not a random generator.
const DNA = preload("res://scripts/world/track_dna.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")
const TOOLS = preload("res://scripts/world/track_edit_tools.gd")
const BUSY = preload("res://scripts/ui/busy_overlay.gd")
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
var map_view: Control
var header_name: Label
var help_check: CheckBox
var zoom_strip: Rect2 = Rect2()
## Compiled spline and the sample ranges the validator rejected, so the
## failing arc itself can be drawn in red (not just its nodes).
var compiled_samples: Array = []
var problem_ranges: Array[Vector2i] = []
var problems: Array[Dictionary] = []     # DNA.diagnose(): every problem, exact stretches
var preview: Dictionary = {}             # DNA.sample_curve() of the current knots
var grab_offset: Vector2 = Vector2.ZERO  # finger -> node offset while dragging
var smooth_button: Button
## v0.1.42: circuits of the Terrain Builder keep their landscape here. The field is rebuilt from the saved world
## descriptor, the road heights are re-solved on it when saving, and stretches that cannot be built are red.
var terrain_key: String = ""
var terrain_field: NitroTerrainField = null
var terrain_tex: ImageTexture = null
var terrain_ok: bool = true
var terrain_flagged: Dictionary = {}
var terrain_reasons: Array = []
var open_kind: String = "nodes"
const HELP_LINES: Array[String] = [
    "DRAG a node to reshape the road",
    "DRAG empty map to move  •  2 FINGERS pinch to zoom",
    "ADD NODE, then tap the map to place it",
    "ORANGE = selected node  •  RED = problem section",
    "GREEN frame = drivable  •  RED frame = fix the track",
    "AUTO-SMOOTH widens a too-tight red corner for you",
    "OPEN loads any saved circuit (terrain, 3D tiles, nodes)",
    "SET START: tap a node, then SET START (it drives to the next node)",
    "REVERSE turns the driving direction round",
    "SAVE AS names your track  •  DRIVE tests it"]

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS
    # TRACK BUILDER > EDIT NODES asks for the circuit touched last (also one just built in a builder); every other way
    # in (MY TRACKS > EDIT, results > EDIT TRACK, tests) names its circuit through the last-path marker.
    var latest: bool = bool(ProjectSettings.get_setting("nitro/editor_open_latest",false))
    ProjectSettings.set_setting("nitro/editor_open_latest",false)
    var chosen: String = TOOLS.default_track_path() if latest else TOOLS.marker_track_path()
    if chosen == "" and FileAccess.file_exists(CUSTOM):
        chosen = CUSTOM
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(chosen)) if chosen != "" else null
    if not (raw is Dictionary) or not bool(DNA.compile(raw).get("ok",false)):
        raw = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
        chosen = SOURCE
    # Point-to-point routes (terrain) are edited in the Terrain Builder; this editor shapes closed circuits.
    if chosen != SOURCE and TOOLS.is_open_route(raw) and TOOLS.kind_of(raw) == "terrain":
        ProjectSettings.set_setting("nitro/terrain_edit_track",chosen)
        get_tree().call_deferred("change_scene_to_file","res://scenes/terrain_builder.tscn")
        return
    _adopt(raw,"" if chosen == SOURCE else chosen,"MY CUSTOM CIRCUIT" if chosen == SOURCE else "")
    _fit_view()
    _make_ui()
    _sync_terrain()
    _validate()
    _update_header()
    if not help_hidden():
        _show_dialog("help")

## Take a circuit (a parsed track file) as the one being edited. `path` = the file it came from ("" = a copy that
## is not saved yet), `copy_name` = a name for such a copy.
func _adopt(raw: Dictionary, path: String, copy_name: String) -> void:
    data = raw.duplicate(true)
    if path == "":
        data["id"] = "player_custom_track"
        data["name"] = copy_name if copy_name != "" else str(data.get("name","MY CUSTOM CIRCUIT"))
        last_saved_path = ""
        last_saved_name = ""
    else:
        last_saved_path = path
        last_saved_name = str(data.get("name","MY CUSTOM CIRCUIT"))
    data["closed"] = true
    # OPEN has already validated the DNA. Preserve its physical width, including per-knot profiles.
    data["width_m"] = float(data.get("width_m",24.0))
    selected = -1
    pointer = -999
    add_mode = false
    zoom_level = 1.0
    pan_offset = Vector2.ZERO
    open_kind = TOOLS.kind_of(data)

func _redraw() -> void:
    queue_redraw()
    if map_view != null:
        map_view.queue_redraw()

func _update_header() -> void:
    if header_name != null:
        header_name.text = last_saved_name.to_upper() if not last_saved_name.is_empty() else "UNSAVED TRACK"

static func help_hidden() -> bool:
    var cfg := ConfigFile.new()
    if cfg.load(STYLE.SETTINGS_PATH) != OK:
        return false
    return bool(cfg.get_value("editor","hide_help",false))

static func set_help_hidden(hidden: bool) -> void:
    var cfg := ConfigFile.new()
    cfg.load(STYLE.SETTINGS_PATH)
    cfg.set_value("editor","hide_help",hidden)
    cfg.save(STYLE.SETTINGS_PATH)

## Clearly visible tick box (the default theme icon is near-invisible on
## the dark modal).
static func _tick_icon(checked: bool, sc: float) -> ImageTexture:
    var n: int = maxi(18,int(30.0*sc))
    var img := Image.create(n,n,false,Image.FORMAT_RGBA8)
    img.fill(Color(0,0,0,0))
    var border: int = maxi(2,int(3.0*sc))
    for y in range(n):
        for x in range(n):
            var edge: bool = x < border or y < border or x >= n-border or y >= n-border
            if edge:
                img.set_pixel(x,y,Color(0.95,0.95,1.0))
            elif checked and x >= border*2 and y >= border*2 and x < n-border*2 and y < n-border*2:
                img.set_pixel(x,y,STYLE.PINK)
    return ImageTexture.create_from_image(img)

func _close_help() -> void:
    if help_check != null and help_check.button_pressed:
        set_help_hidden(true)
    help_check = null
    _close_dialog()

func _fit_view() -> void:
    var s: Vector2 = get_viewport_rect().size
    # The edit window fills everything between the header and the
    # validation line; the map is clipped to it and never reaches the buttons.
    canvas = Rect2(s.x*0.03,s.y*0.066,s.x*0.94,s.y*0.628)
    if map_view != null:
        map_view.position = canvas.position
        map_view.size = canvas.size
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
    _redraw()

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
    STYLE.ensure_settings()
    var title := Label.new()
    title.name = "Editor title"
    title.text = "TRACK\nEDITOR"
    title.position = Vector2(s.x*0.03,s.y*0.008)
    title.size = Vector2(s.x*0.24,s.y*0.052)
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_constant_override("line_spacing",int(-6.0*scale))
    title.add_theme_font_size_override("font_size",int(30.0*scale))
    title.add_theme_font_override("font",STYLE.BOLD)
    title.add_theme_color_override("font_color",STYLE.WHITE)
    add_child(title)
    header_name = Label.new()
    header_name.name = "Saved track name"
    header_name.position = Vector2(s.x*0.27,s.y*0.012)
    header_name.size = Vector2(s.x*0.46,s.y*0.045)  # centred on screen
    header_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header_name.clip_text = true
    header_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    header_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    header_name.add_theme_font_override("font",STYLE.BOLD)
    header_name.add_theme_font_size_override("font_size",int(27.0*scale))
    header_name.add_theme_color_override("font_color",STYLE.PINK)
    add_child(header_name)
    map_view = Control.new()
    map_view.name = "Clipped edit window"
    map_view.clip_contents = true
    map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    map_view.position = canvas.position
    map_view.size = canvas.size
    map_view.draw.connect(_draw_map)
    add_child(map_view)
    message_label = Label.new()
    message_label.name = "Validation line"
    message_label.position = Vector2(s.x*0.03,s.y*0.698)
    message_label.size = Vector2(s.x*0.94,s.y*0.036)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    message_label.clip_text = true
    message_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    message_label.add_theme_font_override("font",STYLE.BOLD)
    message_label.add_theme_font_size_override("font_size",int(20.0*scale))
    add_child(message_label)
    var help_button: Button = _button("?",0.875,0.010,0.095,0.046,func(): _show_dialog("help"))
    help_button.add_theme_font_size_override("font_size",int(clampf(s.x/30.0,14.0,30.0)))
    help_button.size = Vector2(s.x*0.095,s.y*0.046)
    # Zoom controls float in the top-right corner of the edit window.
    var zoom_buttons: Array[Button] = [
        _button("FIT",0.845,0.080,0.112,0.042,Callable(self,"_fit_all")),
        _button("ZOOM +",0.845,0.127,0.112,0.042,func(): _zoom(1.25)),
        _button("ZOOM -",0.845,0.174,0.112,0.042,func(): _zoom(0.8))]
    zoom_strip = Rect2()
    for zb in zoom_buttons:
        zb.add_theme_font_size_override("font_size",int(clampf(s.x/36.0,13.0,28.0)))
        zb.size = Vector2(s.x*0.112,s.y*0.042)
        zb.position.x = canvas.end.x-s.x*0.012-zb.size.x
        var r := Rect2(zb.position,zb.size)
        zoom_strip = r if zoom_strip.size == Vector2.ZERO else zoom_strip.merge(r)
    zoom_strip = zoom_strip.grow(6.0)
    # Four rows (v0.1.42): nodes | start + fix | file | leave + drive.
    _button("ADD NODE",0.03,0.742,0.30,0.054,Callable(self,"_add_point"))
    _button("DELETE NODE",0.35,0.742,0.30,0.054,Callable(self,"_delete_point"))
    _button("↶ UNDO",0.67,0.742,0.30,0.054,Callable(self,"_undo"))
    # Validation runs after every edit; this slot FIXES problems.
    _button("SET START",0.03,0.801,0.30,0.054,Callable(self,"_set_start")).name = "Set start"
    _button("REVERSE",0.35,0.801,0.30,0.054,Callable(self,"_reverse")).name = "Reverse"
    smooth_button = _button("AUTO-SMOOTH",0.67,0.801,0.30,0.054,Callable(self,"_auto_smooth"))
    smooth_button.name = "Auto smooth"
    _button("OPEN...",0.03,0.860,0.30,0.054,Callable(self,"_request_open")).name = "Open"
    _button("SAVE AS...",0.35,0.860,0.30,0.054,Callable(self,"_request_save"))
    _button("START NEW",0.67,0.860,0.30,0.054,Callable(self,"_request_new"))
    _button("BACK",0.03,0.919,0.30,0.054,Callable(self,"_back"))
    _button("DRIVE",0.35,0.919,0.62,0.054,Callable(self,"_drive")).name = "Drive"

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
    _update_header()
    pointer = -999
    drag_recorded = false
    _fit_view()
    _sync_terrain()
    _validate()

func _close_dialog() -> void:
    if dialog_overlay != null:
        dialog_overlay.queue_free()
        dialog_overlay = null

func _modal_button(parent: Node,caption: String,action: Callable,scale: float) -> void:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size.y = 48.0*scale
    button.add_theme_font_size_override("font_size",int(23.0*scale))
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
    if kind=="help":
        # Fit the content height so the popup has no empty tail.
        panel.position.y = s.y*0.20
        panel.size.y = 0.0
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
    title.text = "SAVE TRACK" if kind=="save" else ("HOW TO EDIT" if kind=="help" else "START NEW TRACK")
    title.add_theme_font_size_override("font_size",int(28.0*sc))
    title.add_theme_color_override("font_color",Color(1.0,0.82,0.25))
    stack.add_child(title)
    var hint := Label.new()
    hint.text = "Give your circuit a name" if kind=="save" else (
        "\n".join(HELP_LINES) if kind=="help" else "Unsaved edits will be replaced")
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size",int((24.0 if kind=="help" else 19.0)*sc))
    hint.add_theme_color_override("font_color",Color(0.86,0.84,0.92))
    if kind=="help":
        hint.add_theme_constant_override("line_spacing",int(6.0*sc))
    stack.add_child(hint)
    if kind=="help":
        help_check = CheckBox.new()
        help_check.name = "Do not show again"
        help_check.text = "Don't show again"
        help_check.add_theme_font_size_override("font_size",int(23.0*sc))
        help_check.custom_minimum_size.y = 48.0*sc
        help_check.add_theme_icon_override("unchecked",_tick_icon(false,sc))
        help_check.add_theme_icon_override("checked",_tick_icon(true,sc))
        help_check.add_theme_constant_override("h_separation",int(12.0*sc))
        stack.add_child(help_check)
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
    if kind=="help":
        _modal_button(row,"CLOSE",Callable(self,"_close_help"),sc)
    elif kind=="save":
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
    open_kind = "nodes"
    _sync_terrain()
    _update_header()
    _fit_view()
    _redraw()

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
    if terrain_field != null:
        # A terrain circuit is saved with the road heights solved on ITS landscape (what the Terrain Builder does).
        var fit: Dictionary = TOOLS.fit_terrain(data,terrain_field)
        if not bool(fit["ok"]):
            _status("TERRAIN • "+str((fit["reasons"] as Array)[0] if not (fit["reasons"] as Array).is_empty() else "NOT BUILDABLE"),false)
            return false
        data = fit["data"]
    # The tiles of a builder circuit describe the road as it was before the nodes were shaped.
    TOOLS.mark_node_shaped(data)
    var slug: String = _safe_slug(title)
    var path: String = "user://nitro_track_"+slug+".json"
    data["name"] = title
    # Records per layout (v0.1.32): the id carries a geometry fingerprint.
    data["id"] = load("res://scripts/ui/race_results.gd").layout_id("custom_"+slug,data)
    var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
    if file == null:
        _status("FAILED • Device storage unavailable",false)
        return false
    # Full float precision: the saved file is exactly the validated track.
    file.store_string(JSON.stringify(data,"  ",false,true))
    file.close()
    var compiled: Dictionary = DNA.read_track(path)
    if not bool(compiled.get("ok",false)):
        _status("FAILED • Saved file did not pass validator",false)
        return false
    if compiled["centerline"] != DNA.compile(data)["centerline"]:
        _status("FAILED • Saved geometry differs from the editor",false)
        return false
    # Keep editing exactly what the file holds (what the race will load).
    var reread: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if reread is Dictionary:
        data["control_points"] = reread["control_points"]
        _refresh_preview()
    var recent: FileAccess = FileAccess.open(LAST_SAVED,FileAccess.WRITE)
    if recent != null:
        recent.store_string(path)
        recent.close()
    last_saved_path = path
    last_saved_name = title
    _update_header()
    _status("SAVED • "+title+" • %.0f m" % last_length,true)
    return true

func _button(text: String,xx: float,yy: float,ww: float,hh: float,action: Callable) -> Button:
    var s: Vector2 = get_viewport_rect().size
    var button := Button.new()
    button.text = text
    button.position = Vector2(s.x*xx,s.y*yy)
    button.size = Vector2(s.x*ww,s.y*hh)
    # Larger labels: owner found the old 23 px hard to read on the phone.
    button.add_theme_font_size_override("font_size",int(clampf(s.x/25.0,16.0,36.0)))
    STYLE.style_button(button,clampf(s.x/700.0,0.85,1.8))
    button.pressed.connect(action)
    add_child(button)
    return button

func _status(txt: String,valid: bool) -> void:
    message_label.text = txt
    message_label.add_theme_color_override("font_color",Color(0.55,0.95,0.77) if valid else Color(1.0,0.43,0.50))

## The road exactly as the race will build it: same spline, width, edges
## (= barrier lines) and start line (knot 0, driving towards knot 1).
func _refresh_preview() -> void:
    preview = {}
    var n: int = _point_count()
    if n < 8:
        return
    var pts: Array[Vector2] = []
    var widths := PackedFloat32Array()
    var profile: Array = data.get("widths_m",[])
    for i in range(n):
        pts.append(_node_position(i))
        widths.append(float(profile[i]) if profile.size()==n else float(data.get("width_m",24.0)))
    preview = DNA.sample_curve(pts,widths)

## Node size and finger hit area scale with the screen (phones: ~9 mm).
func node_radius() -> float:
    var v: Vector2 = get_viewport_rect().size
    return clampf(minf(v.x,v.y)*0.017,10.0,22.0)

func hit_radius() -> float:
    var v: Vector2 = get_viewport_rect().size
    return maxf(node_radius()*2.6,minf(v.x,v.y)*0.06)

func _invalidate() -> void:
    _refresh_preview()
    ready_to_play = false
    _status("CHANGED • Validate before driving",false)
    _redraw()

func _validate() -> void:
    var result: Dictionary = DNA.compile(data)
    ready_to_play = bool(result.get("ok",false))
    invalid_nodes.clear()
    problem_ranges.clear()
    problems.clear()
    terrain_flagged.clear()
    terrain_reasons = []
    terrain_ok = true
    compiled_samples = result.get("centerline",[])
    _refresh_preview()
    if ready_to_play:
        last_length = float(result["length_metres"])
        var valid_text: String = "VALID • %.0f m / %.1f m width • closed loop" % [last_length,float(data["width_m"])]
        if terrain_field != null:
            var fit: Dictionary = TOOLS.fit_terrain(data,terrain_field)
            terrain_ok = bool(fit["ok"])
            terrain_reasons = fit["reasons"]
            for k in fit["flagged"]:
                terrain_flagged[int(k)] = true
            # Short enough for a phone line: length, the #29 event + surface (or the width), terrain verdict.
            var ev: String = TOOLS.event_label(data)
            valid_text = "VALID • %.0f m • %s • TERRAIN OK" % [last_length,ev if ev != "" else "%.0f m WIDE" % float(data["width_m"])]
        if terrain_ok:
            _status(valid_text,true)
        else:
            # Geometry is fine but the road would be built over water / a cliff: not drivable yet.
            ready_to_play = false
            for k in terrain_flagged:
                invalid_nodes[int(k)] = true
            _status("TERRAIN • %s • MOVE THE RED NODES" % str(terrain_reasons[0] if not terrain_reasons.is_empty() else "NOT BUILDABLE"),false)
    else:
        var errors: PackedStringArray = result.get("errors",PackedStringArray())
        if result.has("centerline"):
            # Every problem with its exact stretch, not just the first one.
            problems = DNA.diagnose(result)
            for prob in problems:
                for k in prob["knots"]:
                    invalid_nodes[int(k)] = true
                var m: int = compiled_samples.size()
                if str(prob["kind"]) == "tight":
                    var a: int = int(prob["from"])
                    var b: int = int(prob["to"])
                    problem_ranges.append(Vector2i(a-1,a+posmod(b-a,m)+1))
                else:
                    var ra: Vector2i = prob["a"]
                    var rb: Vector2i = prob["b"]
                    problem_ranges.append(Vector2i(ra.x-1,ra.y+2))
                    problem_ranges.append(Vector2i(rb.x-1,rb.y+2))
        if problems.is_empty():
            for error in errors:
                _flag_problem_nodes(str(error))
                _flag_problem_samples(str(error))
        var fixable: bool = not invalid_nodes.is_empty()
        var head: String = friendly_problem(problems[0]) if not problems.is_empty() else \
            friendly_error(str(errors[0]) if not errors.is_empty() else "")
        if problems.size() > 1:
            head = "%d PROBLEMS • %s" % [problems.size(),head]
        _status(head+("  •  TAP AUTO-SMOOTH" if fixable else ""),false)
    if smooth_button != null:
        STYLE.style_button(smooth_button,clampf(get_viewport_rect().size.x/700.0,0.85,1.8),not ready_to_play and terrain_ok)
    _redraw()

## Player-facing wording for one diagnosed problem.
static func friendly_problem(prob: Dictionary) -> String:
    match str(prob.get("kind","")):
        "tight":
            return "CORNER TOO TIGHT (%.0f m, needs %.0f m)" % [float(prob["radius"]),float(prob["need"])]
        "close":
            return "ROADS TOO CLOSE (%.0f m gap, needs %.0f m)" % [float(prob["gap"]),float(prob["need"])]
        "cross":
            return "INNER WALL FOLDS IN A TIGHT CORNER" if bool(prob["local"]) else "TRACK CROSSES ITSELF"
    return "INVALID"

## Short player-facing wording for validator messages (full text stays in
## the validator for tests/logs).
static func friendly_error(message: String) -> String:
    var regex := RegEx.new()
    regex.compile("Curve radius ([0-9.]+) m")
    var m: RegExMatch = regex.search(message)
    if m != null:
        return "CORNER TOO TIGHT (%s m)" % m.get_string(1)
    if message.contains("overlap"):
        return "ROADS TOO CLOSE TOGETHER"
    if message.contains("Self-intersecting"):
        return "TRACK CROSSES ITSELF"
    if message.contains("too-close control points"):
        return "TWO NODES ON TOP OF EACH OTHER"
    if message.contains("eight control points"):
        return "PLACE AT LEAST 8 NODES"
    return "INVALID • "+(message if not message.is_empty() else "Unknown geometry error")

## Sample ranges named in a validator message (radius / overlap / crossing).
func _flag_problem_samples(message: String) -> void:
    var regex := RegEx.new()
    regex.compile("(?:sample |samples |segments )([0-9]+)(?:(?:/| and )([0-9]+))?")
    var m: RegExMatch = regex.search(message)
    if m == null:
        return
    for g in [1,2]:
        var txt: String = m.get_string(g)
        if not txt.is_empty():
            var c: int = int(txt)
            problem_ranges.append(Vector2i(c-DNA.SUBDIVISIONS/2,c+DNA.SUBDIVISIONS/2))

## AUTO-SMOOTH: NitroTrackDNA.repair() fixes the reported problems with
## small local moves (tight corners relax, too-close stretches are pushed
## apart), never moving a node more than a set share of the track size, and
## never redesigning a real crossing. One UNDO step; says how much it moved.
func _auto_smooth() -> void:
    _validate()
    if ready_to_play:
        _status("ALREADY VALID • nothing to smooth",true)
        return
    if not terrain_ok:
        _status("TERRAIN • AUTO-SMOOTH only fixes corners • drag the red nodes off the water / cliff",false)
        return
    if _point_count() < 8:
        _status("PLACE AT LEAST 8 NODES FIRST",false)
        return
    var busy: CanvasLayer = null
    if get_tree().get_script() == null:
        # Game: show SMOOTHING… with the loading animation before the work.
        busy = load("res://scripts/ui/busy_overlay.gd").open(self,"SMOOTHING TRACK")
        await get_tree().process_frame
        await get_tree().process_frame
    var fix: Dictionary = DNA.repair(data)
    if busy != null:
        busy.queue_free()
    if not bool(fix.get("ok",false)):
        _status("CAN'T FIX AUTOMATICALLY • "+str(fix.get("reason","drag the red nodes apart")),false)
        return
    _save_undo_snapshot()
    data["control_points"] = fix["points"]
    _validate()
    _status("FIXED • moved %d nodes, max %.1f m • VALID • %.0f m" % [
        (fix["moved"] as Dictionary).size(),float(fix["max_move"]),last_length],true)

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

## --- terrain context -------------------------------------------------------------------------------------------

## Keep the landscape of a terrain circuit in step with `data` (rebuilt from the saved world descriptor; cached by
## archetype + seed). Other circuits have none.
func _sync_terrain() -> void:
    var key: String = TOOLS.field_key(data)
    if key == "":
        terrain_key = ""
        terrain_field = null
        terrain_tex = null
        return
    if key == terrain_key and terrain_field != null:
        return
    var busy: NitroBusy = null
    if get_tree().get_script() == null:
        busy = BUSY.open(self,"LOADING TERRAIN",true)
        await get_tree().process_frame
        await get_tree().process_frame
    terrain_field = TOOLS.field_for(data)
    terrain_key = key
    terrain_tex = ImageTexture.create_from_image(TOOLS.terrain_image(terrain_field))
    if busy != null:
        busy.close()
        _validate()
    _redraw()

## --- OPEN ------------------------------------------------------------------------------------------------------

func _request_open() -> void:
    _close_dialog()
    var s: Vector2 = get_viewport_rect().size
    var sc: float = clampf(s.x/700.0,0.90,1.65)
    dialog_overlay = ColorRect.new()
    dialog_overlay.name = "Open circuit modal"
    dialog_overlay.color = Color(0.005,0.004,0.011,0.78)
    dialog_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    dialog_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(dialog_overlay)
    var panel := PanelContainer.new()
    panel.position = Vector2(s.x*0.045,s.y*0.07)
    panel.size = Vector2(s.x*0.91,s.y*0.86)
    panel.custom_minimum_size = panel.size
    panel.add_theme_stylebox_override("panel",STYLE.modal_box(sc))
    dialog_overlay.add_child(panel)
    var margin := MarginContainer.new()
    for side in ["margin_left","margin_right","margin_top","margin_bottom"]:
        margin.add_theme_constant_override(side,int(14.0*sc))
    panel.add_child(margin)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation",int(9.0*sc))
    margin.add_child(stack)
    var title := Label.new()
    title.text = "OPEN A CIRCUIT"
    title.add_theme_font_size_override("font_size",int(28.0*sc))
    title.add_theme_font_override("font",STYLE.BOLD)
    title.add_theme_color_override("font_color",Color(1.0,0.82,0.25))
    stack.add_child(title)
    var hint := Label.new()
    hint.text = "Circuits from the Terrain Builder keep their landscape. Built-in circuits open as a copy."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size",int(17.0*sc))
    hint.add_theme_color_override("font_color",Color(0.86,0.84,0.92))
    stack.add_child(hint)
    var scroll := ScrollContainer.new()
    scroll.name = "Open list"
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    stack.add_child(scroll)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation",int(8.0*sc))
    scroll.add_child(list)
    for t in TOOLS.list_tracks():
        var entry: Dictionary = t
        var b := Button.new()
        var sub: String = "%s • %.0f m" % [str(entry["label"]),float(entry["length"])]
        if bool(entry["open"]):
            sub = "POINT-TO-POINT ROUTE • EDITED IN THE TERRAIN BUILDER"
        b.text = "%s\n%s" % [str(entry["name"]).to_upper(),sub]
        b.name = "Open "+str(entry["path"]).get_file().get_basename()
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.clip_text = true
        b.custom_minimum_size.y = 76.0*sc
        b.add_theme_font_size_override("font_size",int(19.0*sc))
        STYLE.style_button(b,sc)
        var path: String = str(entry["path"])
        var builtin_name: String = str(entry["name"]) if bool(entry["builtin"]) else ""
        b.pressed.connect(func(): _load_path(path,builtin_name))
        list.add_child(b)
    _modal_button(stack,"CANCEL",Callable(self,"_close_dialog"),sc)

## Load a saved circuit into the editor. `builtin_name` != "" = a built-in circuit, opened as an unsaved copy.
func _load_path(path: String,builtin_name: String = "") -> void:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
    if not (raw is Dictionary) or not bool(DNA.compile(raw).get("ok",false)):
        _close_dialog()
        _status("COULD NOT OPEN • that file is not a valid circuit",false)
        return
    if TOOLS.is_open_route(raw):
        _close_dialog()
        if TOOLS.kind_of(raw) == "terrain":
            ProjectSettings.set_setting("nitro/terrain_edit_track",path)
            get_tree().change_scene_to_file("res://scenes/terrain_builder.tscn")
        else:
            _status("POINT-TO-POINT ROUTES CAN'T BE SHAPED HERE",false)
        return
    _save_undo_snapshot()
    _close_dialog()
    _adopt(raw,"" if builtin_name != "" else path,("COPY OF "+builtin_name) if builtin_name != "" else "")
    _fit_view()
    _sync_terrain()
    _validate()
    _update_header()

## --- START point + direction ------------------------------------------------------------------------------------

## The selected node becomes the start line (knot 0); the car drives from it towards the next node.
func _set_start() -> void:
    if selected < 0 or selected >= _point_count():
        _status("TAP A NODE FIRST • it becomes the START and the car drives towards the next node",false)
        return
    if selected == 0:
        _status("THAT NODE IS ALREADY THE START • green arrow = driving direction",true)
        return
    _save_undo_snapshot()
    data = TOOLS.rotate_start(data,selected)
    selected = 0
    _validate()
    if ready_to_play:
        _status("START SET • drives towards the next node • %.0f m" % last_length,true)

## Drive the same road the other way round (the start stays on the same node).
func _reverse() -> void:
    var n: int = _point_count()
    if n < 3:
        return
    _save_undo_snapshot()
    data = TOOLS.reverse_direction(data)
    if selected > 0:
        selected = (n-selected)%n
    _validate()
    if ready_to_play:
        _status("DIRECTION REVERSED • green arrow shows the way • %.0f m" % last_length,true)

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
    var profile: Array = data.get("widths_m",[])
    if not profile.is_empty():
        profile.insert(idx+1,lerpf(float(profile[idx]),float(profile[(idx+1)%n]),0.5))
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
    var profile: Array = data.get("widths_m",[])
    if not profile.is_empty():
        profile.remove_at(selected)
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
    # Zoom buttons float over the canvas; do not accidentally add road knots.
    if zoom_strip.has_point(pos):
        return
    # Generous finger target; the node already selected wins ties so a
    # second touch keeps editing the same node.
    var radius: float = hit_radius()
    var closest: float = radius
    var found: int = -1
    for i in range(_point_count()):
        var d: float = pos.distance_to(_screen_point(_node_position(i)))
        if i == selected:
            d *= 0.75
        if d < closest:
            closest = d
            found = i
    if found < 0 and add_mode:
        _save_undo_snapshot()
        var world: Vector2 = _world_point(pos)
        var points: Array = data["control_points"]
        var profile: Array = data.get("widths_m",[])
        if not profile.is_empty():
            profile.append(lerpf(float(profile.back()),float(profile.front()),0.5))
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
    # Keep the finger-to-node offset: the node does not jump under the finger.
    grab_offset = _screen_point(_node_position(found))-pos if found >= 0 else Vector2.ZERO
    if found < 0:
        # Empty canvas: one-finger drag pans the zoomed view.
        pan_pointer = pointer_index
        pan_last = pos
    _redraw()

func _drag_touch(pos: Vector2,pointer_index: int) -> void:
    if pan_pointer == pointer_index and pointer == -999:
        _pan_by(pos-pan_last)
        pan_last = pos
        return
    if pointer != pointer_index or selected < 0:
        return
    var world: Vector2 = _world_point(pos+grab_offset)
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
        grab_offset = Vector2.ZERO
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
                if touches.size() == 1:
                    # One finger stays down after a pinch: keep panning
                    # with it (no jump, no accidental node grab).
                    pan_pointer = int(touches.keys()[0])
                    pan_last = touches.values()[0]
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

## Map drawing lives in a clip_contents child, so a zoomed or panned road
## can never spill under the header or the buttons.
func _draw_map() -> void:
    var v: Control = map_view
    var o: Vector2 = -canvas.position
    v.draw_rect(Rect2(Vector2.ZERO,canvas.size),Color(0.062,0.049,0.093,0.92),true)
    if terrain_tex != null:
        # The landscape of a terrain circuit (blue = water, shaded land); the frame is where the builder puts road.
        var tr: Rect2 = TOOLS.terrain_rect()
        var tl: Vector2 = _screen_point(tr.position)+o
        v.draw_texture_rect(terrain_tex,Rect2(tl,_screen_point(tr.end)+o-tl),false,Color(1,1,1,0.92))
        var pr: Rect2 = TOOLS.play_rect()
        var ptl: Vector2 = _screen_point(pr.position)+o
        v.draw_rect(Rect2(ptl,_screen_point(pr.end)+o-ptl),Color(1,1,1,0.30),false,2.0)
    # Faint 50 m grid for scale.
    var step: float = 50.0*pixels_per_metre
    if step > 14.0:
        var first: Vector2 = _world_point(canvas.position)
        var gx: float = ceil(first.x/50.0)*50.0
        while true:
            var sx: float = _screen_point(Vector2(gx,0)).x+o.x
            if sx > canvas.size.x:
                break
            v.draw_line(Vector2(sx,0),Vector2(sx,canvas.size.y),Color(1,1,1,0.035),1.0)
            gx += 50.0
        var gy: float = ceil(first.y/50.0)*50.0
        while true:
            var sy: float = _screen_point(Vector2(0,gy)).y+o.y
            if sy > canvas.size.y:
                break
            v.draw_line(Vector2(0,sy),Vector2(canvas.size.x,sy),Color(1,1,1,0.035),1.0)
            gy += 50.0
    var n: int = _point_count()
    if n > 0:
        var line := PackedVector2Array()
        for idx in range(n):
            line.append(_screen_point(_node_position(idx))+o)
        var road_px: float = float(data.get("width_m",25.0))*pixels_per_metre
        if not preview.is_empty():
            # The real road: asphalt between the edges, edge lines where
            # the barriers stand, thin centre line.
            var cl: Array = preview["centerline"]
            var le: Array = preview["left_edge"]
            var re: Array = preview["right_edge"]
            var m: int = cl.size()
            var lpts := PackedVector2Array()
            var rpts := PackedVector2Array()
            var cpts := PackedVector2Array()
            for k in range(m+1):
                lpts.append(_screen_point(Vector2(le[k%m]))+o)
                rpts.append(_screen_point(Vector2(re[k%m]))+o)
                cpts.append(_screen_point(Vector2(cl[k%m]))+o)
            var asphalt := PackedColorArray([Color(0.20,0.22,0.27,0.90)])
            for k in range(m):
                # Two triangles per slice: no triangulation, so a folded
                # (invalid) corner still draws, showing the fold.
                v.draw_primitive(PackedVector2Array([lpts[k],lpts[k+1],rpts[k+1]]),asphalt,PackedVector2Array())
                v.draw_primitive(PackedVector2Array([lpts[k],rpts[k+1],rpts[k]]),asphalt,PackedVector2Array())
            v.draw_polyline(lpts,Color(0.86,0.86,0.92,0.85),2.0,true)
            v.draw_polyline(rpts,Color(0.86,0.86,0.92,0.85),2.0,true)
            v.draw_polyline(cpts,Color(1,1,1,0.22),1.0,true)
            # Start / finish across the road at knot 0, arrow = driving direction.
            v.draw_line(lpts[0],rpts[0],Color(1,1,1,0.95),maxf(3.0,0.9*pixels_per_metre))
            var dir: Vector2 = (cpts[2]-cpts[0]).normalized()
            var tip: Vector2 = cpts[0]+dir*maxf(26.0,road_px*0.6)
            var side: Vector2 = Vector2(-dir.y,dir.x)*9.0
            v.draw_line(cpts[0],tip,Color(0.19,0.85,0.44,0.95),3.0,true)
            v.draw_primitive(PackedVector2Array([tip+dir*10.0,tip+side,tip-side]),PackedColorArray([Color(0.19,0.85,0.44,0.95)]),PackedVector2Array())
        elif n >= 2:
            v.draw_polyline(line,Color(0.20,0.22,0.27,0.88),road_px,true)
            v.draw_polyline(line,Color(0.95,0.95,0.98,0.8),2.0,true)
        # Failing stretches in red, exactly where the validator measured them.
        if not problem_ranges.is_empty() and compiled_samples.size() > 4:
            var m2: int = compiled_samples.size()
            for rng in problem_ranges:
                var arc := PackedVector2Array()
                for k in range(rng.x,rng.y+1):
                    arc.append(_screen_point(Vector2(compiled_samples[posmod(k,m2)]))+o)
                if arc.size() > 1:
                    v.draw_polyline(arc,Color(1.0,0.15,0.20,0.35),road_px,true)
                    v.draw_polyline(arc,Color(1.0,0.25,0.30,0.95),4.0,true)
        for prob in problems:
            if str(prob["kind"]) == "close":
                # The missing gap between the two stretches.
                var pa: Vector2 = _screen_point(Vector2(prob["at_a"]))+o
                var pb: Vector2 = _screen_point(Vector2(prob["at_b"]))+o
                v.draw_dashed_line(pa,pb,Color(1.0,0.35,0.35,0.95),3.0,8.0)
                v.draw_circle(pa,5.0,Color(1.0,0.35,0.35))
                v.draw_circle(pb,5.0,Color(1.0,0.35,0.35))
            elif str(prob["kind"]) == "cross":
                var c: Vector2 = _screen_point(Vector2(prob["at"]))+o
                v.draw_line(c-Vector2(9,9),c+Vector2(9,9),Color(1.0,0.3,0.3),4.0)
                v.draw_line(c-Vector2(9,-9),c+Vector2(9,-9),Color(1.0,0.3,0.3),4.0)
        var r: float = node_radius()
        # Start marker on node 0 (the car starts here and drives towards node 1), always visible.
        v.draw_arc(line[0],r*1.6,0.0,TAU,32,Color(0.19,0.85,0.44,0.9),3.0,true)
        for idx in range(n):
            var point: Vector2 = line[idx]
            # Selection wins orange; invalid knots otherwise red; neutral white.
            var tint: Color = Color(1.0,0.56,0.09) if idx == selected else (
                Color(1.0,0.12,0.17) if invalid_nodes.has(idx) else Color(0.94,0.94,0.96))
            if idx == selected and pointer != -999:
                # Being dragged: a ring larger than the finger shows the node.
                v.draw_arc(point,r*2.4,0.0,TAU,40,Color(1.0,0.56,0.09,0.9),3.0,true)
            v.draw_circle(point,r,tint)
            v.draw_circle(point,r*0.4,Color(0.035,0.041,0.050))
        if n >= 2:
            # "START" beside node 0, on the left of the driving direction, above the road and the nodes.
            var sdir: Vector2 = (line[1]-line[0]).normalized()
            var fs: int = int(clampf(r*1.25,13.0,24.0))
            var label_w: float = STYLE.text_width("START",float(fs))
            var label_at: Vector2 = line[0]+Vector2(-sdir.y,sdir.x)*(r*2.4+label_w*0.5)
            label_at.x = clampf(label_at.x,label_w*0.5+4.0,canvas.size.x-label_w*0.5-4.0)
            v.draw_string(STYLE.BOLD,label_at+Vector2(-label_w*0.5,fs*0.35),"START",HORIZONTAL_ALIGNMENT_LEFT,-1.0,fs,Color(0.55,1.0,0.70))
    # Validation frame: green = drivable, red = needs fixing.
    # Calm thin green when drivable; red with a soft glow when it needs work.
    var inset := Rect2(Vector2(2,2),canvas.size-Vector2(4,4))
    if ready_to_play:
        v.draw_rect(inset,Color(0.25,0.92,0.48,0.55),false,2.0)
    else:
        v.draw_rect(inset,Color(1.0,0.22,0.26,0.22),false,10.0)
        v.draw_rect(inset,Color(1.0,0.22,0.26,0.95),false,3.0)
