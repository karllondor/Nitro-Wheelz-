extends Control

func _ready() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.06, 0.08, 0.12)
    add_child(bg)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var center := CenterContainer.new()
    add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var box := VBoxContainer.new()
    box.custom_minimum_size = Vector2(440, 0)
    box.add_theme_constant_override("separation", 18)
    center.add_child(box)
    var heading := Label.new()
    heading.text = "NEW_GAME_NAME"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 42)
    box.add_child(heading)
    var subtitle := Label.new()
    subtitle.text = "Karll Game Starter | Test shell, not a shipped game"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(subtitle)
    var play := _button(box, "PLAY INPUT / MOVEMENT PROTOTYPE", "res://scenes/prototype.tscn")
    _button(box, "XBOX / KEYBOARD INPUT MONITOR", "res://scenes/dev/input_monitor.tscn")
    var version := Label.new()
    version.text = "Build: " + _build_label()
    version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(version)
    if not OS.has_feature("mobile"):
        var quit_button := Button.new()
        quit_button.text = "QUIT"
        quit_button.custom_minimum_size.y = 52
        quit_button.pressed.connect(func(): get_tree().quit())
        box.add_child(quit_button)
    play.grab_focus()

func _button(parent: VBoxContainer, title: String, scene: String) -> Button:
    var button := Button.new()
    button.text = title
    button.custom_minimum_size.y = 60
    button.pressed.connect(func(): get_tree().change_scene_to_file(scene))
    parent.add_child(button)
    return button

func _build_label() -> String:
    var data = JSON.parse_string(FileAccess.get_file_as_string("res://build_info.json"))
    if data is Dictionary:
        return str(data.get("version", "?")) + " / " + str(data.get("git_sha", "unbuilt")).substr(0, 8)
    return "unknown"

