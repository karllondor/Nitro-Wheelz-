extends Control
class_name NitroPauseMenu
## Single modal pause overlay. Blocks touch to old race controls.
## Also holds the player settings: sound on/off and the interface accent
## colour (every HUD panel, glow, bar and button reads STYLE.PINK, so a new
## swatch recolours the whole UI immediately). Settings persist in
## user://nitro_settings.cfg.
const STYLE = preload("res://scripts/ui/hud_style.gd")

var _on_resume: Callable
var _on_restart: Callable
var _on_garage: Callable
var sound_button: Button
var swatches: Dictionary = {}

func show_pause(on_resume: Callable,on_restart: Callable,on_garage: Callable) -> void:
    _on_resume = on_resume
    _on_restart = on_restart
    _on_garage = on_garage
    STYLE.ensure_settings()
    _build()

func _build() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    swatches.clear()
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var s: Vector2 = get_viewport_rect().size
    var sc: float = clampf(s.x/700.0,0.85,1.7)
    theme = STYLE.screen_theme(sc)
    var shade := ColorRect.new()
    shade.color = Color(0.005,0.006,0.011,0.76)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(shade)
    var centre := CenterContainer.new()
    centre.mouse_filter = Control.MOUSE_FILTER_PASS
    centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(centre)
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(minf(s.x*0.82,s.y*1.1),0)
    panel.add_theme_stylebox_override("panel",STYLE.modal_box(sc))
    centre.add_child(panel)
    var margin := MarginContainer.new()
    var p: int = int(20.0*sc)
    for side in ["margin_left","margin_right","margin_top","margin_bottom"]:
        margin.add_theme_constant_override(side,p)
    panel.add_child(margin)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation",int(13.0*sc))
    margin.add_child(stack)
    var head := Label.new()
    head.text = "PAUSED"
    head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    head.add_theme_color_override("font_color",STYLE.WHITE)
    head.add_theme_font_override("font",STYLE.BOLD)
    head.add_theme_font_size_override("font_size",int(34.0*sc))
    stack.add_child(head)
    for item in [
        {"name":"RESUME","action":_on_resume},
        {"name":"RESTART","action":_on_restart},
        {"name":"GARAGE / MENU","action":_on_garage}
    ]:
        var btn := Button.new()
        btn.text = str(item["name"])
        btn.custom_minimum_size.y = 52.0*sc
        btn.add_theme_font_size_override("font_size",int(20.0*sc))
        STYLE.style_button(btn,sc)
        btn.pressed.connect(item["action"])
        stack.add_child(btn)

    stack.add_child(_section("SETTINGS",sc))
    sound_button = Button.new()
    sound_button.name = "Sound toggle"
    sound_button.custom_minimum_size.y = 48.0*sc
    sound_button.add_theme_font_size_override("font_size",int(19.0*sc))
    sound_button.pressed.connect(_toggle_sound)
    stack.add_child(sound_button)
    _refresh_sound(sc)

    var accent_label := Label.new()
    accent_label.text = "ACCENT COLOUR"
    accent_label.add_theme_color_override("font_color",STYLE.MUTED)
    accent_label.add_theme_font_size_override("font_size",int(15.0*sc))
    stack.add_child(accent_label)
    var row := HBoxContainer.new()
    row.name = "Accent swatches"
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation",int(10.0*sc))
    stack.add_child(row)
    for accent in STYLE.ACCENT_ORDER:
        var sw := Button.new()
        sw.name = "Accent "+accent
        sw.tooltip_text = accent.to_upper()
        sw.custom_minimum_size = Vector2(54.0,54.0)*sc
        sw.focus_mode = Control.FOCUS_ALL
        var selected: bool = accent == STYLE.accent_name
        for state in ["normal","hover","pressed","focus"]:
            sw.add_theme_stylebox_override(state,_swatch_box(STYLE.ACCENTS[accent],selected,sc))
        sw.pressed.connect(choose_accent.bind(accent))
        row.add_child(sw)
        swatches[accent] = sw

func _section(title: String, sc: float) -> Control:
    var l := Label.new()
    l.text = title
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.add_theme_font_override("font",STYLE.BOLD)
    l.add_theme_color_override("font_color",STYLE.PINK_SOFT)
    l.add_theme_font_size_override("font_size",int(18.0*sc))
    return l

func _swatch_box(colour: Color, selected: bool, sc: float) -> StyleBoxFlat:
    var b := StyleBoxFlat.new()
    b.bg_color = colour
    b.set_corner_radius_all(int(27.0*sc))
    b.border_color = Color.WHITE if selected else Color(0,0,0,0.55)
    b.set_border_width_all(int((4.0 if selected else 2.0)*sc))
    b.shadow_color = Color(colour.r,colour.g,colour.b,0.55 if selected else 0.0)
    b.shadow_size = int(10.0*sc) if selected else 0
    return b

func _refresh_sound(sc: float) -> void:
    sound_button.text = "SOUND  ON" if STYLE.sound_on else "SOUND  OFF"
    STYLE.style_button(sound_button,sc,STYLE.sound_on)

func _toggle_sound() -> void:
    STYLE.set_sound(not STYLE.sound_on)
    STYLE.save_settings()
    _refresh_sound(clampf(get_viewport_rect().size.x/700.0,0.85,1.7))

## Applies an accent everywhere and rebuilds this panel in the new colour.
func choose_accent(accent: String) -> void:
    STYLE.set_accent(accent)
    STYLE.save_settings()
    _build()
