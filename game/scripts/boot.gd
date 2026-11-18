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
    description.text = "SHIN-KAWA DRIFT PARK\n3 LAPS  •  2 CAMERAS  •  ORIGINAL PHYSICS"
    description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description.add_theme_font_size_override("font_size",int(19*scale_factor))
    menu.add_child(description)

    var start := _button(menu,"START DRIFT SESSION","res://scenes/race.tscn",scale_factor)
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

func _button(parent: VBoxContainer,title: String, scene: String,scale_factor: float) -> Button:
    var button := Button.new()
    button.text = title
    button.custom_minimum_size.y = 77*scale_factor
    button.add_theme_font_size_override("font_size",int(25*scale_factor))
    button.pressed.connect(func():get_tree().change_scene_to_file(scene))
    parent.add_child(button)
    return button
