extends Control

func _ready() -> void:
    var background := ColorRect.new()
    background.color = Color(0.055,0.071,0.092)
    add_child(background)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var centre := CenterContainer.new()
    add_child(centre)
    centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var menu := VBoxContainer.new()
    menu.custom_minimum_size = Vector2(410,0)
    menu.add_theme_constant_override("separation",20)
    centre.add_child(menu)

    var name := Label.new()
    name.text = "NITRO WHEELZ"
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name.add_theme_font_size_override("font_size",44)
    name.add_theme_color_override("font_color",Color(1.0,0.62,0.28))
    menu.add_child(name)

    var subtitle := Label.new()
    subtitle.text = "JAPAN DRIFT NIGHTS"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size",22)
    menu.add_child(subtitle)

    var description := Label.new()
    description.text = "Shin-Kawa Drift Park • 3-lap driving laboratory\nTop-down default • Chase camera optional\nGarage and car collection: planned for later releases"
    description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    menu.add_child(description)

    var start := _button(menu,"START DRIFT SESSION","res://scenes/race.tscn")
    _button(menu,"XBOX / INPUT DIAGNOSTICS","res://scenes/dev/input_monitor.tscn")

    var hint := Label.new()
    hint.text = "WASD / left stick · Space / A drift · C / Y camera\nEsc / Menu pause · R restart · M main menu"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    menu.add_child(hint)

    var stamp := Label.new()
    stamp.text = "PROTOTYPE v0.1.0 — original physics implementation"
    stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stamp.add_theme_color_override("font_color",Color(0.67,0.73,0.80))
    menu.add_child(stamp)

    if not OS.has_feature("mobile"):
        var quit := Button.new()
        quit.text = "QUIT"
        quit.custom_minimum_size.y = 52
        quit.pressed.connect(func():get_tree().quit())
        menu.add_child(quit)
    start.grab_focus()

func _button(parent: VBoxContainer,title: String, scene: String) -> Button:
    var button := Button.new()
    button.text = title
    button.custom_minimum_size.y = 64
    button.pressed.connect(func():get_tree().change_scene_to_file(scene))
    parent.add_child(button)
    return button

