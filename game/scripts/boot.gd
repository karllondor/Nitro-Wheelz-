extends Control
## Starter menu redesigned for readable portrait phones without tiny inherited
## desktop fonts. Buttons scale with the project viewport and remain focusable.

func _ready() -> void:
    var s: Vector2 = get_viewport_rect().size
    var portrait: bool = s.y > s.x
    var scale_factor: float = clampf(s.x/700.0,1.0,2.2) if portrait else 1.0

    var background := ColorRect.new()
    background.color = Color(0.016,0.014,0.024)
    add_child(background)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var center := CenterContainer.new()
    add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var menu := VBoxContainer.new()
    menu.custom_minimum_size = Vector2(s.x*(0.83 if portrait else 0.42),0)
    menu.add_theme_constant_override("separation",int(10*scale_factor))
    center.add_child(menu)

    # Brand artwork derived from user-supplied graffiti logo.
    var logo := TextureRect.new()
    logo.name = "Nitro Wheelz Graffiti Crown Logo"
    logo.texture = load("res://assets/brand/nitro_wheelz_logo.svg") as Texture2D
    logo.custom_minimum_size = Vector2(s.x*0.70,s.y*(0.175 if portrait else 0.22))
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    menu.add_child(logo)

    var description := Label.new()
    description.text = "3 LAPS  •  2 CAMERAS  •  ORIGINAL PHYSICS\nCHOOSE A TRACK TO DRIVE"
    description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description.add_theme_font_size_override("font_size",int(19*scale_factor))
    menu.add_child(description)

    var start := _button(menu,"SHIN-KAWA • ORIGINAL","res://scenes/race.tscn",
        scale_factor,"res://tracks/shin_kawa_v2.json")
    _button(menu,"TEST 01 • OVAL (271m)","res://scenes/race.tscn",
        scale_factor,"res://tracks/benchmark_oval.json")
    _button(menu,"TEST 02 • SWEEPERS (295m)","res://scenes/race.tscn",
        scale_factor,"res://tracks/benchmark_sweepers.json")
    _button(menu,"SHIN-KAWA • FULL CIRCUIT","res://scenes/race.tscn",
        scale_factor,"res://tracks/shin_kawa_full_circuit.json")

    _button(menu,"GARAGE • RED / WHITE LADA","res://scenes/garage.tscn",scale_factor)
    _button(menu,"EDIT TRACK • BETA","res://scenes/track_editor.tscn",scale_factor)

    # Generator BETA: generates a valid variant but does NOT permit editing.
    # Creator BETA: generate a new safe closed Track DNA variant locally;
    # never start a race with an unvalidated corridor.
    var generated_status := Label.new()
    generated_status.text = ""
    generated_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    generated_status.add_theme_font_size_override("font_size",int(16*scale_factor))
    var generator_button := Button.new()
    generator_button.text = "GENERATE TRACK • BETA"
    generator_button.custom_minimum_size.y = 62*scale_factor
    generator_button.add_theme_font_size_override("font_size",int(21*scale_factor))
    _brand_button(generator_button)
    menu.add_child(generator_button)
    generator_button.pressed.connect(func():
        var creator: Variant = load("res://scripts/world/track_generator.gd").new()
        var seed: int = Time.get_ticks_usec()
        var result: Dictionary = creator.generate(seed)
        if bool(result.get("ok",false)):
            ProjectSettings.set_setting("nitro/selected_track",str(result["path"]))
            get_tree().change_scene_to_file("res://scenes/race.tscn")
        else:
            generated_status.text = "GENERATION FAILED: "+str(result.get("error","unknown"))
    )
    menu.add_child(generated_status)
    _button(menu,"CONTROLLER DIAGNOSTICS","res://scenes/dev/input_monitor.tscn",scale_factor)

    var hint := Label.new()
    hint.text = "LEFT JOYSTICK • GAS • BRAKE • DRIFT\nCAM changes camera • PAUSE opens menu"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size",int(18*scale_factor))
    menu.add_child(hint)

    var stamp := Label.new()
    stamp.text = "NITRO WHEELZ v" + str(ProjectSettings.get_setting("application/config/version","unknown")) + "  |  TECHNICAL PLAYTEST"
    stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stamp.add_theme_font_size_override("font_size",int(16*scale_factor))
    stamp.add_theme_color_override("font_color",Color(0.69,0.58,1.0))
    menu.add_child(stamp)
    if not OS.has_feature("mobile"):
        var quit := Button.new()
        quit.text = "QUIT"
        quit.custom_minimum_size.y = 53*scale_factor
        quit.add_theme_font_size_override("font_size",int(22*scale_factor))
        quit.pressed.connect(func():get_tree().quit())
        menu.add_child(quit)
    start.grab_focus()

func _button(parent: VBoxContainer,title: String, scene: String,
        scale_factor: float,track_path: String = "") -> Button:
    var button := Button.new()
    button.text = title
    button.custom_minimum_size.y = 62*scale_factor
    button.add_theme_font_size_override("font_size",int(21*scale_factor))
    button.pressed.connect(func():
        if not track_path.is_empty():
            ProjectSettings.set_setting("nitro/selected_track",track_path)
        get_tree().change_scene_to_file(scene))
    _brand_button(button)
    parent.add_child(button)
    return button

func _brand_button(button: Button) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.052,0.048,0.076)
    normal.border_color = Color(0.40,0.27,0.58)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(10)
    button.add_theme_stylebox_override("normal",normal)
    var hover: StyleBoxFlat = normal.duplicate()
    hover.bg_color = Color(0.12,0.080,0.22)
    hover.border_color = Color(0.57,0.30,0.98)
    hover.set_border_width_all(2)
    button.add_theme_stylebox_override("hover",hover)
    button.add_theme_stylebox_override("focus",hover)
    var pressed: StyleBoxFlat = hover.duplicate()
    pressed.bg_color = Color(0.24,0.12,0.36)
    button.add_theme_stylebox_override("pressed",pressed)
    button.add_theme_color_override("font_color",Color(0.98,0.98,1.0))
    button.add_theme_color_override("font_hover_color",Color(1.0,0.83,0.30))
