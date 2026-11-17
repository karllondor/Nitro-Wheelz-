extends Control

var output: RichTextLabel
var connected: Array[int] = []
var chosen_device := -1
var elapsed := 0.0

func _ready() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.06, 0.09, 0.13)
    add_child(bg)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var panel := VBoxContainer.new()
    add_child(panel)
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.offset_left = 24
    panel.offset_top = 24
    panel.offset_right = -24
    panel.offset_bottom = -24
    var title := Label.new()
    title.text = "INPUT MONITOR - Xbox USB/Bluetooth / Keyboard / Android"
    title.add_theme_font_size_override("font_size", 26)
    panel.add_child(title)
    output = RichTextLabel.new()
    output.bbcode_enabled = false
    output.fit_content = false
    output.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.add_child(output)
    var back := Button.new()
    back.text = "BACK (click/touch; Escape / Xbox Menu)"
    back.focus_mode = Control.FOCUS_NONE
    back.custom_minimum_size.y = 48
    back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/boot.tscn"))
    panel.add_child(back)
    var rumble := Button.new()
    rumble.text = "TEST XBOX VIBRATION - explicit click/tap only"
    rumble.focus_mode = Control.FOCUS_NONE
    rumble.custom_minimum_size.y = 48
    rumble.pressed.connect(_rumble)
    panel.add_child(rumble)
    Input.joy_connection_changed.connect(_connection_changed)
    _connection_changed(-1, false)
    _refresh()

func _connection_changed(_device: int, _is_connected: bool) -> void:
    connected = Input.get_connected_joypads()
    chosen_device = connected[0] if not connected.is_empty() else -1

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed > 0.12:
        elapsed = 0.0
        _refresh()

func _refresh() -> void:
    var rows := PackedStringArray()
    rows.append("Controllers: " + str(connected) + " | active: " + str(chosen_device))
    rows.append("Keyboard / input: WASD move, Space primary, E secondary, Esc pause")
    rows.append("Action strengths: move L/R " + str(Input.get_action_strength("move_left")) + " / " + str(Input.get_action_strength("move_right")))
    if chosen_device >= 0:
        rows.append("Name: " + Input.get_joy_name(chosen_device))
        rows.append("GUID: " + Input.get_joy_guid(chosen_device))
        rows.append("Raw axes (0-5):")
        for axis in range(6):
            rows.append(" axis " + str(axis) + " : " + str(snappedf(Input.get_joy_axis(chosen_device, axis), 0.001)))
        rows.append("Buttons A B X Y LB RB Menu:")
        for button in [JOY_BUTTON_A,JOY_BUTTON_B,JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_START]:
            rows.append(" button " + str(button) + " = " + str(Input.is_joy_button_pressed(chosen_device, button)))
    else:
        rows.append("No controller detected. Connect Xbox via USB or Bluetooth.")
    rows.append("Device behavior and rumble must be tested on real hardware.")
    if output != null:
        output.text = "
".join(rows)

func _rumble() -> void:
    if chosen_device >= 0:
        Input.start_joy_vibration(chosen_device, 0.5, 0.5, 0.25)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("game_pause") or event.is_action_pressed("ui_cancel"):
        get_viewport().set_input_as_handled()
        get_tree().change_scene_to_file("res://scenes/boot.tscn")

