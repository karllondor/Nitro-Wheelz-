extends Control
## Nitro Wheelz garage: interactive 3D low-poly toy-style Lada 2106 preview.
const CAR = preload("res://scripts/vehicles/lada_lowpoly.gd")
const LOGO = preload("res://assets/brand/nitro_wheelz_logo.svg")
var preview: SubViewport
var car: NitroLadaLowPoly
var active_variant: String = "red"
var version_label: Label

func _ready() -> void:
    var s: Vector2 = get_viewport_rect().size
    var sc: float = clampf(s.x/700.0,0.85,1.7)
    active_variant = str(ProjectSettings.get_setting("nitro/car_variant","red"))
    # Persist garage paint across app restarts; do not reset to red.
    var garage_cfg := ConfigFile.new()
    if garage_cfg.load("user://nitro_garage.cfg") == OK:
        active_variant = str(garage_cfg.get_value("garage","paint",active_variant))
    if active_variant != "white":
        active_variant = "red"
    ProjectSettings.set_setting("nitro/car_variant",active_variant)
    var back := ColorRect.new()
    back.color = Color(0.018,0.015,0.028)
    back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(back)

    var brand := TextureRect.new()
    brand.texture = LOGO
    brand.position = Vector2(s.x*0.21,s.y*0.015)
    brand.size = Vector2(s.x*0.58,s.y*0.105)
    brand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    brand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(brand)

    var title := Label.new()
    title.text = "GARAGE  /  LADA 2106 DRIFT SPEC"
    title.position = Vector2(s.x*0.05,s.y*0.13)
    title.size = Vector2(s.x*0.90,s.y*0.045)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size",int(22.0*sc))
    title.add_theme_color_override("font_color",Color(1.0,0.82,0.25))
    add_child(title)

    var display := SubViewportContainer.new()
    display.position = Vector2(s.x*0.045,s.y*0.190)
    display.size = Vector2(s.x*0.91,s.y*0.48)
    display.stretch = true
    add_child(display)
    preview = SubViewport.new()
    preview.name = "Realtime car model preview"
    preview.size = Vector2i(maxi(512,int(s.x)),maxi(320,int(s.y*0.48)))
    preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    preview.own_world_3d = true
    display.add_child(preview)

    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.14,0.12,0.20)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.92,0.89,0.99)
    env.ambient_light_energy = 0.9
    world.environment = env
    preview.add_child(world)
    var lamp := DirectionalLight3D.new()
    lamp.rotation_degrees = Vector3(-35.0,30.0,0.0)
    lamp.light_energy = 1.5
    preview.add_child(lamp)
    var camera := Camera3D.new()
    camera.position = Vector3(4.5,2.7,-5.8)
    camera.fov = 53.0
    preview.add_child(camera)
    camera.look_at(Vector3(0,0.85,0),Vector3.UP)
    camera.current = true
    _spawn_car()

    var info := Label.new()
    info.text = "BODY 4.166 m   •   WHEELBASE 2.424 m   •   WIDEBODY"
    info.position = Vector2(s.x*0.05,s.y*0.685)
    info.size = Vector2(s.x*0.90,s.y*0.039)
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.add_theme_font_size_override("font_size",int(15.0*sc))
    info.add_theme_color_override("font_color",Color(0.78,0.74,0.90))
    add_child(info)

    version_label = Label.new()
    version_label.position = Vector2(s.x*0.05,s.y*0.73)
    version_label.size = Vector2(s.x*0.90,s.y*0.032)
    version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    version_label.add_theme_font_size_override("font_size",int(16.0*sc))
    version_label.add_theme_color_override("font_color",Color(1.0,1.0,1.0))
    add_child(version_label)
    _set_status()

    _action("RED  •  EXPOSED ENGINE",0.05,0.775,0.44,0.075,
        Callable(self,"_choose_red"),sc)
    _action("WHITE  •  CLEAN HOOD",0.51,0.775,0.44,0.075,
        Callable(self,"_choose_white"),sc)
    _action("BACK TO MENU",0.05,0.885,0.43,0.075,
        Callable(self,"_back"),sc)
    _action("DRIVE",0.52,0.885,0.43,0.075,
        Callable(self,"_drive"),sc)

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

func _spawn_car() -> void:
    if car != null:
        preview.remove_child(car)
        car.queue_free()
        car = null
    car = CAR.new()
    car.paint_variant = active_variant
    car.name = "Lada 2106 "+active_variant
    preview.add_child(car)

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

func _action(caption: String,x: float,y: float,w: float,h: float,fn: Callable,sc: float) -> void:
    var s: Vector2 = get_viewport_rect().size
    var button := Button.new()
    button.text = caption
    button.position = Vector2(s.x*x,s.y*y)
    button.size = Vector2(s.x*w,s.y*h)
    button.add_theme_font_size_override("font_size",int(18.0*sc))
    var box := StyleBoxFlat.new()
    box.bg_color = Color(0.073,0.063,0.103)
    box.border_color = Color(0.57,0.30,0.98)
    box.set_border_width_all(2)
    box.set_corner_radius_all(12)
    button.add_theme_stylebox_override("normal",box)
    button.pressed.connect(fn)
    add_child(button)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        get_tree().change_scene_to_file("res://scenes/boot.tscn")
