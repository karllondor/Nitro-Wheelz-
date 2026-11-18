extends Control
## Starter menu redesigned for readable portrait phones without tiny inherited
## desktop fonts. Buttons scale with the project viewport and remain focusable.

func _ready() -> void:
    var s: Vector2 = get_viewport_rect().size
    var portrait: bool = s.y > s.x
    var scale_factor: float = clampf(s.x/700.0,1.0,2.2) if portrait else 1.0

    var background := ColorRect.new()
    background.color = Color(0.055,0.065,0.087)
    add_child(background)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var center := CenterContainer.new()
    add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var menu := VBoxContainer.new()
    menu.custom_minimum_size = Vector2(s.x*(0.79 if portrait else 0.40),0)
    menu.add_theme_constant_override("separation",int(15*scale_factor))
    center.add_child(menu)

    var title := Label.new()
    title.text = "NITRO WHEELZ"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size",int(49*scale_factor))
    title.add_theme_color_override("font_color",Color(1.0,0.63,0.27))
    menu.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "JAPAN DRIFT NIGHTS"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size",int(24*scale_factor))
    subtitle.add_theme_color_override("font_color",Color(0.90,0.91,0.94))
    menu.add_child(subtitle)

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
    generator_button.custom_minimum_size.y = 77*scale_factor
    generator_button.add_theme_font_size_override("font_size",int(25*scale_factor))
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
    stamp.add_theme_color_override("font_color",Color(0.66,0.73,0.80))
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
    button.custom_minimum_size.y = 77*scale_factor
    button.add_theme_font_size_override("font_size",int(25*scale_factor))
    button.pressed.connect(func():
        if not track_path.is_empty():
            ProjectSettings.set_setting("nitro/selected_track",track_path)
        get_tree().change_scene_to_file(scene))
    parent.add_child(button)
    return button
