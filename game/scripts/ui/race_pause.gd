extends Control
class_name NitroPauseMenu
## Single modal pause overlay. Blocks touch to old race controls.
## Holds the shared player settings panel: sound on/off, engine / tyres /
## effects volumes and the interface accent colour (every HUD panel, glow,
## bar and button reads STYLE.PINK, so a new swatch recolours the whole UI
## immediately). Settings persist in user://nitro_settings.cfg.
const STYLE = preload("res://scripts/ui/hud_style.gd")
const SETTINGS = preload("res://scripts/ui/settings_panel.gd")

var _on_resume: Callable
var _on_restart: Callable
var _on_garage: Callable
var settings: NitroSettingsPanel

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
    panel.custom_minimum_size = Vector2(minf(s.x*0.84,s.y*1.1),0)
    panel.add_theme_stylebox_override("panel",STYLE.modal_box(sc))
    centre.add_child(panel)
    var margin := MarginContainer.new()
    var p: int = int(20.0*sc)
    for side in ["margin_left","margin_right","margin_top","margin_bottom"]:
        margin.add_theme_constant_override(side,p)
    panel.add_child(margin)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation",int(12.0*sc))
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
    settings = SETTINGS.new()
    settings.name = "Settings panel"
    stack.add_child(settings)
    settings.build(sc)
    # A new accent rebuilds this panel so its own buttons recolour too.
    settings.accent_changed.connect(func(_a: String) -> void: call_deferred("_build"))

## Kept for callers/tests: same actions as the panel buttons.
func _toggle_sound() -> void:
    settings.toggle_sound()

func choose_accent(accent: String) -> void:
    STYLE.set_accent(accent)
    STYLE.save_settings()
    _build()
