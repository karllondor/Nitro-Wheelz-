extends Control
class_name NitroPauseMenu
## Single modal pause overlay. Blocks touch to old race controls.
## Holds the shared player settings panel: sound on/off, engine / tyres /
## effects volumes and the interface accent colour (every HUD panel, glow,
## bar and button reads STYLE.PINK, so a new swatch recolours the whole UI
## immediately). Settings persist in user://nitro_settings.cfg.
const TIME = preload("res://scripts/lighting/time_of_day.gd")
const LAMPS = preload("res://scripts/lighting/car_lamps.gd")
const LIGHTING_SELECTOR = preload("res://scripts/ui/lighting_selector.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")
const SETTINGS = preload("res://scripts/ui/settings_panel.gd")

var _on_resume: Callable
var _on_restart: Callable
var _on_garage: Callable
var _on_edit: Callable
## NITRO WHEELZ PARK (issue #27): an optional extra row (TUTORIAL ON / OFF).
var extra_label: String = ""
var _on_extra: Callable
var _park_options: Dictionary = {}
var _lighting: Dictionary = {}
var _time_picker: HBoxContainer
var settings: NitroSettingsPanel
## v0.1.27: settings fold away under SOUND & STYLE (more readable menu).
static var settings_open: bool = false

func show_pause(on_resume: Callable,on_restart: Callable,on_garage: Callable,on_edit: Callable = Callable(),
        on_extra: Callable = Callable(),label_extra: String = "",park_options: Dictionary = {},
        lighting: Dictionary = {}) -> void:
    _lighting = lighting
    _on_extra = on_extra
    extra_label = label_extra
    _park_options = park_options
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
    var sc: float = clampf(minf(s.x/700.0, s.y/700.0),0.72,1.45)
    theme = STYLE.screen_theme(sc)
    var shade := ColorRect.new()
    shade.color = Color(0.005,0.006,0.011,0.67)
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
    var scroll := ScrollContainer.new()
    scroll.name = "Pause options"
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.custom_minimum_size = Vector2(panel.custom_minimum_size.x, 0)
    scroll.follow_focus = true
    centre.add_child(scroll)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(panel)
    panel.minimum_size_changed.connect(func():
        scroll.custom_minimum_size.y = minf(s.y * 0.92, panel.get_combined_minimum_size().y))
    var resize_scroll := func():
        scroll.custom_minimum_size.y = minf(s.y * 0.92, panel.get_combined_minimum_size().y)
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
    # v0.1.32 (owner QA): RESTART and GARAGE / MENU end the run, so they ask
    # for a second tap (the label says so for 2.5 s) instead of a popup.
    var restart_label: String = _park_options.get("restart","↻  RESTART")
    var rb: Button = _menu_button(row,restart_label,Callable(),sc,60.0,21.0)
    rb.name = _park_options.get("restart","RESTART")
    if _on_restart.is_valid():
        rb.pressed.connect(_confirm.bind(rb,"TAP AGAIN TO RECOVER" if _park_options.has("restart") else "TAP AGAIN TO RESTART",_on_restart))
    else:
        rb.text = "RESTART UNAVAILABLE"
        rb.disabled = true
    if _on_edit.is_valid():
        _menu_button(row,"✎  EDIT TRACK",_on_edit,sc,60.0,21.0).name = "EDIT TRACK"
    if _on_extra.is_valid() and extra_label != "":
        _menu_button(stack,extra_label,_on_extra,sc,60.0,19.0).name = "Park tutorial toggle"
    var reset_action: Callable = _park_options.get("reset",Callable())
    if reset_action.is_valid():
        var reset: Button = _menu_button(stack,"RESET TRAINING OBJECTS",Callable(),sc,60.0,19.0)
        reset.name = "RESET TRAINING OBJECTS"
        reset.pressed.connect(_confirm.bind(reset,"TAP AGAIN TO RESET OBJECTS",reset_action))
    var leave_label: String = _park_options.get("leave","GARAGE / MENU")
    var gb: Button = _menu_button(stack,leave_label,Callable(),sc,60.0,21.0)
    gb.name = leave_label
    gb.pressed.connect(_confirm.bind(gb,"TAP AGAIN TO RETURN" if _park_options.has("leave") else "TAP AGAIN TO LEAVE THE RUN",_on_garage))
    if _lighting.has("set_mode"):
        _lighting_row(stack, "VEHICLE LIGHTS", LAMPS.MODE_LABELS, int(_lighting.get("mode",0)), _lighting.set_mode, sc)
    if _lighting.has("time"):
        _time_picker = _lighting_row(stack, "TIME OF DAY", TIME.LABELS, int(_lighting.time), _lighting.get("set_time",Callable()), sc, true)
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
    resize_scroll.call_deferred()

func _lighting_row(parent: Control, title: String, options: Array, value: int, on_chosen: Callable, sc: float, icons := false) -> HBoxContainer:
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 3)
    parent.add_child(column)
    var label := Label.new()
    label.text = title
    label.add_theme_font_override("font", STYLE.BOLD)
    label.add_theme_font_size_override("font_size", roundi(14.0 * sc))
    label.add_theme_color_override("font_color", STYLE.MUTED)
    column.add_child(label)
    var row := LIGHTING_SELECTOR.new()
    row.name = title
    column.add_child(row)
    var key := "time" if icons else "mode"
    var action := Callable()
    if on_chosen.is_valid():
        action = func(index: int):
            _lighting[key] = index
            on_chosen.call(index)
    row.configure(options, value, action, sc, icons)
    return row

func show_time_of_day(value: int) -> void:
    if _lighting.has("time"):
        _lighting.time = value
    if is_instance_valid(_time_picker):
        _time_picker.select(value)

func _menu_button(parent: Control, text: String, cb: Callable, sc: float, h: float, fs: float,
        primary: bool = false) -> Button:
    var btn := Button.new()
    btn.text = text
    btn.custom_minimum_size.y = h*sc
    btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    btn.add_theme_font_override("font",STYLE.BOLD)
    btn.add_theme_font_size_override("font_size",int(fs*sc))
    STYLE.style_button(btn,sc,primary)
    if cb.is_valid():
        btn.pressed.connect(cb)
    parent.add_child(btn)
    return btn

## Two-tap confirmation for actions that throw the current run away.
func _confirm(btn: Button, prompt: String, action: Callable) -> void:
    if btn.has_meta("armed") and Time.get_ticks_msec()-int(btn.get_meta("armed")) < 2500:
        btn.remove_meta("armed")
        action.call()
        return
    var label: String = btn.text
    btn.set_meta("armed",Time.get_ticks_msec())
    btn.text = prompt
    STYLE.style_button(btn,btn.get_theme_font_size("font_size")/21.0,true)
    get_tree().create_timer(2.5).timeout.connect(func() -> void:
        if is_instance_valid(btn) and btn.has_meta("armed"):
            btn.remove_meta("armed")
            btn.text = label
            STYLE.style_button(btn,btn.get_theme_font_size("font_size")/21.0,false))

## Kept for callers/tests: same actions as the panel buttons.
func _toggle_sound() -> void:
    settings.toggle_sound()

func choose_accent(accent: String) -> void:
    STYLE.set_accent(accent)
    STYLE.save_settings()
    _build()
