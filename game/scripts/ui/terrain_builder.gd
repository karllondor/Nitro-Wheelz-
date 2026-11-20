extends Node3D
## Nitro Wheelz TERRAIN-FIRST TRACK BUILDER (v0.1.25).
##
##   1. choose a COUNTRY (Japan / Poland / Ireland)
##   2. choose a LANDSCAPE (its archetypes) and the event (practice/club/pro)
##   3. GENERATE TERRAIN (again = a new landscape), look around (drag to
##      orbit, pinch to zoom, two fingers to pan / twist, VIEW angles)
##   4. DRAW ROAD on the tiles: green = on grade, amber = cut / fill / walls /
##      bridge, red = not buildable (with the reason)
##   5. the terrain adapts automatically around the road (cuts, fills,
##      retaining walls, bridges, cliff walls; only near the road)
##   6. DRIVE: the race loads the same saved world + road.
##
## Closed circuits (LOOP, CLOSE LOOP auto-connects the ends over buildable
## tiles) and open point-to-point routes (ROUTE). UNDO / REDO cover every
## road edit; the generated terrain itself is deterministic per seed.
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const WORLD = preload("res://scripts/world/terrain/terrain_world.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const PROFILE = preload("res://scripts/world/terrain/road_profile.gd")
const GRID = preload("res://scripts/world/track_grid.gd")
const TRACK = preload("res://scripts/world/drift_track.gd")
const DNA = preload("res://scripts/world/track_dna.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")
const DRAFT: String = "user://nitro_terrain_builder_draft.json"
const DRIVE_PATH: String = "user://nitro_track_terrain_drive.json"
const REBUILD_INTERVAL: float = 0.30
const VIEWS: Array[String] = ["3D","TOP","LOW"]
const VIEW_PITCH: Dictionary = {"3D":40.0,"TOP":82.0,"LOW":22.0}
const DIST_MIN: float = 90.0
const DIST_MAX: float = 1900.0

var stage: String = "setup"
var country: String = "japan"
var archetype: String = "jp_sakura"
var terrain_seed: int = 1
var event_mode: String = "club"
var topology: String = "loop"          # loop | route
var route_start: Vector2i = Vector2i(-1,-1)
var generated_key: String = ""

var world: NitroTerrainWorld
var grid: NitroTrackGrid
var build_map: Dictionary = {}
var road_root: Node3D
var overlay_root: Node3D
var highlight: MeshInstance3D
var highlight_mat: StandardMaterial3D
var flash_time: float = 0.0
var camera: Camera3D

var mode: String = "draw"
var stroke_active: bool = false
var stroke_pointer: int = -1
var stroke_last: Vector2i = Vector2i(-1,-1)
var stroke_changed: bool = false
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var dirty: bool = false
var since_rebuild: float = 99.0
var adapt_pending: bool = false
var track_ok: bool = false
var last_eval: Dictionary = {}
var last_data: Dictionary = {}
var last_adapt: Dictionary = {}

# camera orbit
var cam_target: Vector3 = Vector3.ZERO
var cam_yaw: float = 0.0
var cam_pitch: float = 52.0
var cam_dist: float = 1150.0
var goal_target: Vector3 = Vector3.ZERO
var goal_dist: float = 1150.0
var goal_pitch: float = 52.0
var goal_yaw: float = 0.0
var view_index: int = 0
var touches: Dictionary = {}
var gesture_active: bool = false
var g_start_dist: float = 1.0
var g_start_angle: float = 0.0
var g_start_cam_dist: float = 1000.0
var g_start_yaw: float = 0.0
var g_anchor: Vector3 = Vector3.ZERO
var orbit_pointer: int = -1
var orbit_last: Vector2 = Vector2.ZERO

# ui
var ui_unit: float = 1.0
var ui_root: Control
var header_rect: Rect2 = Rect2()
var map_rect: Rect2 = Rect2()
var title_label: Label
var status_label: Label
var desc_label: Label
var setup_box: Control
var build_box: Control
var buttons: Dictionary = {}
var _last_fog: float = -1.0
var pending_panel: Panel
var pending_label: Label
var dim_rect: ColorRect
# Camera line-of-sight cache (v0.1.27): effective pitch that keeps the
# building area visible over mountain walls.
var _cam_key: String = ""
var view_pitch: float = 40.0

func _ready() -> void:
    STYLE.ensure_settings()
    grid = TT.new_grid()
    _build_scene_nodes()
    var edit_path: String = str(ProjectSettings.get_setting("nitro/terrain_edit_track",""))
    ProjectSettings.set_setting("nitro/terrain_edit_track","")
    var loaded: bool = false
    if edit_path != "":
        loaded = load_track_file(edit_path)
    if not loaded:
        _load_draft()
    _build_ui()
    generate_terrain(false)
    if stage == "build":
        _enter_build()
    else:
        _enter_setup()
    get_viewport().size_changed.connect(_on_resize)

# ------------------------------------------------------------------ scene

func _build_scene_nodes() -> void:
    road_root = Node3D.new()
    road_root.name = "Road preview"
    add_child(road_root)
    overlay_root = Node3D.new()
    overlay_root.name = "Buildability overlay"
    add_child(overlay_root)
    highlight = MeshInstance3D.new()
    highlight.name = "Touched tile"
    var quad := PlaneMesh.new()
    quad.size = Vector2(GRID.CELL_M,GRID.CELL_M)*0.94
    highlight.mesh = quad
    highlight_mat = StandardMaterial3D.new()
    highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    highlight_mat.no_depth_test = true
    highlight_mat.albedo_color = Color(1,0.16,0.56,0.0)
    highlight.material_override = highlight_mat
    add_child(highlight)
    camera = Camera3D.new()
    camera.name = "Builder camera"
    camera.fov = 50.0
    camera.near = 1.0
    camera.far = 9000.0
    add_child(camera)
    camera.current = true

func descriptor() -> Dictionary:
    return CAT.descriptor(archetype,terrain_seed,-1,event_mode)

## (Re)generate the landscape for the current selection. new_seed = true
## rolls a new terrain seed ("NEW LANDSCAPE").
func generate_terrain(new_seed: bool = true) -> void:
    if new_seed:
        terrain_seed = (terrain_seed*1103515245+12345+int(Time.get_ticks_usec()%9973)) % 999983
        if terrain_seed <= 0:
            terrain_seed += 1
    if world != null:
        remove_child(world)
        world.queue_free()
    world = WORLD.new()
    world.name = "Terrain world"
    world.setup(descriptor())
    world.field.bake()
    add_child(world)
    world.build()
    world.set_fog_scale(0.0)
    _last_fog = -1.0
    build_map = world.field.build_map()
    generated_key = "%s/%d" % [archetype,terrain_seed]
    _rebuild_overlay()
    dirty = true
    adapt_pending = true
    _rebuild_preview()
    _adapt_now()
    if title_label != null:
        _refresh_titles()

func _rebuild_overlay() -> void:
    for child in overlay_root.get_children():
        overlay_root.remove_child(child)
        child.queue_free()
    # Buildability squares: painted by the terrain shader, so they always
    # lie ON the ground (v0.1.27; flat quads used to sink into slopes).
    var img := Image.create(grid.cols,grid.rows,false,Image.FORMAT_RGBA8)
    for y in range(grid.rows):
        for x in range(grid.cols):
            var st: int = int(build_map[Vector2i(x,y)]["state"])
            img.set_pixel(x,y,[Color(0.25,0.95,0.45,1.0),Color(1.0,0.72,0.12,1.0),Color(1.0,0.18,0.20,1.0)][st])
    var half0 := Vector2(grid.cols,grid.rows)*GRID.CELL_M*0.5
    world.ground_mat.set_shader_parameter("tile_tex",ImageTexture.create_from_image(img))
    world.ground_mat.set_shader_parameter("tile_origin",-half0)
    world.ground_mat.set_shader_parameter("tile_count",Vector2(grid.cols,grid.rows))
    world.ground_mat.set_shader_parameter("tile_size",GRID.CELL_M)
    _show_tiles(stage == "build")
    # Tile grid lines draped on the terrain.
    var st2 := SurfaceTool.new()
    st2.begin(Mesh.PRIMITIVE_TRIANGLES)
    var half := Vector2(grid.cols,grid.rows)*GRID.CELL_M*0.5
    for x2 in range(grid.cols+1):
        var px: float = -half.x+float(x2)*GRID.CELL_M
        _drape(st2,Vector2(px,-half.y),Vector2(px,half.y),0.9 if (x2 == 0 or x2 == grid.cols) else 0.45)
    for y2 in range(grid.rows+1):
        var pz: float = -half.y+float(y2)*GRID.CELL_M
        _drape(st2,Vector2(-half.x,pz),Vector2(half.x,pz),0.9 if (y2 == 0 or y2 == grid.rows) else 0.45)
    var lines: ArrayMesh = st2.commit()
    var lm := StandardMaterial3D.new()
    lm.vertex_color_use_as_albedo = true
    lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    lm.cull_mode = BaseMaterial3D.CULL_DISABLED
    lines.surface_set_material(0,lm)
    var ln := MeshInstance3D.new()
    ln.name = "Tile grid"
    ln.mesh = lines
    overlay_root.add_child(ln)

func _show_tiles(on: bool) -> void:
    overlay_root.visible = on
    if world != null and world.ground_mat != null:
        world.ground_mat.set_shader_parameter("tiles",1.0 if on else 0.0)

func _drape(st: SurfaceTool, a: Vector2, b: Vector2, width: float) -> void:
    var d: Vector2 = (b-a)
    var steps: int = maxi(1,int(d.length()/8.0))
    var n := Vector2(-d.y,d.x).normalized()*width
    var col := Color(1,1,1,0.30) if width < 0.8 else Color(STYLE.PINK.r,STYLE.PINK.g,STYLE.PINK.b,0.8)
    for i in range(steps):
        var p0: Vector2 = a+d*float(i)/float(steps)
        var p1: Vector2 = a+d*float(i+1)/float(steps)
        var y0: float = world.height_at(p0.x,p0.y)+0.7
        var y1: float = world.height_at(p1.x,p1.y)+0.7
        var q: Array = [Vector3(p0.x-n.x,y0,p0.y-n.y),Vector3(p0.x+n.x,y0,p0.y+n.y),
            Vector3(p1.x-n.x,y1,p1.y-n.y),Vector3(p1.x+n.x,y1,p1.y+n.y)]
        for k in [0,1,2,2,1,3]:
            st.set_color(col)
            st.add_vertex(q[k])

# --------------------------------------------------------------------- ui

func _build_ui() -> void:
    var s: Vector2 = get_viewport().get_visible_rect().size
    ui_unit = clampf(minf(s.x,s.y)/700.0,0.85,1.8)
    var layer := CanvasLayer.new()
    layer.layer = 8
    add_child(layer)
    ui_root = Control.new()
    ui_root.name = "Terrain builder UI"
    ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui_root.theme = STYLE.screen_theme(ui_unit)
    layer.add_child(ui_root)
    ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var safe_top: float = maxf(0.0,float(DisplayServer.get_display_safe_area().position.y)) if DisplayServer.get_name() != "headless" else 0.0
    header_rect = Rect2(s.x*0.02,s.y*0.010+safe_top,s.x*0.96,maxf(s.y*0.062,66.0*ui_unit))
    var header := Panel.new()
    header.name = "Header"
    header.position = header_rect.position
    header.size = header_rect.size
    var hb: StyleBoxFlat = STYLE.modal_box(ui_unit)
    hb.bg_color.a = 0.74
    header.add_theme_stylebox_override("panel",hb)
    ui_root.add_child(header)
    var bw: float = header_rect.size.y*1.2
    _button(ui_root,"◀","_back",Rect2(header_rect.position+Vector2(header_rect.size.y*0.12,header_rect.size.y*0.12),
        Vector2(bw,header_rect.size.y*0.76)),"BACK")
    title_label = Label.new()
    title_label.name = "Title"
    title_label.position = header_rect.position+Vector2(bw+header_rect.size.y*0.3,header_rect.size.y*0.05)
    title_label.size = Vector2(header_rect.size.x-bw*2.6,header_rect.size.y*0.48)
    title_label.clip_text = true
    title_label.add_theme_font_override("font",STYLE.BOLD)
    title_label.add_theme_font_size_override("font_size",int(16.0*ui_unit))
    title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui_root.add_child(title_label)
    status_label = Label.new()
    status_label.name = "Status"
    status_label.position = header_rect.position+Vector2(bw+header_rect.size.y*0.3,header_rect.size.y*0.50)
    status_label.size = Vector2(header_rect.size.x-bw*2.6,header_rect.size.y*0.46)
    status_label.clip_text = true
    status_label.add_theme_font_size_override("font_size",int(12.5*ui_unit))
    status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui_root.add_child(status_label)
    _button(ui_root,"FIT","_fit",Rect2(Vector2(header_rect.end.x-bw-header_rect.size.y*0.12,header_rect.position.y+header_rect.size.y*0.12),
        Vector2(bw,header_rect.size.y*0.76)),"FIT")
    var safe_bottom: float = 0.0
    if DisplayServer.get_name() != "headless":
        var sa: Rect2i = DisplayServer.get_display_safe_area()
        if sa.size.y > 0:
            safe_bottom = clampf(s.y-float(sa.end.y),0.0,s.y*0.05)
    var row_h: float = s.y*0.064
    var gap: float = s.y*0.010
    var left: float = s.x*0.02
    var width: float = s.x*0.96
    # SETUP sheet: country / landscape / event / actions.
    setup_box = Control.new()
    setup_box.name = "Setup"
    setup_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui_root.add_child(setup_box)
    var y4: float = s.y-safe_bottom-gap-row_h
    var y3: float = y4-gap-row_h
    var y2: float = y3-gap-row_h
    var y1: float = y2-gap-row_h
    _row(setup_box,[["JAPAN","_pick_country","japan"],["POLAND","_pick_country","poland"],["IRELAND","_pick_country","ireland"]],
        y1,row_h,left,width,"country_")
    _landscape_row(y2,row_h,left,width)
    _row(setup_box,[["PRACTICE","_pick_event","practice"],["CLUB EVENT","_pick_event","club"],["PRO EVENT","_pick_event","pro"]],
        y3,row_h,left,width,"event_")
    _row(setup_box,[["GENERATE TERRAIN","_generate_pressed",null],["VIEW","_cycle_view",null],["DRAW ROAD ▶","_enter_build",null]],
        y4,row_h,left,width,"")
    desc_label = Label.new()
    desc_label.name = "Landscape description"
    desc_label.position = Vector2(left,y1-row_h*1.25)
    desc_label.size = Vector2(width,row_h*1.15)
    desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    desc_label.add_theme_font_size_override("font_size",int(14.0*ui_unit))
    desc_label.add_theme_color_override("font_color",STYLE.WHITE)
    desc_label.add_theme_color_override("font_outline_color",Color(0,0,0,0.85))
    desc_label.add_theme_constant_override("outline_size",int(5.0*ui_unit))
    desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    setup_box.add_child(desc_label)
    # Pending-generation state (v0.1.27): the old landscape is dimmed and a
    # clear card says the new selection is not generated yet.
    dim_rect = ColorRect.new()
    dim_rect.name = "Pending dim"
    dim_rect.color = Color(0.0,0.0,0.0,0.45)
    dim_rect.position = Vector2(0.0,header_rect.end.y)
    dim_rect.size = Vector2(s.x,y1-row_h*1.3-header_rect.end.y)
    dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    dim_rect.visible = false
    ui_root.add_child(dim_rect)
    ui_root.move_child(dim_rect,0)
    pending_panel = Panel.new()
    pending_panel.name = "Pending generation"
    var pb: StyleBoxFlat = STYLE.modal_box(ui_unit)
    pending_panel.add_theme_stylebox_override("panel",pb)
    pending_panel.size = Vector2(s.x*0.80,s.y*0.13)
    pending_panel.position = Vector2(s.x*0.10,header_rect.end.y+(y1-row_h*1.3-header_rect.end.y)*0.5-s.y*0.065)
    pending_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pending_panel.visible = false
    ui_root.add_child(pending_panel)
    pending_label = Label.new()
    pending_label.name = "Pending text"
    pending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pending_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    pending_label.size = pending_panel.size
    pending_label.add_theme_font_override("font",STYLE.BOLD)
    pending_label.add_theme_font_size_override("font_size",int(17.0*ui_unit))
    pending_label.add_theme_color_override("font_color",STYLE.WHITE)
    pending_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pending_panel.add_child(pending_label)
    # BUILD bar: two rows.
    build_box = Control.new()
    build_box.name = "Build"
    build_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui_root.add_child(build_box)
    _row(build_box,[["DRAW","_set_draw",null],["ERASE","_set_erase",null],["↶ UNDO","_undo",null],["↷ REDO","_redo",null],["CLEAR","_clear",null]],
        y3,row_h,left,width,"")
    _row(build_box,[["LOOP","_toggle_topology",null],["CLOSE","_close_loop",null],["AUTO","_auto",null],["VIEW","_cycle_view",null],
        ["SAVE","_save",null],["DRIVE","_drive",null]],y4,row_h,left,width,"b_")
    map_rect = Rect2(0.0,header_rect.end.y+s.y*0.006,s.x,y1-row_h*1.3-header_rect.end.y)
    _refresh_titles()

func _row(parent: Control, items: Array, y: float, h: float, left: float, width: float, prefix: String) -> void:
    var gap: float = width*0.014
    var bw: float = (width-gap*float(items.size()-1))/float(items.size())
    for k in range(items.size()):
        var it: Array = items[k]
        var key: String = prefix+(str(it[2]) if it[2] != null else str(it[0]))
        var b: Button = _button(parent,str(it[0]),str(it[1]),Rect2(left+float(k)*(bw+gap),y,bw,h),key)
        if it[2] != null:
            b.pressed.disconnect(Callable(self,str(it[1])))
            b.pressed.connect(Callable(self,str(it[1])).bind(str(it[2])))

func _landscape_row(y: float, h: float, left: float, width: float) -> void:
    for key in buttons.keys():
        if str(key).begins_with("land_"):
            var old: Button = buttons[key]
            old.queue_free()
            buttons.erase(key)
    var items: Array = []
    for a in CAT.of_country(country):
        items.append([str(CAT.info(a)["short"]),"_pick_landscape",a])
    _row(setup_box,items,y,h,left,width,"land_")

func _button(parent: Control, text: String, method: String, rect: Rect2, key: String) -> Button:
    var b := Button.new()
    b.name = key
    b.text = text
    b.position = rect.position
    b.size = rect.size
    b.clip_text = true
    b.add_theme_font_size_override("font_size",int(clampf(rect.size.y*0.30,12.0*ui_unit,19.0*ui_unit)))
    b.pressed.connect(Callable(self,method))
    STYLE.style_button(b,ui_unit)
    parent.add_child(b)
    buttons[key] = b
    return b

## The selection differs from the landscape on screen (not generated yet).
func is_pending() -> bool:
    return world == null or str(world.desc.get("archetype","")) != archetype

func _refresh_titles() -> void:
    if title_label == null:
        return
    var inf: Dictionary = CAT.info(archetype)
    var pending: bool = is_pending()
    if pending and world != null:
        var shown: Dictionary = CAT.info(str(world.desc.get("archetype","")))
        title_label.text = "%s SELECTED • NOT GENERATED (SHOWING %s)" % [str(inf["name"]),str(shown["short"])]
    else:
        title_label.text = "%s • %s • SEED %d" % [str(CAT.COUNTRY_NAMES[country]),str(inf["name"]),terrain_seed]
    if pending_panel != null:
        pending_panel.visible = pending and stage == "setup"
        dim_rect.visible = pending and stage == "setup"
        pending_label.text = "%s • %s\nNOT GENERATED YET\nTAP  GENERATE TERRAIN" % [str(CAT.COUNTRY_NAMES[country]),str(inf["name"])]
    if buttons.has("DRAW ROAD ▶"):
        (buttons["DRAW ROAD ▶"] as Button).disabled = pending
    desc_label.text = "%s\nROAD GRADE %s • EVENT %s" % [str(inf["desc"]),str(inf["grade_hint"]),event_mode.to_upper()]
    for c in CAT.COUNTRIES:
        if buttons.has("country_"+c):
            STYLE.style_button(buttons["country_"+c],ui_unit,c == country)
    for a in CAT.ORDER:
        if buttons.has("land_"+a):
            STYLE.style_button(buttons["land_"+a],ui_unit,a == archetype)
    for e in CAT.EVENT_MODES:
        if buttons.has("event_"+e):
            STYLE.style_button(buttons["event_"+e],ui_unit,e == event_mode)
    var gen: Button = buttons.get("GENERATE TERRAIN",null)
    if gen != null:
        gen.text = "NEW LANDSCAPE ↻" if generated_key == "%s/%d" % [archetype,terrain_seed] else "GENERATE TERRAIN"
        STYLE.style_button(gen,ui_unit,is_pending())
    if buttons.has("DRAW"):
        STYLE.style_button(buttons["DRAW"],ui_unit,mode == "draw")
        STYLE.style_button(buttons["ERASE"],ui_unit,mode == "erase")
        (buttons["b_LOOP"] as Button).text = "LOOP" if topology == "loop" else "ROUTE"
        STYLE.style_button(buttons["b_LOOP"],ui_unit,true)
        (buttons["b_CLOSE"] as Button).disabled = topology != "loop"
        STYLE.style_button(buttons["b_DRIVE"],ui_unit,track_ok)

func _status(text: String, ok: bool) -> void:
    if status_label == null:
        return
    status_label.text = text
    status_label.add_theme_color_override("font_color",Color(0.55,0.95,0.77) if ok else Color(1.0,0.62,0.45))

func _on_resize() -> void:
    for child in ui_root.get_parent().get_children():
        child.queue_free()
    buttons.clear()
    ui_root.get_parent().queue_free()
    _build_ui()
    if stage == "build":
        setup_box.visible = false
    else:
        build_box.visible = false
    _fit()

# ------------------------------------------------------------ setup stage

func _enter_setup() -> void:
    stage = "setup"
    setup_box.visible = true
    build_box.visible = false
    _show_tiles(false)
    view_index = 0
    _set_view("3D")
    _fit()
    _status("DRAG TO LOOK AROUND • PINCH TO ZOOM • GENERATE TERRAIN AGAIN FOR A NEW LANDSCAPE",true)

func _enter_build() -> void:
    if is_pending():
        _status("GENERATE THE SELECTED LANDSCAPE FIRST",false)
        return
    stage = "build"
    setup_box.visible = false
    build_box.visible = true
    _show_tiles(true)
    _set_view("TOP" if grid.tile_count() == 0 else "3D")
    _fit()
    _update_status()
    _save_draft()

func _pick_country(c: String) -> void:
    if c == country:
        return
    country = c
    var list: Array[String] = CAT.of_country(c)
    archetype = list[0]
    var s: Vector2 = get_viewport().get_visible_rect().size
    var land_y: float = (buttons["land_"+CAT.of_country("japan")[0]] as Button).position.y if buttons.has("land_jp_sakura") else 0.0
    for key in buttons.keys():
        if str(key).begins_with("land_"):
            land_y = (buttons[key] as Button).position.y
            break
    _landscape_row(land_y,s.y*0.064,s.x*0.02,s.x*0.96)
    _refresh_titles()

func _pick_landscape(a: String) -> void:
    archetype = a
    _refresh_titles()

func _pick_event(e: String) -> void:
    event_mode = e
    if world != null:
        world.desc["event_mode"] = e
        if world.scenery != null:
            world.scenery._build_venue()
    _refresh_titles()
    _save_draft()

func _generate_pressed() -> void:
    var again: bool = generated_key == "%s/%d" % [archetype,terrain_seed]
    # A different landscape keeps the road only where it is still buildable.
    generate_terrain(again)
    _drop_unbuildable_tiles()
    _refresh_titles()
    _fit()
    _save_draft()
    _status("TERRAIN %s • SEED %d • %s" % [str(CAT.info(archetype)["name"]),terrain_seed,_map_summary()],true)

func _map_summary() -> String:
    var cnt: Array = [0,0,0]
    for c in build_map.keys():
        cnt[int(build_map[c]["state"])] += 1
    return "%d GREEN / %d AMBER / %d RED TILES" % cnt

func _drop_unbuildable_tiles() -> void:
    var removed: int = 0
    for c in grid.links.keys():
        if int(build_map[c]["state"]) >= 2:
            grid.erase(c)
            removed += 1
    if removed > 0:
        dirty = true
        _rebuild_preview()
        _adapt_now()

# ------------------------------------------------------------------ camera

func _set_view(name: String) -> void:
    view_index = maxi(VIEWS.find(name),0)
    goal_pitch = float(VIEW_PITCH[name])

func _cycle_view() -> void:
    view_index = (view_index+1)%VIEWS.size()
    goal_pitch = float(VIEW_PITCH[VIEWS[view_index]])
    if VIEWS[view_index] == "LOW":
        goal_dist = minf(goal_dist,520.0)
    _status("VIEW %s • TWO FINGERS: PINCH ZOOM, DRAG PAN, TWIST ROTATE" % VIEWS[view_index],true)

func occupied_bounds() -> Rect2:
    if grid.tile_count() == 0:
        var size := Vector2(grid.cols,grid.rows)*GRID.CELL_M
        return Rect2(-size*0.5,size)
    var lo := Vector2(INF,INF)
    var hi := Vector2(-INF,-INF)
    for c in grid.links.keys():
        var w: Vector2 = grid.world_of(c)
        lo = lo.min(w)
        hi = hi.max(w)
    var m: float = GRID.CELL_M*1.2
    return Rect2(lo-Vector2(m,m),(hi-lo)+Vector2(m,m)*2.0)

func _fit() -> void:
    var b: Rect2 = occupied_bounds()
    var c: Vector2 = b.get_center()
    goal_target = Vector3(c.x,world.height_at(c.x,c.y) if world != null else 0.0,c.y)
    var s: Vector2 = get_viewport().get_visible_rect().size
    var aspect: float = s.x/maxf(s.y,1.0)
    var need: float = maxf(b.size.y,b.size.x/maxf(aspect,0.3))
    goal_dist = clampf(need*1.35/tan(deg_to_rad(camera.fov*0.5))*0.5,DIST_MIN,DIST_MAX)

func _cam_pos(pitch_deg: float) -> Vector3:
    var p: float = deg_to_rad(pitch_deg)
    var y: float = deg_to_rad(cam_yaw)
    var pos: Vector3 = cam_target+Vector3(sin(y)*cos(p),sin(p),cos(y)*cos(p))*cam_dist
    if world != null:
        pos.y = maxf(pos.y,world.height_at(pos.x,pos.z)+12.0)
    return pos

## Terrain between the camera and a ground point (sampled along the ray).
func _occluded(from: Vector3, to: Vector3) -> bool:
    var n: int = 28
    for k in range(1,n-2):
        var p: Vector3 = from.lerp(to,float(k)/float(n))
        if world.height_at(p.x,p.z) > p.y-4.0:
            return true
    return false

## v0.1.27 FIT / occlusion: the camera rises (steeper pitch) until it sees
## the target and the corners of the area around it over any mountain wall
## or snow ridge, instead of looking through the terrain.
func _clear_pitch() -> float:
    if world == null:
        return cam_pitch
    var y: float = deg_to_rad(cam_yaw)
    var fwd := Vector3(-sin(y),0.0,-cos(y))
    var right := Vector3(cos(y),0.0,-sin(y))
    var r: float = clampf(cam_dist*0.32,40.0,360.0)
    var pts: Array[Vector3] = [cam_target]
    for o in [fwd*r,-fwd*r,right*r,-right*r]:
        var q: Vector3 = cam_target+o
        pts.append(Vector3(q.x,world.height_at(q.x,q.z),q.z))
    var p: float = cam_pitch
    for _i in range(16):
        var pos: Vector3 = _cam_pos(p)
        var blocked: bool = false
        for q2 in pts:
            if _occluded(pos,q2):
                blocked = true
                break
        if not blocked or p >= 86.0:
            break
        p = minf(p+4.0,86.0)
    return p

func _apply_camera() -> void:
    var key: String = "%.1f|%.1f|%.1f|%.1f|%.2f|%.2f" % [cam_target.x,cam_target.z,cam_target.y,cam_dist,cam_pitch,cam_yaw]
    if key != _cam_key:
        _cam_key = key
        view_pitch = _clear_pitch()
    camera.position = _cam_pos(view_pitch)
    camera.near = clampf(cam_dist*0.0025,0.3,4.0)
    camera.look_at(cam_target,Vector3.UP)
    if world != null:
        # Overview without haze (it washed the whole map out); a little
        # aerial perspective only for close, low views.
        var fog: float = clampf((700.0-cam_dist)/700.0,0.0,1.0)*0.5
        if absf(fog-_last_fog) > 0.02:
            _last_fog = fog
            world.set_fog_scale(fog)
    if map_rect.size.y > 0.0:
        var s: Vector2 = get_viewport().get_visible_rect().size
        camera.v_offset = 0.0
        camera.h_offset = 0.0
        # Keep the target in the middle of the free map area.
        var shift: float = (map_rect.get_center().y-s.y*0.5)/s.y
        camera.v_offset = shift*2.0*cam_dist*tan(deg_to_rad(camera.fov*0.5))

## Ground point under a screen position (ray marched against the terrain).
func ground_hit(screen: Vector2) -> Vector3:
    var o: Vector3 = camera.project_ray_origin(screen)
    var d: Vector3 = camera.project_ray_normal(screen)
    var t: float = 0.0
    var prev_t: float = 0.0
    var step: float = 6.0
    while t < 7000.0:
        var p: Vector3 = o+d*t
        if p.y <= world.height_at(p.x,p.z):
            var lo: float = prev_t
            var hi: float = t
            for _i in range(16):
                var mid: float = (lo+hi)*0.5
                var q: Vector3 = o+d*mid
                if q.y <= world.height_at(q.x,q.z):
                    hi = mid
                else:
                    lo = mid
            return o+d*hi
        prev_t = t
        step = clampf((p.y-world.height_at(p.x,p.z))*0.5,2.0,60.0)
        t += step
    return Vector3(o.x,0.0,o.z)

func pick(screen: Vector2) -> Vector2i:
    var g: Vector3 = ground_hit(screen)
    return grid.cell_at(Vector2(g.x,g.z))

# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var t: InputEventScreenTouch = event
        if t.pressed and map_rect.has_point(t.position):
            touches[t.index] = t.position
        else:
            touches.erase(t.index)
        if t.pressed and touches.size() == 2:
            _begin_gesture()
        elif t.pressed and touches.size() == 1 and not gesture_active and map_rect.has_point(t.position):
            if stage == "build":
                stroke_pointer = t.index
                begin_stroke(pick(t.position))
            else:
                orbit_pointer = t.index
                orbit_last = t.position
        elif not t.pressed:
            if t.index == stroke_pointer:
                stroke_pointer = -1
                end_stroke()
            if t.index == orbit_pointer:
                orbit_pointer = -1
        if gesture_active and touches.size() < 2:
            gesture_active = false
    elif event is InputEventScreenDrag:
        var dr: InputEventScreenDrag = event
        if touches.has(dr.index):
            touches[dr.index] = dr.position
        if gesture_active:
            _update_gesture()
        elif dr.index == stroke_pointer:
            move_stroke(pick(dr.position))
        elif dr.index == orbit_pointer:
            _orbit(dr.position-orbit_last)
            orbit_last = dr.position
    elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
        var mb: InputEventMouseButton = event
        if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
            zoom_at(mb.position,goal_dist*(0.85 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.18))
            return
        if mb.button_index == MOUSE_BUTTON_RIGHT:
            orbit_pointer = 99 if mb.pressed else -1
            orbit_last = mb.position
            return
        if mb.button_index != MOUSE_BUTTON_LEFT:
            return
        if mb.pressed and map_rect.has_point(mb.position):
            if stage == "build":
                begin_stroke(pick(mb.position))
            else:
                orbit_pointer = 98
                orbit_last = mb.position
        elif not mb.pressed:
            if stroke_active:
                end_stroke()
            if orbit_pointer == 98:
                orbit_pointer = -1
    elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
        var mm: InputEventMouseMotion = event
        if stroke_active and mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
            move_stroke(pick(mm.position))
        elif orbit_pointer >= 98:
            _orbit(mm.position-orbit_last)
            orbit_last = mm.position
    elif event.is_action_pressed("ui_cancel"):
        _back()

func _orbit(delta: Vector2) -> void:
    goal_yaw -= delta.x*0.25
    goal_pitch = clampf(goal_pitch+delta.y*0.18,14.0,86.0)
    cam_yaw = goal_yaw
    cam_pitch = goal_pitch
    _apply_camera()

## Two fingers: cancel a half-drawn stroke, then pinch = zoom, midpoint =
## pan (anchored to the ground under it), twist = rotate the view.
func _begin_gesture() -> void:
    if stroke_active:
        stroke_active = false
        stroke_pointer = -1
        if stroke_changed and not undo_stack.is_empty():
            _restore(undo_stack.pop_back())
            dirty = true
            _rebuild_preview()
        elif not undo_stack.is_empty():
            undo_stack.pop_back()
    orbit_pointer = -1
    var pts: Array = touches.values()
    gesture_active = true
    var a: Vector2 = pts[0]
    var b: Vector2 = pts[1]
    g_start_dist = maxf(a.distance_to(b),1.0)
    g_start_angle = (b-a).angle()
    g_start_cam_dist = cam_dist
    g_start_yaw = cam_yaw
    g_anchor = ground_hit((a+b)*0.5)

func _update_gesture() -> void:
    var pts: Array = touches.values()
    if pts.size() < 2:
        return
    var a: Vector2 = pts[0]
    var b: Vector2 = pts[1]
    var mid: Vector2 = (a+b)*0.5
    cam_dist = clampf(g_start_cam_dist*g_start_dist/maxf(a.distance_to(b),1.0),DIST_MIN,DIST_MAX)
    cam_yaw = g_start_yaw-rad_to_deg(wrapf((b-a).angle()-g_start_angle,-PI,PI))
    _apply_camera()
    var now: Vector3 = ground_hit(mid)
    cam_target += Vector3(g_anchor.x-now.x,0.0,g_anchor.z-now.z)
    goal_target = cam_target
    goal_dist = cam_dist
    goal_yaw = cam_yaw
    _apply_camera()

func zoom_at(screen_pos: Vector2, new_dist: float) -> void:
    var anchor: Vector3 = ground_hit(screen_pos)
    cam_dist = clampf(new_dist,DIST_MIN,DIST_MAX)
    _apply_camera()
    var now: Vector3 = ground_hit(screen_pos)
    cam_target += Vector3(anchor.x-now.x,0.0,anchor.z-now.z)
    goal_target = cam_target
    goal_dist = cam_dist
    _apply_camera()

# --------------------------------------------------------------- drawing

func _tile_state(c: Vector2i) -> Dictionary:
    return build_map.get(c,{"state":2,"reason":"OUTSIDE THE MAP"})

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
        var st: Dictionary = _tile_state(c)
        if int(st["state"]) >= 2:
            _flash(c,false)
            _status("NOT BUILDABLE: "+str(st["reason"]),false)
            stroke_last = Vector2i(-1,-1)
        else:
            grid.add_tile(c)
            if grid.tile_count() == 1:
                route_start = c
            for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
                var n: Vector2i = c+d
                if grid.is_road(n) and grid.degree(n) < 2 and grid.degree(c) < 2:
                    grid.link(c,n)
            stroke_changed = true
            _flash(c,true)
            if int(st["state"]) == 1:
                _status("AMBER: "+str(st["reason"]),false)
    else:
        _flash(c,true)
    dirty = true

func move_stroke(c: Vector2i) -> void:
    if not stroke_active or not grid.in_bounds(c) or c == stroke_last or stroke_last.x < 0:
        return
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
        var st: Dictionary = _tile_state(next)
        if int(st["state"]) >= 2 and not grid.is_road(next):
            _flash(next,false)
            _status("NOT BUILDABLE: "+str(st["reason"]),false)
            break
        var result: String = grid.link(stroke_last,next)
        if result == "ok" or result == "linked":
            stroke_changed = stroke_changed or result == "ok"
            stroke_last = next
            _flash(next,true)
            if int(st["state"]) == 1:
                _status("AMBER: "+str(st["reason"]),false)
        else:
            _flash(next,false)
            _status("A TILE JOINS ONLY TWO NEIGHBOURS • NO CROSSINGS",false)
            if OS.has_feature("mobile"):
                Input.vibrate_handheld(40,0.4)
            break
    dirty = true

func end_stroke() -> void:
    stroke_active = false
    if not stroke_changed:
        # Nothing changed (e.g. a refused red tile): keep the message.
        if not undo_stack.is_empty():
            undo_stack.pop_back()
        return
    redo_stack.clear()
    _rebuild_preview()
    _adapt_now()
    _save_draft()

func _flash(c: Vector2i, ok: bool) -> void:
    var w: Vector2 = grid.world_of(c)
    highlight.position = Vector3(w.x,world.height_at(w.x,w.y)+2.0,w.y)
    highlight_mat.albedo_color = Color(STYLE.PINK.r,STYLE.PINK.g,STYLE.PINK.b,0.35) if ok else Color(1.0,0.12,0.10,0.60)
    flash_time = 0.6

func _snapshot() -> Dictionary:
    return {"links":grid.snapshot(),"topology":topology,"route_start":route_start}

func _restore(s: Dictionary) -> void:
    grid.restore(s["links"])
    topology = str(s["topology"])
    route_start = s["route_start"]

func _push_undo() -> void:
    undo_stack.append(_snapshot())
    if undo_stack.size() > 80:
        undo_stack.pop_front()

func _set_draw() -> void:
    mode = "draw"
    _refresh_titles()

func _set_erase() -> void:
    mode = "erase"
    _refresh_titles()

func _undo() -> void:
    if undo_stack.is_empty():
        _status("NOTHING TO UNDO",false)
        return
    redo_stack.append(_snapshot())
    _restore(undo_stack.pop_back())
    _after_edit()

func _redo() -> void:
    if redo_stack.is_empty():
        _status("NOTHING TO REDO",false)
        return
    undo_stack.append(_snapshot())
    _restore(redo_stack.pop_back())
    _after_edit()

func _clear() -> void:
    if grid.tile_count() == 0:
        return
    _push_undo()
    redo_stack.clear()
    grid.clear()
    route_start = Vector2i(-1,-1)
    _after_edit()

func _after_edit() -> void:
    dirty = true
    _rebuild_preview()
    _adapt_now()
    _save_draft()

func _toggle_topology() -> void:
    _push_undo()
    topology = "route" if topology == "loop" else "loop"
    if topology == "route":
        # A closed loop becomes a route by opening it at its start tile.
        var ro: Dictionary = TT.route_order(grid)
        if bool(ro["closed"]):
            var order: Array = ro["order"]
            var a: Vector2i = order[0]
            var b: Vector2i = order[order.size()-1]
            (grid.links[a] as Array).erase(b)
            (grid.links[b] as Array).erase(a)
            route_start = a
    _after_edit()

## CLOSE LOOP: connect the two ends of the drawn road over buildable tiles.
func _close_loop() -> void:
    var ro: Dictionary = TT.route_order(grid,route_start)
    if int(ro["parts"]) != 1 or bool(ro["closed"]):
        _status("DRAW ONE OPEN ROAD FIRST" if not bool(ro.get("closed",false)) else "ALREADY A CLOSED LOOP",false)
        return
    var order: Array[Vector2i] = []
    for c in ro["order"]:
        order.append(c)
    var path: Array[Vector2i] = TT.close_path(grid,world.field,order)
    var a: Vector2i = order[order.size()-1]
    var b: Vector2i = order[0]
    var adjacent: bool = absi(a.x-b.x)+absi(a.y-b.y) == 1
    if path.is_empty() and not adjacent:
        _status("NO BUILDABLE CONNECTION BETWEEN THE ENDS",false)
        return
    _push_undo()
    redo_stack.clear()
    var prev: Vector2i = a
    for c2 in path:
        grid.link(prev,c2)
        prev = c2
    grid.link(prev,b)
    topology = "loop"
    _after_edit()
    _status("LOOP CLOSED WITH %d NEW TILES" % path.size(),true)

## AUTO: a random buildable loop / route on this terrain.
func _auto() -> void:
    _push_undo()
    redo_stack.clear()
    var seed_value: int = terrain_seed*31+int(Time.get_ticks_msec()%100000)
    var res: Dictionary = TT.generate_loop(grid,world.field,descriptor(),seed_value) if topology == "loop" \
        else TT.generate_route(grid,world.field,descriptor(),seed_value)
    if not bool(res.get("ok",false)):
        _restore(undo_stack.pop_back())
        _status("NO VALID %s FOUND ON THIS TERRAIN • TRY AGAIN" % topology.to_upper(),false)
        return
    if topology == "route":
        route_start = (res["order"] as Array)[0]
    else:
        route_start = TT.route_order(grid)["order"][0]
    _after_edit()
    _fit()

# ---------------------------------------------------------------- preview

func _process(delta: float) -> void:
    since_rebuild += delta
    var k: float = 1.0-exp(-7.0*delta)
    if not gesture_active and orbit_pointer < 0:
        var moved: bool = absf(cam_dist-goal_dist) > 0.05 or cam_target.distance_to(goal_target) > 0.05 \
            or absf(cam_pitch-goal_pitch) > 0.05 or absf(cam_yaw-goal_yaw) > 0.05
        if moved:
            cam_dist = lerpf(cam_dist,goal_dist,k)
            cam_target = cam_target.lerp(goal_target,k)
            cam_pitch = lerpf(cam_pitch,goal_pitch,k)
            cam_yaw = lerpf(cam_yaw,goal_yaw,k)
    _apply_camera()
    if dirty and stroke_active and since_rebuild >= REBUILD_INTERVAL:
        _rebuild_preview()
    if flash_time > 0.0:
        flash_time = maxf(flash_time-delta,0.0)
        var c: Color = highlight_mat.albedo_color
        c.a *= clampf(flash_time/0.6,0.0,1.0)
        highlight_mat.albedo_color = c

## Fast road preview while drawing: every piece drawn with the race road
## code on heights solved on the (undeformed) terrain.
func _rebuild_preview() -> void:
    dirty = false
    since_rebuild = 0.0
    for child in road_root.get_children():
        road_root.remove_child(child)
        child.queue_free()
    var index: int = 0
    for part in grid.components():
        var order: Array[Vector2i] = []
        for c in part["cells"]:
            order.append(c)
        var closed: bool = bool(part["closed"])
        var samples: Array[Vector2] = grid.preview_samples(order,closed)
        if samples.size() < 2:
            continue
        var hw := PackedFloat32Array()
        hw.resize(samples.size())
        hw.fill(GRID.WIDTH_M*0.5)
        var h: PackedFloat32Array = _draped_heights(samples,closed)
        var piece: NitroDriftTrack = TRACK.new()
        piece.name = "Road piece %d" % index
        piece.with_props = false
        piece.apply_region_style(descriptor())
        piece.build_from_samples(samples,GRID.WIDTH_M*0.5,closed,"terrain_preview_%d" % index,false,h)
        road_root.add_child(piece)
        index += 1

## Preview heights for road pieces the terrain is NOT adapted to yet (while
## a stroke is drawn, unjoined pieces): laid on the current ground across
## the full road width, lightly smoothed, never below it. (The graded
## profile is only used once the terrain is cut / filled for it, otherwise
## the preview sank into hills.)
func _draped_heights(samples: Array[Vector2], closed: bool) -> PackedFloat32Array:
    var n: int = samples.size()
    var raw := PackedFloat32Array()
    raw.resize(n)
    var hw: float = GRID.WIDTH_M*0.5
    for i in range(n):
        var a: Vector2 = samples[(i-1+n)%n] if (closed or i > 0) else samples[i]
        var b: Vector2 = samples[(i+1)%n] if (closed or i < n-1) else samples[i]
        var t: Vector2 = (b-a).normalized() if b != a else Vector2.RIGHT
        var nrm := Vector2(-t.y,t.x)
        var top: float = -INF
        for o in [-1.0,-0.5,0.0,0.5,1.0]:
            var q: Vector2 = samples[i]+nrm*o*hw
            top = maxf(top,world.height_at(q.x,q.y))
        raw[i] = top+0.25
    var out := PackedFloat32Array(raw)
    for i2 in range(n):
        var acc: float = 0.0
        var wsum: float = 0.0
        for d in range(-2,3):
            var j: int = i2+d
            if closed:
                j = (j+n)%n
            elif j < 0 or j >= n:
                continue
            var wgt: float = 3.0-absf(float(d))
            acc += raw[j]*wgt
            wsum += wgt
        out[i2] = maxf(acc/wsum,raw[i2])
    return out

## Full terrain adaptation for the drawn road (one connected piece): the
## saved data (with knot heights) -> Track DNA -> the race road + terrain.
func _adapt_now() -> void:
    adapt_pending = false
    track_ok = false
    last_eval = {}
    last_data = {}
    var ro: Dictionary = TT.route_order(grid,route_start)
    var order: Array[Vector2i] = []
    for c in ro.get("order",[]):
        order.append(c)
    var closed: bool = bool(ro.get("closed",false))
    if int(ro.get("parts",0)) != 1 or order.size() < 2 or (closed and topology == "route"):
        last_adapt = world.set_road([] as Array[Vector2],PackedFloat32Array(),PackedFloat32Array(),false)
        _update_status()
        return
    var data: Dictionary = TT.track_data(grid,order,closed,world.field,descriptor(),"Terrain track","terrain_check")
    var ev: Dictionary = TT.evaluate(world.field,data)
    last_eval = ev
    last_data = data
    var comp: Dictionary = ev.get("compiled",{})
    if bool(comp.get("ok",false)) and (comp["heights"] as PackedFloat32Array).size() == (comp["centerline"] as Array).size():
        last_adapt = world.set_road(comp["centerline"],comp["halfwidths"],comp["heights"],bool(comp["closed"]))
        # Replace the quick preview by the exact race road.
        for child in road_root.get_children():
            road_root.remove_child(child)
            child.queue_free()
        var piece: NitroDriftTrack = TRACK.new()
        piece.name = "Race road"
        piece.with_props = false
        piece.with_environment = false
        piece.apply_region_style(descriptor())
        road_root.add_child(piece)
        piece._apply_compiled(comp)
        var drivable: bool = (closed and topology == "loop") or (not closed and topology == "route")
        track_ok = bool(ev["ok"]) and drivable
    else:
        last_adapt = world.set_road([] as Array[Vector2],PackedFloat32Array(),PackedFloat32Array(),false)
    _update_status()

func _update_status() -> void:
    _refresh_titles()
    if stage != "build":
        return
    var parts: Array = grid.components()
    if grid.tile_count() == 0:
        _status("TAP A GREEN / AMBER TILE TO START • DRAG TO LAY ROAD • AUTO = RANDOM %s" % topology.to_upper(),true)
        return
    if parts.size() > 1:
        _status("%d PIECES • JOIN THEM INTO ONE ROAD" % parts.size(),false)
        return
    var closed: bool = bool(parts[0]["closed"])
    var comp: Dictionary = last_eval.get("compiled",{})
    if comp.is_empty() or not bool(comp.get("ok",false)):
        var errs: PackedStringArray = comp.get("errors",PackedStringArray()) if not comp.is_empty() else PackedStringArray()
        if topology == "loop" and not closed:
            _status("%d TILES • CONNECT THE ENDS OR TAP CLOSE LOOP" % grid.tile_count(),false)
        else:
            _status("INVALID: "+(str(errs[0]) if not errs.is_empty() else "DRAW MORE ROAD"),false)
        return
    var cls: Dictionary = last_eval.get("class",{})
    var counts: Array = [0,0,0,0,0,0,0]
    for v in cls.get("class",PackedInt32Array()):
        counts[int(v)] += 1
    var works: Array[String] = []
    for k in [2,3,4,5]:
        if counts[k] > 0:
            works.append(PROFILE.NAMES[k])
    var length: int = int(comp["length_metres"])
    var gmax: float = float(last_eval.get("max_grade",0.0))*100.0
    if not bool(last_eval.get("ok",false)):
        _status("RED: "+", ".join(PackedStringArray(cls.get("reasons",[]))),false)
    elif topology == "loop" and not closed:
        _status("%d m • MAX GRADE %.1f %% • CONNECT THE ENDS OR CLOSE LOOP" % [length,gmax],false)
    elif topology == "route" and closed:
        _status("LOOP DRAWN IN ROUTE MODE • TAP ROUTE/LOOP",false)
    else:
        _status("%s READY • %d m • MAX GRADE %.1f %%%s • DRIVE" % ["LOOP" if closed else "ROUTE",length,gmax,
            (" • "+" / ".join(works)) if not works.is_empty() else ""],true)

# ------------------------------------------------------------ save / drive

func current_track_data(title: String, id: String) -> Dictionary:
    if not track_ok or last_data.is_empty():
        return {}
    var d: Dictionary = last_data.duplicate(true)
    d["name"] = title
    d["id"] = id
    return d

func _write(path: String, title: String, id: String) -> bool:
    var data: Dictionary = current_track_data(title,id)
    if data.is_empty():
        _status("FINISH A VALID %s FIRST" % topology.to_upper(),false)
        return false
    var file := FileAccess.open(path,FileAccess.WRITE)
    if file == null:
        _status("STORAGE UNAVAILABLE",false)
        return false
    file.store_string(JSON.stringify(data,"  ",false,true))
    file.close()
    return bool(DNA.read_track(path).get("ok",false))

func _save() -> bool:
    var stamp: Dictionary = Time.get_datetime_dict_from_system()
    var title: String = "%s %02d-%02d %02d:%02d" % [str(CAT.info(archetype)["short"]),stamp["day"],stamp["month"],stamp["hour"],stamp["minute"]]
    var slug: String = "terrain_%04d%02d%02d_%02d%02d%02d" % [stamp["year"],stamp["month"],stamp["day"],
        stamp["hour"],stamp["minute"],stamp["second"]]
    var path: String = "user://nitro_track_"+slug+".json"
    if not _write(path,title,slug):
        return false
    _status("SAVED • "+title+" • IN DRIVE > MY TRACKS",true)
    return true

func _drive() -> void:
    if not _write(DRIVE_PATH,"MY %s %s" % [str(CAT.info(archetype)["short"]),"ROUTE" if topology == "route" else "CIRCUIT"],"player_terrain_track"):
        return
    _save_draft()
    ProjectSettings.set_setting("nitro/selected_track",DRIVE_PATH)
    get_tree().change_scene_to_file("res://scenes/race.tscn")

func _back() -> void:
    if stage == "build":
        _enter_setup()
        return
    _save_draft()
    get_tree().change_scene_to_file("res://scenes/boot.tscn")

# ------------------------------------------------------------ persistence

func _save_draft() -> void:
    var tiles: Array = []
    var pairs: Array = []
    for c in grid.links.keys():
        tiles.append([c.x,c.y])
        for n in grid.links[c]:
            if c < n:
                pairs.append([c.x,c.y,n.x,n.y])
    var file := FileAccess.open(DRAFT,FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify({"version":1,"world":descriptor(),"tiles":tiles,"links":pairs,
            "topology":topology,"route_start":[route_start.x,route_start.y],"stage":stage}))
        file.close()

func _load_draft() -> void:
    if not FileAccess.file_exists(DRAFT):
        return
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DRAFT))
    if not (raw is Dictionary):
        return
    var w: Variant = raw.get("world",{})
    if w is Dictionary and CAT.ARCHETYPES.has(str(w.get("archetype",""))):
        archetype = str(w["archetype"])
        country = str(CAT.info(archetype)["country"])
        terrain_seed = int(w.get("terrain_seed",1))
        event_mode = str(w.get("event_mode","club"))
    topology = str(raw.get("topology","loop"))
    var rs: Array = raw.get("route_start",[-1,-1])
    route_start = Vector2i(int(rs[0]),int(rs[1]))
    for t in raw.get("tiles",[]):
        grid.add_tile(Vector2i(int(t[0]),int(t[1])))
    for l in raw.get("links",[]):
        grid.link(Vector2i(int(l[0]),int(l[1])),Vector2i(int(l[2]),int(l[3])))
    stage = "build" if str(raw.get("stage","setup")) == "build" and grid.tile_count() > 0 else "setup"

## Open a saved terrain track for editing (same world + road).
func load_track_file(path: String) -> bool:
    if not FileAccess.file_exists(path):
        return false
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (raw is Dictionary):
        return false
    var w: Dictionary = TT.world_of(raw)
    if w.is_empty():
        return false
    archetype = str(w["archetype"])
    country = str(CAT.info(archetype)["country"])
    terrain_seed = int(w.get("terrain_seed",1))
    event_mode = str(w.get("event_mode","club"))
    var lg: Dictionary = TT.load_grid(grid,raw)
    if not bool(lg.get("ok",false)):
        return false
    topology = "loop" if bool(lg["closed"]) else "route"
    var order: Array = lg["order"]
    route_start = order[0] if not order.is_empty() else Vector2i(-1,-1)
    stage = "build"
    return true
