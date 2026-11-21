extends VBoxContainer
class_name NitroSettingsPanel
## Player settings, shared by the pause menu and the main-menu SETTINGS
## screen: master SOUND on/off, separate ENGINE / TYRES / EFFECTS volumes
## (owner audit P1) and the interface accent colour. Everything persists in
## user://nitro_settings.cfg through NitroHudStyle.
const STYLE = preload("res://scripts/ui/hud_style.gd")
const DRIVER = preload("res://scripts/player/driver_profile.gd")

signal accent_changed(accent: String)

var sc: float = 1.0
var sound_button: Button
var sliders: Dictionary = {}

func build(scale: float, show_header: bool = true) -> void:
    sc = scale
    STYLE.ensure_settings()
    for child in get_children():
        remove_child(child)
        child.queue_free()
    sliders.clear()
    add_theme_constant_override("separation",int(10.0*sc))
    var head := Label.new()
    head.text = "SETTINGS"
    head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    head.add_theme_font_override("font",STYLE.BOLD)
    head.add_theme_color_override("font_color",STYLE.PINK_SOFT)
    head.add_theme_font_size_override("font_size",int(18.0*sc))
    if show_header:
        add_child(head)
    else:
        head.free()
    sound_button = Button.new()
    sound_button.name = "Sound toggle"
    sound_button.custom_minimum_size.y = 46.0*sc
    sound_button.add_theme_font_size_override("font_size",int(19.0*sc))
    sound_button.pressed.connect(toggle_sound)
    add_child(sound_button)
    _refresh_sound()
    # The local driver name is used on every new score record.
    var driver_row := HBoxContainer.new()
    driver_row.name = "Driver name"
    driver_row.add_theme_constant_override("separation",int(10.0*sc))
    var driver_label := Label.new()
    driver_label.text = "DRIVER"
    driver_label.custom_minimum_size.x = 130.0*sc
    driver_label.add_theme_font_override("font",STYLE.BOLD)
    driver_label.add_theme_font_size_override("font_size",int(17.0*sc))
    driver_row.add_child(driver_label)
    var driver_input := LineEdit.new()
    driver_input.name = "Driver input"
    driver_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    driver_input.custom_minimum_size.y = 46.0*sc
    driver_input.max_length = DRIVER.MAX_LENGTH
    driver_input.text = DRIVER.get_name()
    driver_input.placeholder_text = "DRIVER NAME"
    driver_input.text_submitted.connect(func(value: String) -> void:
        driver_input.text = DRIVER.set_name(value))
    driver_input.focus_exited.connect(func() -> void:
        driver_input.text = DRIVER.set_name(driver_input.text))
    driver_row.add_child(driver_input)
    add_child(driver_row)
    for spec in [["engine","ENGINE"],["tyres","TYRES"],["fx","EFFECTS"],["music","MUSIC"]]:
        add_child(_volume_row(str(spec[0]),str(spec[1])))
    var accent_label := Label.new()
    accent_label.text = "ACCENT COLOUR"
    accent_label.add_theme_color_override("font_color",STYLE.MUTED)
    accent_label.add_theme_font_size_override("font_size",int(15.0*sc))
    add_child(accent_label)
    var row := HBoxContainer.new()
    row.name = "Accent swatches"
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation",int(10.0*sc))
    add_child(row)
    for accent in STYLE.ACCENT_ORDER:
        var sw := Button.new()
        sw.name = "Accent "+accent
        sw.tooltip_text = accent.to_upper()
        sw.custom_minimum_size = Vector2(50.0,50.0)*sc
        var selected: bool = accent == STYLE.accent_name
        for state in ["normal","hover","pressed","focus"]:
            sw.add_theme_stylebox_override(state,_swatch_box(STYLE.ACCENTS[accent],selected))
        sw.pressed.connect(choose_accent.bind(accent))
        row.add_child(sw)

static func volume(group: String) -> float:
    match group:
        "engine": return STYLE.vol_engine
        "tyres": return STYLE.vol_tyres
        "music": return STYLE.vol_music
    return STYLE.vol_fx

