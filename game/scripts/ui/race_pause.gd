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
var _on_edit: Callable
var settings: NitroSettingsPanel
## v0.1.27: settings fold away under SOUND & STYLE (more readable menu).
static var settings_open: bool = false

func show_pause(on_resume: Callable,on_restart: Callable,on_garage: Callable,on_edit: Callable = Callable()) -> void:
    _on_resume = on_resume
    _on_restart = on_restart
    _on_garage = on_garage
    _on_edit = on_edit
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
    shade.color = Color(0.005,0.006,0.011,0.86)
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
    # v0.1.27 layout: big primary RESUME, RESTART | EDIT TRACK side by side,
    # GARAGE / MENU, then SOUND & STYLE folded away.
    var resume: Button = _menu_button(stack,"▶  RESUME",_on_resume,sc,68.0,26.0,true)
    resume.name = "RESUME"
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation",int(10.0*sc))
    stack.add_child(row)
    _menu_button(row,"↻  RESTART",_on_restart,sc,60.0,21.0).name = "RESTART"
    if _on_edit.is_valid():
        _menu_button(row,"✎  EDIT TRACK",_on_edit,sc,60.0,21.0).name = "EDIT TRACK"
    _menu_button(stack,"GARAGE / MENU",_on_garage,sc,60.0,21.0).name = "GARAGE / MENU"
    var fold: Button = _menu_button(stack,("▾  SOUND & STYLE" if settings_open else "▸  SOUND & STYLE"),
        func() -> void:
            settings_open = not settings_open
            call_deferred("_build"),sc,48.0,17.0)
    fold.name = "Settings fold"
    settings = SETTINGS.new()
    settings.name = "Settings panel"
    stack.add_child(settings)
    settings.build(sc)
    settings.visible = settings_open
    # A new accent rebuilds this panel so its own buttons recolour too.
    settings.accent_changed.connect(func(_a: String) -> void: call_deferred("_build"))

func _menu_button(parent: Control, text: String, cb: Callable, sc: float, h: float, fs: float,
        primary: bool = false) -> Button:
    var btn := Button.new()
    btn.text = text
    btn.custom_minimum_size.y = h*sc
    btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    btn.add_theme_font_override("font",STYLE.BOLD)
    btn.add_theme_font_size_override("font_size",int(fs*sc))
    STYLE.style_button(btn,sc,primary)
    btn.pressed.connect(cb)
    parent.add_child(btn)
    return btn

## Kept for callers/tests: same actions as the panel buttons.
func _toggle_sound() -> void:
    settings.toggle_sound()

func choose_accent(accent: String) -> void:
    STYLE.set_accent(accent)
    STYLE.save_settings()
    _build()
