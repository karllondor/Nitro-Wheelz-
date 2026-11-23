extends Control
class_name NitroRaceDesktopActions
## Mouse-first CAMERA and PAUSE on Linux/Windows/macOS/Web.
## These used to exist only in NitroRaceTouch (hidden on PC/Web).
## Neither the desktop overlay nor its parent captures gameplay mouse input.

const STYLE = preload("res://scripts/ui/hud_style.gd")

signal camera_requested
signal pause_requested

var camera_button: Button
var pause_button: Button

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    STYLE.ensure_settings()
    camera_button = _make_button("Camera", "CAMERA", "C: switch camera")
    pause_button = _make_button("Pause", "PAUSE", "Esc: pause game")
    camera_button.pressed.connect(func() -> void: camera_requested.emit())
    pause_button.pressed.connect(func() -> void: pause_requested.emit())
    get_viewport().size_changed.connect(_refresh_geometry)
    _refresh_geometry()

func _make_button(node_name: String, label: String, hint: String) -> Button:
    var button := Button.new()
    button.name = node_name
    button.text = label
    button.tooltip_text = hint
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    button.focus_mode = Control.FOCUS_NONE
    add_child(button)
    _style_button(button)
    return button

func _style_button(button: Button) -> void:
    STYLE.style_button(button,1.0)
    # Retain the existing Nitro Wheelz accent and Exo type, but allow more
    # of the racing line to show through the smaller desktop controls.
    for state in ["normal","hover","focus","pressed"]:
        var box: StyleBoxFlat = STYLE.button_box(1.0,state)
        box.bg_color.a = 0.74 if state == "normal" else 0.87
        box.shadow_size = 0 if state == "normal" else 4
        box.set_corner_radius_all(7)
        box.content_margin_left = 4.0
        box.content_margin_right = 4.0
        button.add_theme_stylebox_override(state,box)
    button.add_theme_font_size_override("font_size",13)

func _refresh_geometry() -> void:
    if camera_button == null or pause_button == null:
        return
    var size_px: Vector2 = get_viewport_rect().size
    var profile: String = STYLE.platform_profile()
    var m: Dictionary = STYLE.metrics(size_px,profile)
    var camera_r: Rect2 = m["camera"]
    var pause_r: Rect2 = m["pause"]
    camera_button.position = camera_r.position
    camera_button.size = camera_r.size
    pause_button.position = pause_r.position
    pause_button.size = pause_r.size
    var font_px: int = int(clampf(camera_r.size.y*0.34,11.0,14.0))
    camera_button.add_theme_font_size_override("font_size",font_px)
    pause_button.add_theme_font_size_override("font_size",font_px)