func set_volume(group: String, value: float) -> void:
    var v: float = clampf(value,0.0,1.0)
    match group:
        "engine": STYLE.vol_engine = v
        "tyres": STYLE.vol_tyres = v
        "music": STYLE.vol_music = v
        _: STYLE.vol_fx = v
    STYLE.save_settings()
    if sliders.has(group):
        var pct: Label = (sliders[group] as Dictionary)["label"]
        pct.text = "%d%%" % int(round(v*100.0))

func _volume_row(group: String, title: String) -> Control:
    var row := HBoxContainer.new()
    row.name = "Volume "+group
    row.add_theme_constant_override("separation",int(10.0*sc))
    var name_label := Label.new()
    name_label.text = title
    name_label.custom_minimum_size.x = 130.0*sc
    name_label.add_theme_font_override("font",STYLE.BOLD)
    name_label.add_theme_font_size_override("font_size",int(17.0*sc))
    row.add_child(name_label)
    var slider := HSlider.new()
    slider.name = "Slider "+group
    slider.min_value = 0.0
    slider.max_value = 100.0
    slider.step = 5.0
    slider.value = round(volume(group)*100.0)
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    slider.custom_minimum_size.y = 40.0*sc
    _style_slider(slider)
    row.add_child(slider)
    var pct := Label.new()
    pct.custom_minimum_size.x = 64.0*sc
    pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    pct.text = "%d%%" % int(round(volume(group)*100.0))
    pct.add_theme_color_override("font_color",STYLE.MUTED)
    pct.add_theme_font_size_override("font_size",int(16.0*sc))
    row.add_child(pct)
    slider.value_changed.connect(func(v: float) -> void: set_volume(group,v/100.0))
    sliders[group] = {"slider":slider,"label":pct}
    return row

func _style_slider(slider: HSlider) -> void:
    var track := StyleBoxFlat.new()
    track.bg_color = Color(1,1,1,0.12)
    track.set_corner_radius_all(int(4.0*sc))
    track.content_margin_top = 4.0*sc
    track.content_margin_bottom = 4.0*sc
    var fill := StyleBoxFlat.new()
    fill.bg_color = STYLE.PINK
    fill.set_corner_radius_all(int(4.0*sc))
    fill.content_margin_top = 4.0*sc
    fill.content_margin_bottom = 4.0*sc
    slider.add_theme_stylebox_override("slider",track)
    slider.add_theme_stylebox_override("grabber_area",fill)
    slider.add_theme_stylebox_override("grabber_area_highlight",fill)
    var knob: ImageTexture = _knob(int(26.0*sc))
    slider.add_theme_icon_override("grabber",knob)
    slider.add_theme_icon_override("grabber_highlight",knob)

static func _knob(n: int) -> ImageTexture:
    var img := Image.create(n,n,false,Image.FORMAT_RGBA8)
    img.fill(Color(0,0,0,0))
    var c: float = (float(n)-1.0)*0.5
    for y in range(n):
        for x in range(n):
            var d: float = Vector2(x-c,y-c).length()
            if d <= c:
                var edge: float = clampf(c-d,0.0,1.0)
                img.set_pixel(x,y,Color(0.96,0.96,0.98,edge) if d < c-2.0 else Color(STYLE.PINK.r,STYLE.PINK.g,STYLE.PINK.b,edge))
    return ImageTexture.create_from_image(img)

func _swatch_box(colour: Color, selected: bool) -> StyleBoxFlat:
    var b := StyleBoxFlat.new()
    b.bg_color = colour
    b.set_corner_radius_all(int(25.0*sc))
    b.border_color = Color.WHITE if selected else Color(0,0,0,0.55)
    b.set_border_width_all(int((4.0 if selected else 2.0)*sc))
    b.shadow_color = Color(colour.r,colour.g,colour.b,0.55 if selected else 0.0)
    b.shadow_size = int(10.0*sc) if selected else 0
    return b

func _refresh_sound() -> void:
    sound_button.text = "SOUND  ON" if STYLE.sound_on else "SOUND  OFF"
    STYLE.style_button(sound_button,sc,STYLE.sound_on)

func toggle_sound() -> void:
    STYLE.set_sound(not STYLE.sound_on)
    STYLE.save_settings()
    _refresh_sound()

func choose_accent(accent: String) -> void:
    STYLE.set_accent(accent)
    STYLE.save_settings()
    accent_changed.emit(accent)
