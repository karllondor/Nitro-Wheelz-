extends Node3D
## Nitro Wheelz 3D TRACK BUILDER (tap-to-build, procedural).
## Tap the grass: a road tile appears with kerbs, verge, flowers and trees.
## Tap next to the end of a road to extend it, drag to lay a strip, erase
## with ERASE, or let GENERATE grow a random loop. The preview is drawn by
## the same NitroDriftTrack code as the race; DRIVE compiles the closed loop
## through the fail-closed Track DNA validator, saves it and starts a race.

const GRID = preload("res://scripts/world/track_grid.gd")
const TRACK = preload("res://scripts/world/drift_track.gd")
const DNA = preload("res://scripts/world/track_dna.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")
const GRASS = preload("res://assets/surfaces/grass_night.webp")
const DRAFT: String = "user://nitro_builder_draft.json"
const BUILT: String = "user://nitro_track_built.json"
const LAST_SAVED: String = "user://nitro_editor_last_path.txt"
const TILT_DEG: float = 68.0
const REBUILD_INTERVAL: float = 0.35

var grid: NitroTrackGrid
var camera: Camera3D
var road_root: Node3D
var marker_root: Node3D
var highlight: MeshInstance3D
var highlight_mat: StandardMaterial3D
var flash_time: float = 0.0
var mode: String = "draw"
var stroke_active: bool = false
var stroke_pointer: int = -1
var stroke_last: Vector2i = Vector2i(-1,-1)
var stroke_changed: bool = false
var undo_stack: Array[Dictionary] = []
var dirty: bool = true
var since_rebuild: float = 99.0
var map_rect: Rect2 = Rect2()
var ui_layer: CanvasLayer
var title_label: Label
var status_label: Label
var hint_label: Label
var buttons: Dictionary = {}
var loop_ok: bool = false
var loop_length: float = 0.0
var seed_counter: int = 0
var ui_unit: float = 1.0

func _ready() -> void:
    grid = GRID.new(8,12)
    _load_draft()
    _build_world()
    _build_ui()
    _fit_camera()
    get_viewport().size_changed.connect(_on_resize)
    _rebuild()

# ------------------------------------------------------------------ world

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var res := Environment.new()
    res.background_mode = Environment.BG_COLOR
    res.background_color = Color(0.02,0.022,0.04)
    res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    res.ambient_light_color = Color(0.52,0.48,0.66)
    res.ambient_light_energy = 0.85
    env.environment = res
    add_child(env)
    var moon := DirectionalLight3D.new()
    moon.rotation_degrees = Vector3(-62,-38,0)
    moon.light_color = Color(0.86,0.87,1.0)
    moon.light_energy = 1.05
    add_child(moon)
    var size: Vector2 = grid.size_metres()
    var ground := MeshInstance3D.new()
    ground.name = "Builder grass"
    var plane := PlaneMesh.new()
    plane.size = size+Vector2(400,400)
    ground.mesh = plane
    ground.position.y = -0.08
    var gm := StandardMaterial3D.new()
    gm.albedo_texture = GRASS
    gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    gm.uv1_scale = Vector3(plane.size.x/18.0,plane.size.y/18.0,1.0)
    gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ground.material_override = gm
    add_child(ground)
    _build_grid_overlay(size)
    road_root = Node3D.new()
    road_root.name = "Built road preview"
    add_child(road_root)
    marker_root = Node3D.new()
    marker_root.name = "Open end markers"
    add_child(marker_root)
    highlight = MeshInstance3D.new()
    highlight.name = "Touched tile"
    var quad := PlaneMesh.new()
    quad.size = Vector2(GRID.CELL_M,GRID.CELL_M)*0.96
    highlight.mesh = quad
    highlight_mat = StandardMaterial3D.new()
    highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    highlight_mat.albedo_color = Color(1,0.16,0.56,0.0)
    highlight.material_override = highlight_mat
    highlight.position.y = 0.2
    add_child(highlight)
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.far = 4000.0
    add_child(camera)
    camera.current = true

