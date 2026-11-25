extends HBoxContainer
## Compact exclusive choices shared by setup, lobby and pause.
const STYLE = preload("res://scripts/ui/hud_style.gd")
const TIME = preload("res://scripts/lighting/time_of_day.gd")
const ICON_PATHS := [
    "M3 17h18M7 15a5 5 0 0 1 10 0M12 10V3m-3 3 3-3 3 3",
    "M12 2v3m0 14v3M2 12h3m14 0h3M5 5l2 2m10 10 2 2M5 19l2-2M17 7l2-2M16 12a4 4 0 1 1-8 0 4 4 0 0 1 8 0",
    "M3 17h18M7 15a5 5 0 0 1 10 0M12 3v7m-3-3 3 3 3-3",
    "M20 15A8 8 0 0 1 9 4a8 8 0 1 0 11 11Z"
]
static var _icons: Array[Texture2D] = []
var _buttons: Array[Button] = []
var _scale := 1.0

func configure(options: Array, selected: int, on_chosen: Callable, ui_scale: float, show_icons := false) -> void:
    _scale = ui_scale
    add_theme_constant_override("separation", roundi(6.0 * ui_scale))
    if show_icons and _icons.is_empty():
        for path in ICON_PATHS:
            var image := Image.new()
            image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="%s" fill="none" stroke="#fff0c9" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round"/></svg>' % path, 2.0)
            _icons.append(ImageTexture.create_from_image(image))
    var group := ButtonGroup.new()
    for index in options.size():
        var button := Button.new()
        button.name = str(options[index])
        button.text = str(options[index])
        button.toggle_mode = true
        button.button_group = group
        button.disabled = not on_chosen.is_valid()
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.custom_minimum_size.y = roundi((57.0 if show_icons else 44.0) * ui_scale)
        button.add_theme_font_override("font", STYLE.BOLD)
        button.add_theme_font_size_override("font_size", roundi(15.0 * ui_scale))
        if show_icons:
            button.icon = _icons[index]
            button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
            button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
            button.add_theme_constant_override("icon_max_width", roundi(21.0 * ui_scale))
            button.expand_icon = true
        add_child(button)
        _buttons.append(button)
        if on_chosen.is_valid():
            button.pressed.connect(_choose.bind(index, on_chosen))
    select(selected)

func _choose(value: int, on_chosen: Callable) -> void:
    select(value)
    on_chosen.call(value)

func select(value: int) -> void:
    for index in _buttons.size():
        var button := _buttons[index]
        var active := index == value
        button.set_pressed_no_signal(active)
        STYLE.style_button(button, _scale * 0.75, active)
        if button.disabled:
            button.add_theme_color_override("font_disabled_color", STYLE.WHITE if active else STYLE.DIM)
            if active:
                button.add_theme_stylebox_override("disabled", button.get_theme_stylebox("pressed"))
