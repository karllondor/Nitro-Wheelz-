extends Control

var player: ColorRect
var speed := 290.0
var start_pos := Vector2(640.0, 360.0)

func _ready() -> void:
    var background := ColorRect.new()
    background.color = Color(0.1, 0.13, 0.17)
    add_child(background)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    player = ColorRect.new()
    player.size = Vector2(48, 48)
    player.position = start_pos
    player.color = Color(1, 0.51, 0.18)
    add_child(player)
    var info := VBoxContainer.new()
    info.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    info.offset_left = 20
    info.offset_top = 18
    add_child(info)
    var hint := Label.new()
    hint.text = "Move WASD/Xbox stick, A/Space colour, X/E reset, Menu/Esc back"
    info.add_child(hint)
    var back := Button.new()
    back.text = "BACK TO MENU"
    back.focus_mode = Control.FOCUS_NONE
    back.custom_minimum_size.y = 48
    back.pressed.connect(_back)
    info.add_child(back)
    if OS.has_feature("mobile"):
        var touchscreen: Control = load("res://scripts/touch_controls.gd").new()
        add_child(touchscreen)
        touchscreen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
    var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if player != null:
        player.position += movement * speed * delta
        player.position = player.position.clamp(Vector2.ZERO, get_viewport_rect().size - player.size)
        if Input.is_action_just_pressed("action_primary"):
            player.color = Color(0.2, 0.8, 0.9) if player.color.r > 0.5 else Color(1, 0.51, 0.18)
        if Input.is_action_just_pressed("action_secondary"):
            player.position = start_pos

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("game_pause") or event.is_action_pressed("ui_cancel"):
        get_viewport().set_input_as_handled()
        _back()

func _back() -> void:
    get_tree().change_scene_to_file("res://scenes/boot.tscn")