func _build_grid_overlay(size: Vector2) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var half: Vector2 = size*0.5
    var w: float = 0.45
    var col := Color(1,1,1,0.13)
    for x in range(grid.cols+1):
        var px: float = -half.x+float(x)*GRID.CELL_M
        _strip(st,Vector2(px,-half.y),Vector2(px,half.y),w,col)
    for y in range(grid.rows+1):
        var py: float = -half.y+float(y)*GRID.CELL_M
        _strip(st,Vector2(-half.x,py),Vector2(half.x,py),w,col)
    var pink := Color(STYLE.PINK.r,STYLE.PINK.g,STYLE.PINK.b,0.85)
    _strip(st,Vector2(-half.x,-half.y),Vector2(half.x,-half.y),1.6,pink)
    _strip(st,Vector2(half.x,-half.y),Vector2(half.x,half.y),1.6,pink)
    _strip(st,Vector2(half.x,half.y),Vector2(-half.x,half.y),1.6,pink)
    _strip(st,Vector2(-half.x,half.y),Vector2(-half.x,-half.y),1.6,pink)
    var mesh: ArrayMesh = st.commit()
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh.surface_set_material(0,mat)
    var node := MeshInstance3D.new()
    node.name = "Build grid"
    node.mesh = mesh
    node.position.y = 0.0
    add_child(node)

func _strip(st: SurfaceTool, a: Vector2, b: Vector2, width: float, col: Color) -> void:
    var d: Vector2 = (b-a).normalized()
    var n := Vector2(-d.y,d.x)*width*0.5
    var pts: Array[Vector3] = []
    for p in [a-n,a+n,b-n,b+n]:
        pts.append(Vector3(p.x,0.0,p.y))
    for k in [0,1,2,2,1,3]:
        st.set_color(col)
        st.set_normal(Vector3.UP)
        st.add_vertex(pts[k])

# --------------------------------------------------------------------- ui

func _build_ui() -> void:
    var s: Vector2 = get_viewport().get_visible_rect().size
    ui_unit = clampf(s.x/700.0,0.85,1.8)
    ui_layer = CanvasLayer.new()
    ui_layer.layer = 8
    add_child(ui_layer)
    var root := Control.new()
    root.name = "Builder UI"
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.theme = STYLE.screen_theme(ui_unit)
    ui_layer.add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var header := Panel.new()
    header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header.position = Vector2(s.x*0.022,s.y*0.012)
    header.size = Vector2(s.x*0.956,s.y*0.088)
    header.add_theme_stylebox_override("panel",STYLE.modal_box(ui_unit))
    root.add_child(header)
    title_label = Label.new()
    title_label.text = "TRACK BUILDER  /  3D"
    title_label.position = header.position+Vector2(s.x*0.035,s.y*0.008)
    title_label.size = Vector2(header.size.x*0.9,s.y*0.035)
    title_label.add_theme_font_override("font",STYLE.BOLD)
    title_label.add_theme_font_size_override("font_size",int(26.0*ui_unit))
    title_label.add_theme_color_override("font_color",STYLE.WHITE)
    title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(title_label)
    status_label = Label.new()
    status_label.position = header.position+Vector2(s.x*0.035,s.y*0.046)
    status_label.size = Vector2(header.size.x*0.92,s.y*0.036)
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.add_theme_font_size_override("font_size",int(16.0*ui_unit))
    status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(status_label)
    hint_label = Label.new()
    hint_label.text = "TAP THE GRASS TO PLACE ROAD\nTAP NEXT TO AN END TO EXTEND IT\nDRAG TO LAY A WHOLE STRIP"
    hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint_label.position = Vector2(s.x*0.08,s.y*0.40)
    hint_label.size = Vector2(s.x*0.84,s.y*0.12)
    hint_label.add_theme_font_override("font",STYLE.BOLD)
    hint_label.add_theme_font_size_override("font_size",int(22.0*ui_unit))
    hint_label.add_theme_color_override("font_color",Color(1,1,1,0.85))
    hint_label.add_theme_color_override("font_outline_color",Color(0,0,0,0.8))
    hint_label.add_theme_constant_override("outline_size",int(6.0*ui_unit))
    hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(hint_label)
    var rows: Array = [
        [["DRAW","_set_draw"],["ERASE","_set_erase"],["↶ UNDO","_undo"],["CLEAR","_clear"]],
        [["GENERATE","_generate"],["SAVE","_save"],["DRIVE","_drive"],["BACK","_back"]]]
    for r in range(rows.size()):
        var row: Array = rows[r]
        var gap: float = s.x*0.018
        var bw: float = (s.x*0.956-gap*float(row.size()-1))/float(row.size())
        for k in range(row.size()):
            var item: Array = row[k]
            var button := Button.new()
            button.text = str(item[0])
            button.position = Vector2(s.x*0.022+float(k)*(bw+gap),s.y*(0.815+0.088*float(r)))
            button.size = Vector2(bw,s.y*0.072)
            button.add_theme_font_size_override("font_size",int(19.0*ui_unit))
            button.pressed.connect(Callable(self,str(item[1])))
            STYLE.style_button(button,ui_unit)
            root.add_child(button)
            buttons[str(item[0])] = button
    map_rect = Rect2(s.x*0.0,s.y*0.105,s.x,s.y*0.70)
    _refresh_mode_buttons()

