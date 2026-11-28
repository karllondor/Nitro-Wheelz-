extends Control
## Nitro Wheelz garage: collectible-card style studio preview of the
## die-cast Lada 2106 drift spec on a slowly turning (draggable) platform.
const CAR = preload("res://scripts/vehicles/lada_lowpoly.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const COSMETICS = preload("res://scripts/vehicles/car_cosmetics.gd")
const BOOT = preload("res://scripts/boot.gd")
const LOGO = preload("res://assets/brand/nitro_wheelz_logo.svg")
const STYLE = preload("res://scripts/ui/hud_style.gd")
const BACKDROP_SHADER = preload("res://assets/shaders/studio_backdrop.gdshader")
var preview: SubViewport
var car: Node3D
var turntable: Node3D
var active_variant: String = "red"
var version_label: Label
var display: SubViewportContainer
var spin_speed: float = 0.35
var dragging: bool = false
var paint_buttons: Dictionary = {}
var cosmetic_buttons: Dictionary = {}
## v0.1.52 (issue #65): the paint palette of the selected car as colour swatches (tap = choose that paint).
var swatch_row: HBoxContainer
var swatch_note: Label
var _swatch_variant: String = ""
var title_label: Label
var info_label: Label
var ui_unit: float = 1.0
var studio_env: Environment
var studio_key: DirectionalLight3D
var studio_fill: DirectionalLight3D
var camera: Camera3D

func _ready() -> void:
    var s: Vector2 = get_viewport_rect().size
    var sc: float = clampf(s.x/700.0,0.85,1.7)
    ui_unit = sc
    theme = STYLE.screen_theme(sc)
    # Same source as the race: this session's choice, else the saved one.
    active_variant = CARS.selected()
    var back := ColorRect.new()
    back.color = Color(0.018,0.016,0.026)
    back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(back)

    var brand := TextureRect.new()
    brand.texture = LOGO
    brand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    brand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    brand.position = Vector2(s.x*0.21,s.y*0.015)
    brand.size = Vector2(s.x*0.58,s.y*0.095)
    brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(brand)

    var title := Label.new()
    title.name = "Garage title"
    title_label = title
    title.position = Vector2(s.x*0.05,s.y*0.122)
    title.size = Vector2(s.x*0.90,s.y*0.045)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_override("font",STYLE.BOLD)
    title.add_theme_font_size_override("font_size",int(24.0*sc))
    title.add_theme_color_override("font_color",STYLE.WHITE)
    add_child(title)

    # Card frame with the HUD's pink neon edge.
    var card := Panel.new()
    card.position = Vector2(s.x*0.045,s.y*0.175)
    card.size = Vector2(s.x*0.91,s.y*0.355)
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var frame := StyleBoxFlat.new()
    frame.bg_color = Color(0.05,0.045,0.07)
    frame.border_color = STYLE.PINK
    frame.set_border_width_all(int(maxf(2.0,2.0*sc)))
    frame.set_corner_radius_all(int(20.0*sc))
    frame.shadow_color = Color(STYLE.PINK.r,STYLE.PINK.g,STYLE.PINK.b,0.28)
    frame.shadow_size = int(14.0*sc)
    card.add_theme_stylebox_override("panel",frame)
    add_child(card)

    display = SubViewportContainer.new()
    display.position = card.position+Vector2(6,6)*sc
    display.size = card.size-Vector2(12,12)*sc
    display.stretch = true
    add_child(display)
    preview = SubViewport.new()
    preview.name = "Realtime car model preview"
    preview.size = Vector2i(maxi(512,int(display.size.x)),maxi(320,int(display.size.y)))
    preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    preview.own_world_3d = true
    # No MSAA here: multisampled SubViewports render black on some Android
    # GL Compatibility drivers (garage showed an empty card on device).
    display.add_child(preview)
    _build_studio()
    _build_turntable()
    _spawn_car()

    var info := Label.new()
    info_label = info
    info.position = Vector2(s.x*0.05,s.y*0.534)
    info.size = Vector2(s.x*0.90,s.y*0.032)
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.add_theme_font_size_override("font_size",int(16.0*sc))
    info.add_theme_color_override("font_color",STYLE.MUTED)
    add_child(info)

    version_label = Label.new()
    version_label.position = Vector2(s.x*0.05,s.y*0.566)
    version_label.size = Vector2(s.x*0.90,s.y*0.036)
    version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    version_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    version_label.add_theme_font_override("font",STYLE.BOLD)
    version_label.add_theme_font_size_override("font_size",int(20.0*sc))
    version_label.add_theme_color_override("font_color",STYLE.PINK_SOFT)
    add_child(version_label)

    swatch_row = HBoxContainer.new()
    swatch_row.name = "Paint swatches"
    swatch_row.position = Vector2(s.x*0.05,s.y*0.606)
    swatch_row.size = Vector2(s.x*0.90,s.y*0.050)
    swatch_row.alignment = BoxContainer.ALIGNMENT_CENTER
    swatch_row.add_theme_constant_override("separation",int(10.0*sc))
    add_child(swatch_row)
    swatch_note = Label.new()
    swatch_note.name = "Paint note"
    swatch_note.position = swatch_row.position
    swatch_note.size = swatch_row.size
    swatch_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    swatch_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    swatch_note.add_theme_font_size_override("font_size",int(18.0*sc))
    swatch_note.add_theme_color_override("font_color",STYLE.MUTED)
    add_child(swatch_note)

    # One button per car in the collection.
    var n: int = CARS.ORDER.size()
    var gap: float = 0.02
    var bw: float = (0.90-gap*float(n-1))/float(n)
    for i in range(n):
        var v: String = CARS.ORDER[i]
        # two lines (model / version) so the names stay readable with five cars on a phone
        paint_buttons[v] = _action(str(CARS.info(v)["short"]).replace(" • ","\n"),0.05+float(i)*(bw+gap),0.663,bw,0.068,
            _choose.bind(v),sc)
        paint_buttons[v].name = "Car "+v
        paint_buttons[v].add_theme_font_size_override("font_size",int((22.0 if n <= 3 else (19.0 if n == 4 else 17.0))*sc))
    # Car Factory cosmetics (prototype): SIGNATURE resets to the authentic
    # look, PAINT and WHEELS cycle presets. Cosmetic only: never physics.
    cosmetic_buttons["signature"] = _action("SIGNATURE",0.05,0.738,0.26,0.068,Callable(self,"_signature"),sc)
    cosmetic_buttons["paint"] = _action("PAINT",0.33,0.738,0.30,0.068,Callable(self,"_next_paint"),sc)
    cosmetic_buttons["wheels"] = _action("WHEELS",0.65,0.738,0.30,0.068,Callable(self,"_next_wheels"),sc)
    for key in cosmetic_buttons.keys():
        cosmetic_buttons[key].name = "Cosmetic "+key
        cosmetic_buttons[key].add_theme_font_size_override("font_size",int(19.0*sc))
        cosmetic_buttons[key].clip_text = true
    # v0.1.35: the track is choosable from the garage (owner: "from the garage
    # you cannot pick a track"). The button shows the track DRIVE will use.
    track_button = _action("TRACK  ▸  "+BOOT.track_label(BOOT.current_track()),0.05,0.812,0.90,0.062,Callable(self,"_pick_track"),sc)
    track_button.name = "Garage track"
    _action("BACK",0.05,0.885,0.43,0.072,Callable(self,"_back"),sc).name = "Garage back"
    _action("DRIVE",0.52,0.885,0.43,0.072,Callable(self,"_drive"),sc).name = "Garage drive"
    _set_status()

func _build_studio() -> void:
    # Soft studio matching the approved model sheets: light grey for the red
    # drift spec, lavender with a pink/violet key for the pearl-white car.
    var world := WorldEnvironment.new()
    studio_env = Environment.new()
    studio_env.background_mode = Environment.BG_COLOR
    studio_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    world.environment = studio_env
    preview.add_child(world)
    studio_key = DirectionalLight3D.new()
    studio_key.name = "Key light"
    studio_key.rotation_degrees = Vector3(-50.0,35.0,0.0)
    preview.add_child(studio_key)
    studio_fill = DirectionalLight3D.new()
    studio_fill.name = "Fill light"
    studio_fill.rotation_degrees = Vector3(-25.0,205.0,0.0)
    preview.add_child(studio_fill)
    _apply_studio()

func _apply_studio() -> void:
    if studio_env == null:
        return
    # Neutral grey studio for both paints (owner: not too dark, not too
    # light, grey gradient like the poster reference).
    var white: bool = active_variant == "white"
    studio_env.background_color = Color(0.36,0.36,0.375)
    studio_env.ambient_light_color = Color(0.90,0.90,0.93)
    studio_env.ambient_light_energy = 0.70 if white else 0.80
    studio_key.light_color = Color(1.0,0.98,0.96)
    studio_key.light_energy = 1.05 if white else 1.15
    studio_fill.light_color = Color(0.86,0.89,1.0)
    studio_fill.light_energy = 0.50

const BASE_FOV: float = 36.0
## v0.3 controlled framing (every car): the lens is fitted to the car's real
## bounds so the car fills the card; the widest angle over a full turn sets
## the floor (never clipped), narrower views (front / rear) zoom in smoothly
## by at most GARAGE_ZOOM_IN.
const GARAGE_FILL: float = 0.90
const GARAGE_ZOOM_IN: float = 1.22
var _car_corners: Array[Vector3] = []
var _fit_tan_floor: float = 0.0
var _fit_tan: float = 0.0

func _apply_zoom() -> void:
    if camera == null or car == null:
        return
    # Silhouette points of the real car in turntable space (wheels included,
    # contact shadow excluded): the extreme vertex in 24 plan directions for
    # 3 height bands (cheap enough to re-fit every frame on a phone).
    var pts: Array[Vector3] = []
    var inv: Transform3D = turntable.global_transform.affine_inverse()
    for n in car.find_children("*","MeshInstance3D",true,false):
        var mi: MeshInstance3D = n
        if mi.mesh == null or not mi.visible or str(mi.name).to_lower().contains("shadow"):
            continue
        var xf: Transform3D = inv*mi.global_transform
        for si in range(mi.mesh.get_surface_count()):
            var verts: PackedVector3Array = mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
            for k in range(0,verts.size(),5):
                pts.append(xf*verts[k])
    _car_corners.clear()
    if pts.is_empty():
        var box := AABB(Vector3(-0.9,0,-2.2),Vector3(1.8,1.3,4.4))
        for i in range(8):
            _car_corners.append(box.get_endpoint(i))
    else:
        var ylo: float = INF
        var yhi: float = -INF
        for p in pts:
            ylo = minf(ylo,p.y)
            yhi = maxf(yhi,p.y)
        for band in range(3):
            var b0: float = lerpf(ylo,yhi,float(band)/3.0)
            var b1: float = lerpf(ylo,yhi,float(band+1)/3.0)+0.001
            for d in range(24):
                var dir := Vector2(cos(TAU*float(d)/24.0),sin(TAU*float(d)/24.0))
                var best: Vector3 = Vector3.ZERO
                var best_v: float = -INF
                for p2 in pts:
                    if p2.y < b0 or p2.y >= b1:
                        continue
                    var v: float = p2.x*dir.x+p2.z*dir.y
                    if v > best_v:
                        best_v = v
                        best = p2
                if best_v > -INF and not _car_corners.has(best):
                    _car_corners.append(best)
        # Highest and lowest points too.
        for p3 in pts:
            if p3.y >= yhi-0.001 or p3.y <= ylo+0.001:
                _car_corners.append(p3)
                if _car_corners.size() > 90:
                    break
    var saved: float = turntable.rotation.y
    _fit_tan_floor = 0.0
    for deg in range(0,360,10):
        turntable.rotation.y = deg_to_rad(float(deg))
        _fit_tan_floor = maxf(_fit_tan_floor,_needed_tan())
    turntable.rotation.y = saved
    _fit_tan = maxf(_needed_tan(),_fit_tan_floor/GARAGE_ZOOM_IN)
    _frame_camera(1.0)

## Horizontal half-angle tangent the car needs at the current turntable angle.
func _needed_tan() -> float:
    if _car_corners.is_empty():
        return tan(deg_to_rad(BASE_FOV*0.5))
    var aspect: float = float(preview.size.x)/maxf(float(preview.size.y),1.0)
    var inv: Transform3D = camera.global_transform.affine_inverse()
    var need: float = 0.0
    for c in _car_corners:
        var p: Vector3 = inv*(turntable.global_transform*c)
        var depth: float = maxf(-p.z,0.1)
        need = maxf(need,maxf(absf(p.x)/depth,absf(p.y)/depth*aspect))
    return need/GARAGE_FILL

## Fit the lens for the current angle (widen at once, zoom in smoothly).
func _frame_camera(blend: float) -> void:
    if camera == null or _car_corners.is_empty():
        return
    var want: float = maxf(_needed_tan(),_fit_tan_floor/GARAGE_ZOOM_IN)
    _fit_tan = maxf(want,lerpf(_fit_tan,want,clampf(blend,0.0,1.0)))
    camera.fov = rad_to_deg(2.0*atan(minf(_fit_tan,_fit_tan_floor)))

func _build_turntable() -> void:
    turntable = Node3D.new()
    turntable.name = "Turntable"
    turntable.rotation.y = deg_to_rad(145.0)  # front three-quarter, like the sheet
    preview.add_child(turntable)
    camera = Camera3D.new()
    camera.name = "Garage camera"
    # Horizontal FOV (KEEP_WIDTH): the whole 4.2 m car stays inside the tall
    # card at every turntable angle, side-on included (it was cut off).
    camera.keep_aspect = Camera3D.KEEP_WIDTH
    # v0.3: a little higher (collectible product shot, ~16 deg): more of the
    # bonnet / roof shows and the car fills more of the tall card.
    camera.position = Vector3(0.0,3.0,8.6)
    camera.fov = 36.0
    preview.add_child(camera)
    camera.look_at(Vector3(0,0.50,0),Vector3.UP)
    camera.current = true
    # Screen-space grey gradient backdrop, parented to the camera.
    var backdrop := MeshInstance3D.new()
    backdrop.name = "Studio backdrop"
    var quad := QuadMesh.new()
    quad.size = Vector2(160,160)
    backdrop.mesh = quad
    var mat := ShaderMaterial.new()
    mat.shader = BACKDROP_SHADER
    var card: Vector2 = Vector2(preview.size)
    mat.set_shader_parameter("aspect",card.x/maxf(card.y,1.0))
    backdrop.material_override = mat
    backdrop.position = Vector3(0,0,-60.0)
    backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    camera.add_child(backdrop)

func _process(delta: float) -> void:
    if turntable != null and not dragging:
        turntable.rotation.y += spin_speed*delta
    _frame_camera(1.0-exp(-2.5*delta))

func _input(event: InputEvent) -> void:
    # Drag anywhere over the card to spin the car.
    if display == null:
        return
    var inside: bool = false
    if event is InputEventScreenTouch or event is InputEventMouseButton:
        var pos: Vector2 = event.position
        inside = Rect2(display.position,display.size).has_point(pos)
        dragging = event.pressed and inside
    elif dragging and event is InputEventScreenDrag:
        turntable.rotation.y += (event as InputEventScreenDrag).relative.x*0.008
    elif dragging and event is InputEventMouseMotion:
        turntable.rotation.y += (event as InputEventMouseMotion).relative.x*0.008

func _choose_red() -> void:
    _choose("red")

func _choose_white() -> void:
    _choose("white")

## Tests / tools: do not really change scene; the request is recorded instead.
var navigate_enabled: bool = true
var last_scene: String = ""
var track_button: Button

func _goto(scene: String) -> void:
    last_scene = scene
    if navigate_enabled:
        get_tree().change_scene_to_file(scene)

## BACK returns to where the garage was opened from (main menu or RACE SETUP).
func _back() -> void:
    var from_page: String = str(ProjectSettings.get_setting("nitro/garage_return","main"))
    ProjectSettings.set_setting("nitro/garage_return","main")
    ProjectSettings.set_setting("nitro/boot_page",from_page)
    _goto("res://scenes/boot.tscn")

## The track list, then back here.
func _pick_track() -> void:
    ProjectSettings.set_setting("nitro/track_return","garage")
    ProjectSettings.set_setting("nitro/boot_page","drive")
    _goto("res://scenes/boot.tscn")

func _drive() -> void:
    ProjectSettings.set_setting("nitro/selected_track",BOOT.current_track())
    _goto("res://scenes/race.tscn")

func _set_status() -> void:
    var info: Dictionary = CARS.info(active_variant)
    var prof: Dictionary = CARS.cosmetic_profile(active_variant)
    var factory: bool = COSMETICS.supported(prof)
    version_label.text = "SELECTED: "+str(info["paint"])+"  •  "+str(info["note"])
    if CARS.uses_factory_test_model(active_variant):
        version_label.text += "  •  FACTORY GLB"
    if factory:
        var choice: Dictionary = COSMETICS.current(active_variant,prof)
        version_label.text = "%s  •  %s  •  %s" % [COSMETICS.paint_name(choice,prof),
            COSMETICS.wheel_name(choice)+" WHEELS","ORIGINAL" if COSMETICS.is_signature(choice,prof) else "CUSTOM"]
        cosmetic_buttons["paint"].text = "PAINT: "+COSMETICS.paint_name(choice,prof)
        cosmetic_buttons["wheels"].text = "WHEELS: "+COSMETICS.wheel_name(choice)
    else:
        cosmetic_buttons["paint"].text = "PAINT: ORIGINAL"
        cosmetic_buttons["wheels"].text = "WHEELS: ORIGINAL"
    _build_swatches(prof,factory)
    for key in cosmetic_buttons.keys():
        cosmetic_buttons[key].disabled = not factory
        STYLE.style_button(cosmetic_buttons[key],ui_unit,false)
        cosmetic_buttons[key].modulate.a = 1.0 if factory else 0.55
    if title_label != null:
        title_label.text = "GARAGE  /  "+str(info["name"])
    if info_label != null:
        info_label.text = "BODY %.3f m   •   WHEELBASE %.3f m   •   %s" % [float(info["length"]),
            float(info["wheelbase"]),str(info.get("body","WIDEBODY"))]
    for key in paint_buttons.keys():
        STYLE.style_button(paint_buttons[key],ui_unit,key == active_variant)

## One swatch per paint preset of the selected car; the chosen one is ringed. A car without a palette (the R32
## FLAME AI test car) says so in words instead of showing dead buttons.
func _build_swatches(prof: Dictionary, factory: bool) -> void:
    if swatch_row == null:
        return
    var list: Array = COSMETICS.paints(prof) if factory else []
    var current: int = COSMETICS.paint_index(COSMETICS.current(active_variant,prof),prof) if factory else -1
    if _swatch_variant != active_variant or swatch_row.get_child_count() != list.size():
        _swatch_variant = active_variant
        for c in swatch_row.get_children():
            swatch_row.remove_child(c)
            c.queue_free()
        var n: int = maxi(1,list.size())
        var sep: float = 10.0*ui_unit
        var side: float = minf(swatch_row.size.y,(swatch_row.size.x-sep*float(n-1))/float(n)/1.35)
        for i in range(list.size()):
            var b := Button.new()
            b.name = "Paint swatch %d" % i
            b.tooltip_text = str((list[i] as Dictionary).get("name",""))
            b.custom_minimum_size = Vector2(side*1.35,side)
            b.focus_mode = Control.FOCUS_ALL
            b.pressed.connect(_choose_paint.bind(i))
            swatch_row.add_child(b)
    for i in range(swatch_row.get_child_count()):
        var b: Button = swatch_row.get_child(i)
        var p: Dictionary = list[i]
        var col: Color = Color.html(str(p["hex"])) if Color.html_is_valid(str(p["hex"])) else Color.GRAY
        for state in ["normal","hover","pressed","focus"]:
            var box := StyleBoxFlat.new()
            box.bg_color = col
            box.set_corner_radius_all(int(10.0*ui_unit))
            var on: bool = i == current
            box.border_color = STYLE.WHITE if on else (STYLE.PINK if state != "normal" else Color(1,1,1,0.25))
            box.set_border_width_all(int((5.0 if on else 2.0)*ui_unit))
            if str(p.get("livery_id","clean")) != "clean":
                box.border_width_bottom = int(9.0*ui_unit) # livery preset: thicker lower edge
            b.add_theme_stylebox_override(state,box)
    swatch_note.visible = list.is_empty()
    swatch_note.text = "" if factory else "THIS CAR HAS ITS FACTORY PAINT ONLY"

func _choose_paint(index: int) -> void:
    var prof: Dictionary = CARS.cosmetic_profile(active_variant)
    if COSMETICS.supported(prof):
        _apply_cosmetic(COSMETICS.choose_paint(active_variant,prof,index))

func _signature() -> void:
    var prof: Dictionary = CARS.cosmetic_profile(active_variant)
    if not COSMETICS.supported(prof):
        return
    var choice: Dictionary = COSMETICS.reset_to_signature(active_variant,prof)
    _apply_cosmetic(choice)

func _next_paint() -> void:
    var prof: Dictionary = CARS.cosmetic_profile(active_variant)
    if COSMETICS.supported(prof):
        _apply_cosmetic(COSMETICS.next_paint(active_variant,prof))

func _next_wheels() -> void:
    var prof: Dictionary = CARS.cosmetic_profile(active_variant)
    if COSMETICS.supported(prof):
        _apply_cosmetic(COSMETICS.next_wheel(active_variant,prof))

## Live update of the preview: same car node, new paint / wheels only.
func _apply_cosmetic(choice: Dictionary) -> void:
    if car != null and car.has_method("apply_paint"):
        car.call("apply_paint",CARS.visual_choice(active_variant,choice))
        car.call("apply_wheels",choice)
    _set_status()

func _spawn_car() -> void:
    if car != null:
        turntable.remove_child(car)
        car.queue_free()
        car = null
    car = CARS.make(active_variant)
    car.set("shadow_height",0.012)
    car.name = str(CARS.info(active_variant)["name"])+" "+active_variant
    turntable.add_child(car)
    _apply_zoom()

func _choose(chosen: String) -> void:
    if chosen == active_variant:
        return
    active_variant = CARS.select(chosen)
    _spawn_car()
    _apply_studio()
    _set_status()

func _action(caption: String,x: float,y: float,w: float,h: float,fn: Callable,sc: float) -> Button:
    var s: Vector2 = get_viewport_rect().size
    var button := Button.new()
    button.text = caption
    button.position = Vector2(s.x*x,s.y*y)
    button.size = Vector2(s.x*w,s.y*h)
    button.add_theme_font_size_override("font_size",int(18.0*sc))
    STYLE.style_button(button,sc)
    button.pressed.connect(fn)
    add_child(button)
    return button

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _back()
