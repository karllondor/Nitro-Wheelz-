extends Control
## Nitro Wheelz garage: collectible-card style studio preview of the
## die-cast Lada 2106 drift spec on a slowly turning (draggable) platform.
const CAR = preload("res://scripts/vehicles/lada_lowpoly.gd")
const LOGO = preload("res://assets/brand/nitro_wheelz_logo.svg")
const STYLE = preload("res://scripts/ui/hud_style.gd")
var preview: SubViewport
var car: NitroLadaLowPoly
var turntable: Node3D
var active_variant: String = "red"
var version_label: Label
var display: SubViewportContainer
var spin_speed: float = 0.35
var dragging: bool = false
var paint_buttons: Dictionary = {}
var ui_unit: float = 1.0

func _ready() -> void:
    var s: Vector2 = get_viewport_rect().size
    var sc: float = clampf(s.x/700.0,0.85,1.7)
    ui_unit = sc
    theme = STYLE.screen_theme(sc)
    active_variant = str(ProjectSettings.get_setting("nitro/car_variant","red"))
    # Persist garage paint across app restarts; do not reset to red.
    var garage_cfg := ConfigFile.new()
    if garage_cfg.load("user://nitro_garage.cfg") == OK:
        active_variant = str(garage_cfg.get_value("garage","paint",active_variant))
    if active_variant != "white":
        active_variant = "red"
    ProjectSettings.set_setting("nitro/car_variant",active_variant)
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
    title.text = "GARAGE  /  LADA 2106 DRIFT SPEC"
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
    card.size = Vector2(s.x*0.91,s.y*0.50)
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var frame := StyleBoxFlat.new()
    frame.bg_color = Color(0.05,0.045,0.07)
    frame.border_color = STYLE.PINK
    frame.set_border_width_all(int(maxf(2.0,2.0*sc)))
    frame.set_corner_radius_all(int(20.0*sc))
    frame.shadow_color = Color(1.0,0.16,0.56,0.28)
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
    preview.msaa_3d = Viewport.MSAA_4X
    display.add_child(preview)
    _build_studio()
    _spawn_car()

    var info := Label.new()
    info.text = "BODY 4.166 m   •   WHEELBASE 2.424 m   •   WIDEBODY"
    info.position = Vector2(s.x*0.05,s.y*0.695)
    info.size = Vector2(s.x*0.90,s.y*0.035)
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.add_theme_font_size_override("font_size",int(15.0*sc))
    info.add_theme_color_override("font_color",STYLE.MUTED)
    add_child(info)

    version_label = Label.new()
    version_label.position = Vector2(s.x*0.05,s.y*0.732)
    version_label.size = Vector2(s.x*0.90,s.y*0.032)
    version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    version_label.add_theme_font_override("font",STYLE.BOLD)
    version_label.add_theme_font_size_override("font_size",int(17.0*sc))
    version_label.add_theme_color_override("font_color",STYLE.PINK_SOFT)
    add_child(version_label)

    paint_buttons["red"] = _action("RED  •  EXPOSED ENGINE",0.05,0.782,0.44,0.072,
        Callable(self,"_choose_red"),sc)
    paint_buttons["white"] = _action("WHITE  •  CLEAN HOOD",0.51,0.782,0.44,0.072,
        Callable(self,"_choose_white"),sc)
    _action("BACK TO MENU",0.05,0.885,0.43,0.072,Callable(self,"_back"),sc)
    _action("DRIVE",0.52,0.885,0.43,0.072,Callable(self,"_drive"),sc)
    _set_status()

func _build_studio() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.055,0.045,0.08)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.70,0.66,0.86)
    env.ambient_light_energy = 0.75
    world.environment = env
    preview.add_child(world)
    var key := DirectionalLight3D.new()
    key.name = "Key light"
    key.rotation_degrees = Vector3(-48.0,32.0,0.0)
    key.light_energy = 1.35
    preview.add_child(key)
    var rim := DirectionalLight3D.new()
    rim.name = "Pink rim light"
    rim.rotation_degrees = Vector3(-18.0,200.0,0.0)
    rim.light_color = Color(1.0,0.30,0.65)
    rim.light_energy = 0.9
    preview.add_child(rim)
    # Glossy dark plinth with a neon ring.
    var plinth := MeshInstance3D.new()
    var disc := CylinderMesh.new()
    disc.top_radius = 3.3
    disc.bottom_radius = 3.4
    disc.height = 0.12
    disc.radial_segments = 64
    plinth.mesh = disc
    plinth.position.y = -0.06
    var plinth_mat := StandardMaterial3D.new()
    plinth_mat.albedo_color = Color(0.07,0.065,0.09)
    plinth_mat.roughness = 0.25
    plinth_mat.metallic = 0.2
    plinth.material_override = plinth_mat
    preview.add_child(plinth)
    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 3.32
    torus.outer_radius = 3.42
    torus.rings = 64
    ring.mesh = torus
    ring.position.y = 0.0
    var ring_mat := StandardMaterial3D.new()
    ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ring_mat.albedo_color = STYLE.PINK
    ring.material_override = ring_mat
    preview.add_child(ring)
    turntable = Node3D.new()
    turntable.name = "Turntable"
    turntable.rotation.y = deg_to_rad(-35.0)
    preview.add_child(turntable)
    var camera := Camera3D.new()
    camera.position = Vector3(0.0,2.5,8.0)
    camera.fov = 34.0
    preview.add_child(camera)
    camera.look_at(Vector3(0,0.15,0),Vector3.UP)
    camera.current = true

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
    version_label.text = "SELECTED: "+("PEARL WHITE" if active_variant=="white" else "RACING RED")
    for key in paint_buttons.keys():
        STYLE.style_button(paint_buttons[key],ui_unit,key == active_variant)

func _spawn_car() -> void:
    if car != null:
        turntable.remove_child(car)
        car.queue_free()
        car = null
    car = CAR.new()
    car.paint_variant = active_variant
    car.shadow_height = 0.012
    car.name = "Lada 2106 "+active_variant
    turntable.add_child(car)

func _choose(chosen: String) -> void:
    if chosen == active_variant:
        return
    active_variant = chosen
    ProjectSettings.set_setting("nitro/car_variant",chosen)
    var garage_cfg := ConfigFile.new()
    garage_cfg.set_value("garage","paint",chosen)
    garage_cfg.save("user://nitro_garage.cfg")
    _spawn_car()
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