func _refresh_mode_buttons() -> void:
    STYLE.style_button(buttons["DRAW"],ui_unit,mode == "draw")
    STYLE.style_button(buttons["ERASE"],ui_unit,mode == "erase")
    STYLE.style_button(buttons["DRIVE"],ui_unit,loop_ok)

func _on_resize() -> void:
    _fit_camera()

func _fit_camera() -> void:
    var s: Vector2 = get_viewport().get_visible_rect().size
    if map_rect.size == Vector2.ZERO:
        map_rect = Rect2(0,s.y*0.105,s.x,s.y*0.70)
    var size: Vector2 = grid.size_metres()+Vector2(24,24)
    var tilt: float = deg_to_rad(TILT_DEG)
    var need_h: float = size.y*sin(tilt)*s.y/map_rect.size.y
    var need_w: float = size.x*s.y/map_rect.size.x
    camera.size = maxf(need_h,need_w)
    var distance: float = 1500.0
    camera.position = Vector3(0.0,distance*sin(tilt),distance*cos(tilt))
    camera.look_at(Vector3.ZERO,Vector3.UP)
    # Negative v_offset lifts the content so the grid centres in the map area.
    camera.v_offset = (map_rect.get_center().y-s.y*0.5)/s.y*camera.size

# ------------------------------------------------------------------ input

func _pick(screen: Vector2) -> Vector2i:
    var origin: Vector3 = camera.project_ray_origin(screen)
    var dir: Vector3 = camera.project_ray_normal(screen)
    if absf(dir.y) < 0.0001:
        return Vector2i(-1,-1)
    var t: float = -origin.y/dir.y
    var hit: Vector3 = origin+dir*t
    return grid.cell_at(Vector2(hit.x,hit.z))

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch: InputEventScreenTouch = event
        if touch.pressed and stroke_pointer == -1 and map_rect.has_point(touch.position):
            stroke_pointer = touch.index
            begin_stroke(_pick(touch.position))
        elif not touch.pressed and touch.index == stroke_pointer:
            stroke_pointer = -1
            end_stroke()
    elif event is InputEventScreenDrag:
        var drag: InputEventScreenDrag = event
        if drag.index == stroke_pointer:
            move_stroke(_pick(drag.position))
    elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
        var mb: InputEventMouseButton = event
        if mb.button_index != MOUSE_BUTTON_LEFT:
            return
        if mb.pressed and map_rect.has_point(mb.position):
            begin_stroke(_pick(mb.position))
        elif not mb.pressed and stroke_active:
            end_stroke()
    elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
        if stroke_active and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
            move_stroke(_pick((event as InputEventMouseMotion).position))
    elif event.is_action_pressed("ui_cancel"):
        _back()

## Public for tests: start a touch on a tile.
func begin_stroke(c: Vector2i) -> void:
    if not grid.in_bounds(c):
        return
    _push_undo()
    stroke_active = true
    stroke_changed = false
    stroke_last = c
    if mode == "erase":
        stroke_changed = grid.erase(c)
        _flash(c,true)
    elif not grid.is_road(c):
        grid.add_tile(c)
        # Tap next to a road end: extend it (and close the loop when the
        # new tile touches both ends).
        for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
            var n: Vector2i = c+d
            if grid.is_road(n) and grid.degree(n) < 2 and grid.degree(c) < 2:
                grid.link(c,n)
        stroke_changed = true
        _flash(c,true)
    else:
        _flash(c,true)
    dirty = true

