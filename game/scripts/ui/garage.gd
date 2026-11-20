extends Control
## Nitro Wheelz garage: collectible-card style studio preview of the
## die-cast Lada 2106 drift spec on a slowly turning (draggable) platform.
const CAR = preload("res://scripts/vehicles/lada_lowpoly.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const COSMETICS = preload("res://scripts/vehicles/car_cosmetics.gd")
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
var title_label: Label
var info_label: Label
var ui_unit: float = 1.0
var studio_env: Environment
var studio_key: DirectionalLight3D
var studio_fill: DirectionalLight3D

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
    card.position = Vector2(s.x*0.045,s.y*0.180)
    card.size = Vector2(s.x*0.91,s.y*0.455)
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
    info.position = Vector2(s.x*0.05,s.y*0.645)
    info.size = Vector2(s.x*0.90,s.y*0.035)
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.add_theme_font_size_override("font_size",int(15.0*sc))
    info.add_theme_color_override("font_color",STYLE.MUTED)
    add_child(info)

    version_label = Label.new()
    version_label.position = Vector2(s.x*0.05,s.y*0.680)
    version_label.size = Vector2(s.x*0.90,s.y*0.032)
    version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    version_label.add_theme_font_override("font",STYLE.BOLD)
    version_label.add_theme_font_size_override("font_size",int(17.0*sc))
    version_label.add_theme_color_override("font_color",STYLE.PINK_SOFT)
    add_child(version_label)

    # One button per car in the collection.
    var n: int = CARS.ORDER.size()
    var gap: float = 0.02
    var bw: float = (0.90-gap*float(n-1))/float(n)
    for i in range(n):
        var v: String = CARS.ORDER[i]
        paint_buttons[v] = _action(str(CARS.info(v)["short"]),0.05+float(i)*(bw+gap),0.718,bw,0.068,
            _choose.bind(v),sc)
        paint_buttons[v].name = "Car "+v
        paint_buttons[v].add_theme_font_size_override("font_size",int((18.0 if n <= 3 else 14.0)*sc))
    # Car Factory cosmetics (prototype): SIGNATURE resets to the authentic
    # look, PAINT and WHEELS cycle presets. Cosmetic only: never physics.
    cosmetic_buttons["signature"] = _action("SIGNATURE",0.05,0.800,0.26,0.068,Callable(self,"_signature"),sc)
    cosmetic_buttons["paint"] = _action("PAINT",0.33,0.800,0.30,0.068,Callable(self,"_next_paint"),sc)
    cosmetic_buttons["wheels"] = _action("WHEELS",0.65,0.800,0.30,0.068,Callable(self,"_next_wheels"),sc)
    for key in cosmetic_buttons.keys():
        cosmetic_buttons[key].name = "Cosmetic "+key
        cosmetic_buttons[key].add_theme_font_size_override("font_size",int(14.0*sc))
    _action("BACK TO MENU",0.05,0.885,0.43,0.072,Callable(self,"_back"),sc)
    _action("DRIVE",0.52,0.885,0.43,0.072,Callable(self,"_drive"),sc)
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

func _build_turntable() -> void:
    turntable = Node3D.new()
    turntable.name = "Turntable"
    turntable.rotation.y = deg_to_rad(145.0)  # front three-quarter, like the sheet
    preview.add_child(turntable)
    var camera := Camera3D.new()
    camera.name = "Garage camera"
    # Horizontal FOV (KEEP_WIDTH): the whole 4.2 m car stays inside the tall
    # card at every turntable angle, side-on included (it was cut off).
    camera.keep_aspect = Camera3D.KEEP_WIDTH
    camera.position = Vector3(0.0,2.3,8.6)
    camera.fov = 36.0
    preview.add_child(camera)
    camera.look_at(Vector3(0,0.55,0),Vector3.UP)
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

func _back() -> void:
    get_tree().change_scene_to_file("res://scenes/boot.tscn")

func _drive() -> void:
    if not ProjectSettings.has_setting("nitro/selected_track"):
        ProjectSettings.set_setting("nitro/selected_track","res://tracks/shin_kawa_v2.json")
    get_tree().change_scene_to_file("res://scenes/race.tscn")

func _set_status() -> void:
    var info: Dictionary = CARS.info(active_variant)
    var prof: Dictionary = CARS.profile(active_variant)
    var factory: bool = COSMETICS.supported(prof)
    version_label.text = "SELECTED: "+str(info["paint"])+"  •  "+str(info["note"])
    if factory:
        var choice: Dictionary = COSMETICS.current(active_variant,prof)
        version_label.text = "%s  •  %s  •  %s" % [COSMETICS.paint_name(choice,prof),
            COSMETICS.wheel_name(choice)+" WHEELS","ORIGINAL" if COSMETICS.is_signature(choice,prof) else "CUSTOM"]
        cosmetic_buttons["paint"].text = "PAINT: "+COSMETICS.paint_name(choice,prof)
        cosmetic_buttons["wheels"].text = "WHEELS: "+COSMETICS.wheel_name(choice)
    else:
        cosmetic_buttons["paint"].text = "PAINT"
        cosmetic_buttons["wheels"].text = "WHEELS"
    for key in cosmetic_buttons.keys():
        cosmetic_buttons[key].disabled = not factory
        STYLE.style_button(cosmetic_buttons[key],ui_unit,false)
        cosmetic_buttons[key].modulate.a = 1.0 if factory else 0.35
    if title_label != null:
        title_label.text = "GARAGE  /  "+str(info["name"])
    if info_label != null:
        info_label.text = "BODY %.3f m   •   WHEELBASE %.3f m   •   %s" % [float(info["length"]),
            float(info["wheelbase"]),str(info.get("body","WIDEBODY"))]
    for key in paint_buttons.keys():
        STYLE.style_button(paint_buttons[key],ui_unit,key == active_variant)

func _signature() -> void:
    var prof: Dictionary = CARS.profile(active_variant)
    if not COSMETICS.supported(prof):
        return
    var choice: Dictionary = COSMETICS.reset_to_signature(active_variant,prof)
    _apply_cosmetic(choice)

func _next_paint() -> void:
    var prof: Dictionary = CARS.profile(active_variant)
    if COSMETICS.supported(prof):
        _apply_cosmetic(COSMETICS.next_paint(active_variant,prof))

func _next_wheels() -> void:
    var prof: Dictionary = CARS.profile(active_variant)
    if COSMETICS.supported(prof):
        _apply_cosmetic(COSMETICS.next_wheel(active_variant,prof))

## Live update of the preview: same car node, new paint / wheels only.
func _apply_cosmetic(choice: Dictionary) -> void:
    if car != null and car.has_method("apply_paint"):
        car.call("apply_paint",choice)
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
        get_tree().change_scene_to_file("res://scenes/boot.tscn")