func move_stroke(c: Vector2i) -> void:
    if not stroke_active or not grid.in_bounds(c) or c == stroke_last:
        return
    # Walk 4-connected so fast swipes do not skip tiles.
    var guard: int = 0
    while stroke_last != c and guard < 64:
        guard += 1
        var d: Vector2i = c-stroke_last
        var step := Vector2i(signi(d.x),0) if absi(d.x) >= absi(d.y) else Vector2i(0,signi(d.y))
        var next: Vector2i = stroke_last+step
        if mode == "erase":
            if grid.erase(next):
                stroke_changed = true
            stroke_last = next
            _flash(next,true)
            continue
        var result: String = grid.link(stroke_last,next)
        if result == "ok" or result == "linked":
            stroke_changed = stroke_changed or result == "ok"
            stroke_last = next
            _flash(next,true)
        else:
            _flash(next,false)
            _status("A TILE JOINS ONLY TWO NEIGHBOURS • ONE LOOP, NO CROSSINGS",false)
            if OS.has_feature("mobile"):
                Input.vibrate_handheld(40,0.4)
            break
    dirty = true

func end_stroke() -> void:
    stroke_active = false
    if not stroke_changed and not undo_stack.is_empty():
        undo_stack.pop_back()
    _save_draft()
    _rebuild()

func _flash(c: Vector2i, ok: bool) -> void:
    var w: Vector2 = grid.world_of(c)
    highlight.position = Vector3(w.x,0.2,w.y)
    highlight_mat.albedo_color = Color(STYLE.PINK.r,STYLE.PINK.g,STYLE.PINK.b,0.32) if ok else Color(1.0,0.12,0.10,0.55)
    flash_time = 0.6

# ---------------------------------------------------------------- actions

func _push_undo() -> void:
    undo_stack.append(grid.snapshot())
    if undo_stack.size() > 64:
        undo_stack.pop_front()

func _set_draw() -> void:
    mode = "draw"
    _refresh_mode_buttons()

func _set_erase() -> void:
    mode = "erase"
    _refresh_mode_buttons()

func _undo() -> void:
    if undo_stack.is_empty():
        _status("NOTHING TO UNDO",false)
        return
    grid.restore(undo_stack.pop_back())
    _save_draft()
    _rebuild()

func _clear() -> void:
    if grid.tile_count() == 0:
        return
    _push_undo()
    grid.clear()
    _save_draft()
    _rebuild()

func _generate() -> void:
    _push_undo()
    seed_counter += 1
    var seed: int = int(Time.get_unix_time_from_system())+seed_counter*7919
    if not grid.generate(seed,rng_target(seed)):
        _status("GENERATION FAILED • TRY AGAIN",false)
        return
    _save_draft()
    _rebuild()

static func rng_target(seed: int) -> int:
    return 20+absi(seed)%9

func _save() -> bool:
    if not loop_ok:
        _status("CLOSE ONE VALID LOOP BEFORE SAVING",false)
        return false
    var stamp: Dictionary = Time.get_datetime_dict_from_system()
    var title: String = "BUILT %02d-%02d %02d:%02d" % [stamp["day"],stamp["month"],stamp["hour"],stamp["minute"]]
    var slug: String = "built_%04d%02d%02d_%02d%02d%02d" % [stamp["year"],stamp["month"],stamp["day"],
        stamp["hour"],stamp["minute"],stamp["second"]]
    var path: String = "user://nitro_track_"+slug+".json"
    if not _write_track(path,title,slug):
        return false
    var recent := FileAccess.open(LAST_SAVED,FileAccess.WRITE)
    if recent != null:
        recent.store_string(path)
        recent.close()
    _status("SAVED • "+title+" • ALSO EDITABLE IN EDIT TRACK",true)
    return true

func _write_track(path: String, title: String, id: String) -> bool:
    var data: Dictionary = grid.to_track_data(title,id)
    var compiled: Dictionary = DNA.compile(data)
    if not bool(compiled.get("ok",false)):
        _status("INVALID: "+str((compiled.get("errors",PackedStringArray()) as PackedStringArray)[0]),false)
        return false
    var file := FileAccess.open(path,FileAccess.WRITE)
    if file == null:
        _status("STORAGE UNAVAILABLE",false)
        return false
    file.store_string(JSON.stringify(data,"  "))
    file.close()
    return bool(DNA.read_track(path).get("ok",false))

func _drive() -> void:
    if not loop_ok:
        _status("CLOSE ONE VALID LOOP TO DRIVE",false)
        return
    if not _write_track(BUILT,"MY BUILT CIRCUIT","player_built_track"):
        return
    ProjectSettings.set_setting("nitro/selected_track",BUILT)
    get_tree().change_scene_to_file("res://scenes/race.tscn")

func _back() -> void:
    get_tree().change_scene_to_file("res://scenes/boot.tscn")

# ------------------------------------------------------------ persistence

func _save_draft() -> void:
    var pairs: Array = []
    var tiles: Array = []
    for c in grid.links.keys():
        tiles.append([c.x,c.y])
        for n in grid.links[c]:
            if c < n:
                pairs.append([c.x,c.y,n.x,n.y])
    var file := FileAccess.open(DRAFT,FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify({"version":1,"cols":grid.cols,"rows":grid.rows,
            "tiles":tiles,"links":pairs}))
        file.close()

func _load_draft() -> void:
    if not FileAccess.file_exists(DRAFT):
        return
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DRAFT))
    if not (raw is Dictionary) or int(raw.get("cols",0)) != grid.cols or int(raw.get("rows",0)) != grid.rows:
        return
    for t in raw.get("tiles",[]):
        grid.add_tile(Vector2i(int(t[0]),int(t[1])))
    for l in raw.get("links",[]):
        grid.link(Vector2i(int(l[0]),int(l[1])),Vector2i(int(l[2]),int(l[3])))

# ---------------------------------------------------------------- preview

func _process(delta: float) -> void:
    since_rebuild += delta
    if dirty and stroke_active and since_rebuild >= REBUILD_INTERVAL:
        _rebuild()
    if flash_time > 0.0:
        flash_time = maxf(flash_time-delta,0.0)
        var c: Color = highlight_mat.albedo_color
        c.a = c.a*clampf(flash_time/0.6,0.0,1.0)+0.0
        highlight_mat.albedo_color = c
    var pulse: float = 1.0+0.12*sin(Time.get_ticks_msec()*0.006)
    for m in marker_root.get_children():
        (m as Node3D).scale = Vector3(pulse,1.0,pulse)

func _rebuild() -> void:
    dirty = false
    since_rebuild = 0.0
    for child in road_root.get_children():
        road_root.remove_child(child)
        child.queue_free()
    for child in marker_root.get_children():
        marker_root.remove_child(child)
        child.queue_free()
    var parts: Array = grid.components()
    var index: int = 0
    for part in parts:
        var order: Array[Vector2i] = []
        for c in part["cells"]:
            order.append(c)
        var closed: bool = bool(part["closed"])
        var piece: NitroDriftTrack = TRACK.new()
        piece.name = "Road piece %d" % index
        piece.build_from_samples(grid.preview_samples(order,closed),GRID.WIDTH_M*0.5,closed,
            "builder_%d_%d" % [index,order.size()],false)
        road_root.add_child(piece)
        index += 1
    for c in grid.open_ends():
        var ring := MeshInstance3D.new()
        var torus := TorusMesh.new()
        torus.inner_radius = 9.0
        torus.outer_radius = 11.0
        torus.rings = 32
        ring.mesh = torus
        var mat := StandardMaterial3D.new()
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mat.albedo_color = STYLE.PINK
        ring.material_override = mat
        var w: Vector2 = grid.world_of(c)
        ring.position = Vector3(w.x,0.6,w.y)
        marker_root.add_child(ring)
    _update_status(parts)

func _update_status(parts: Array) -> void:
    loop_ok = false
    loop_length = 0.0
    hint_label.visible = grid.tile_count() == 0
    if grid.tile_count() == 0:
        _status("EMPTY PARK • TAP, DRAG OR GENERATE",true)
    elif parts.size() > 1:
        _status("%d PIECES • JOIN THEM INTO ONE LOOP" % parts.size(),false)
    elif not bool(parts[0]["closed"]):
        _status("%d TILES • CONNECT THE TWO GLOWING ENDS TO CLOSE THE LOOP" % grid.tile_count(),false)
    else:
        var check: Dictionary = grid.validate()
        if bool(check.get("ok",false)):
            loop_ok = true
            loop_length = float(check["length_metres"])
            _status("LOOP CLOSED • %d m • %d TILES • READY TO DRIVE" % [int(loop_length),grid.tile_count()],true)
        else:
            _status("LOOP INVALID: "+str((check["errors"] as PackedStringArray)[0]),false)
    _refresh_mode_buttons()

func _status(text: String, ok: bool) -> void:
    if status_label == null:
        return
    status_label.text = text
    status_label.add_theme_color_override("font_color",Color(0.55,0.95,0.77) if ok else Color(1.0,0.50,0.62))
