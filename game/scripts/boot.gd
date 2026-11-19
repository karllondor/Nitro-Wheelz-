extends Control
const STYLE = preload("res://scripts/ui/hud_style.gd")
const RESULTS = preload("res://scripts/ui/race_results.gd")
const DNA = preload("res://scripts/world/track_dna.gd")
const SETTINGS = preload("res://scripts/ui/settings_panel.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const SYNTH = preload("res://scripts/audio/engine_synth.gd")
const LAST_SAVED: String = "user://nitro_editor_last_path.txt"
## Player main menu (owner audit P2): four clear choices — DRIVE, GARAGE,
## TRACK BUILDER, SETTINGS — each opening its own page; tools for testing
## (controller diagnostics) live under DEVELOPER. Portrait-first sizes,
## focusable buttons for controllers.
const TRACKS: Array = [
    ["SHIN-KAWA","res://tracks/shin_kawa_v2.json","shin_kawa_v2"],
    ["SHIN-KAWA • FULL CIRCUIT","res://tracks/shin_kawa_full_circuit.json","shin_kawa_full_circuit"],
    ["OVAL","res://tracks/benchmark_oval.json","benchmark_oval"],
    ["SWEEPERS","res://tracks/benchmark_sweepers.json","benchmark_sweepers"]]

var ui_unit: float = 1.0
var page: VBoxContainer
var page_name: String = ""
var status_label: Label

func _ready() -> void:
    STYLE.ensure_settings()
    var s: Vector2 = get_viewport_rect().size
    var portrait: bool = s.y > s.x
    ui_unit = clampf(s.x/700.0,1.0,2.2) if portrait else 1.0
    theme = STYLE.screen_theme(ui_unit)
    var background := ColorRect.new()
    background.color = Color(0.016,0.014,0.024)
    add_child(background)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var center := CenterContainer.new()
    add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var column := VBoxContainer.new()
    column.custom_minimum_size = Vector2(s.x*(0.83 if portrait else 0.42),0)
    column.add_theme_constant_override("separation",int(12*ui_unit))
    center.add_child(column)
    # Brand artwork derived from user-supplied graffiti logo.
    var logo := TextureRect.new()
    logo.name = "Nitro Wheelz Graffiti Crown Logo"
    logo.texture = load("res://assets/brand/nitro_wheelz_logo.svg") as Texture2D
    logo.custom_minimum_size = Vector2(s.x*0.70,s.y*(0.17 if portrait else 0.22))
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(logo)
    page = VBoxContainer.new()
    page.name = "Menu page"
    page.add_theme_constant_override("separation",int(12*ui_unit))
    column.add_child(page)
    status_label = Label.new()
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.add_theme_font_size_override("font_size",int(16*ui_unit))
    status_label.add_theme_color_override("font_color",Color(1.0,0.45,0.45))
    column.add_child(status_label)
    var stamp := Label.new()
    stamp.text = "NITRO WHEELZ v"+str(ProjectSettings.get_setting("application/config/version","unknown"))
    stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stamp.add_theme_font_size_override("font_size",int(15*ui_unit))
    stamp.add_theme_color_override("font_color",STYLE.DIM)
    column.add_child(stamp)
    show_page("main")

func _clear_page() -> void:
    for child in page.get_children():
        page.remove_child(child)
        child.queue_free()
    status_label.text = ""

func show_page(which: String) -> void:
    _clear_page()
    page_name = which
    match which:
        "drive": _drive_page()
        "build": _build_page()
        "settings": _settings_page()
        "dev": _dev_page()
        _: _main_page()
    for child in page.get_children():
        if child is Button:
            (child as Button).grab_focus()
            break

func _main_page() -> void:
    var drive: Button = _big("DRIVE",func(): show_page("drive"),true)
    drive.name = "DRIVE"
    _big("GARAGE",func(): _go("res://scenes/garage.tscn")).name = "GARAGE"
    _big("TRACK BUILDER",func(): show_page("build")).name = "TRACK BUILDER"
    _big("SETTINGS",func(): show_page("settings")).name = "SETTINGS"
    var hint := Label.new()
    hint.text = "JOYSTICK • GAS • BRAKE • HANDBRAKE\nCAM switches camera  •  PAUSE opens settings"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size",int(16*ui_unit))
    hint.add_theme_color_override("font_color",STYLE.MUTED)
    page.add_child(hint)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation",int(12*ui_unit))
    page.add_child(row)
    var dev := _small("DEVELOPER",func(): show_page("dev"))
    page.remove_child(dev)
    row.add_child(dev)
    if not OS.has_feature("mobile"):
        var quit := _small("QUIT",func(): get_tree().quit())
        page.remove_child(quit)
        row.add_child(quit)

func _drive_page() -> void:
    _title("CHOOSE A TRACK")
    for t in TRACKS:
        var best: int = _best(str(t[2]))
        var label: String = str(t[0])+("\nBEST %s PTS" % RESULTS.points(best) if best > 0 else "\nNO RUN YET")
        var b: Button = _big(label,_race.bind(str(t[1])))
        b.name = "Track "+str(t[2])
    var mine: String = _last_custom_track()
    if not mine.is_empty():
        var checked: Dictionary = DNA.read_track(mine)
        if bool(checked.get("ok",false)):
            _big("MY TRACK • "+str(checked.get("track_name","CUSTOM")).to_upper(),_race.bind(mine)).name = "Track custom"
    _big("RANDOM TRACK",_random_track).name = "Track random"
    _small("◀  BACK",func(): show_page("main"))

func _build_page() -> void:
    _title("TRACK BUILDER")
    _big("BUILD • 3D TILES\nTAP TO LAY ROAD",func(): _go("res://scenes/track_builder.tscn")).name = "Builder 3D"
    _big("EDIT NODES\nSHAPE ANY CIRCUIT",func(): _go("res://scenes/track_editor.tscn")).name = "Editor nodes"
    _big("GENERATE & DRIVE\nRANDOM VALID LOOP",_random_track).name = "Generate"
    _small("◀  BACK",func(): show_page("main"))

func _settings_page() -> void:
    _title("SETTINGS")
    var panel: NitroSettingsPanel = SETTINGS.new()
    panel.name = "Settings panel"
    page.add_child(panel)
    panel.build(ui_unit,false)
    panel.accent_changed.connect(func(_a: String) -> void:
        theme = STYLE.screen_theme(ui_unit)
        call_deferred("show_page","settings"))
    _small("◀  BACK",func(): show_page("main"))

func _dev_page() -> void:
    _title("DEVELOPER")
    _big("CONTROLLER DIAGNOSTICS",func(): _go("res://scenes/dev/input_monitor.tscn")).name = "Diagnostics"
    # Way back to the old handling: every car on the Lada baseline physics.
    var forced: bool = CARS.baseline_physics_forced()
    var phys: Button = _big("BASELINE PHYSICS FOR ALL CARS: "+("ON" if forced else "OFF"),func():
        CARS.set_baseline_physics_forced(not CARS.baseline_physics_forced())
        show_page("dev"))
    phys.name = "Baseline physics"
    STYLE.style_button(phys,ui_unit,forced)
    # Audio comparison: engine synth alone vs synth + recorded effects.
    var synth_only: bool = load("res://scripts/audio/drive_audio.gd").audio_mode() == "synth"
    var mode_b: Button = _big("AUDIO: "+("SYNTH ONLY" if synth_only else "SYNTH + RECORDED FX"),func():
        load("res://scripts/audio/drive_audio.gd").set_audio_mode("recorded" if synth_only else "synth")
        show_page("dev"))
    mode_b.name = "Audio mode"
    var dbg_on: bool = load("res://scripts/ui/audio_debug_overlay.gd").enabled()
    var dbg_b: Button = _big("AUDIO DEBUG OVERLAY: "+("ON" if dbg_on else "OFF"),func():
        load("res://scripts/ui/audio_debug_overlay.gd").set_enabled(not dbg_on)
        show_page("dev"))
    dbg_b.name = "Audio debug"
    STYLE.style_button(dbg_b,ui_unit,dbg_on)
    var bench_label := Label.new()
    bench_label.name = "Benchmark result"
    bench_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bench_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    bench_label.add_theme_font_size_override("font_size",int(16*ui_unit))
    bench_label.add_theme_color_override("font_color",STYLE.MUTED)
    _big("AUDIO BENCHMARK",func(): bench_label.text = audio_benchmark()).name = "Audio benchmark"
    page.add_child(bench_label)
    var info := Label.new()
    info.text = "Godot %s  •  %s renderer" % [Engine.get_version_info().get("string",""),
        str(ProjectSettings.get_setting("rendering/renderer/rendering_method","?"))]
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.add_theme_font_size_override("font_size",int(15*ui_unit))
    info.add_theme_color_override("font_color",STYLE.MUTED)
    page.add_child(info)
    _small("◀  BACK",func(): show_page("main"))

# ------------------------------------------------------------------ helpers

## CPU cost of the engine synth for each car profile on THIS device.
func audio_benchmark() -> String:
    var lines: PackedStringArray = []
    for v in ["red","blue"]:
        var ms: float = SYNTH.benchmark(CARS.engine(v),1.0)
        lines.append("%s: %.1f ms per second of audio (%.1f%% of one core)" % [
            str(CARS.engine(v).get("layout","?")),ms,ms/10.0])
    return "\n".join(lines)

func _title(txt: String) -> void:
    var l := Label.new()
    l.text = txt
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.add_theme_font_override("font",STYLE.BOLD)
    l.add_theme_font_size_override("font_size",int(26*ui_unit))
    l.add_theme_color_override("font_color",STYLE.WHITE)
    page.add_child(l)

func _big(caption: String, action: Callable, primary: bool = false) -> Button:
    var b := Button.new()
    b.text = caption
    var two_lines: bool = caption.contains("\n")
    b.custom_minimum_size.y = (86.0 if two_lines else 74.0)*ui_unit
    b.add_theme_font_size_override("font_size",int((21.0 if two_lines else 26.0)*ui_unit))
    STYLE.style_button(b,ui_unit,primary)
    b.pressed.connect(action)
    page.add_child(b)
    return b

func _small(caption: String, action: Callable) -> Button:
    var b := Button.new()
    b.text = caption
    b.custom_minimum_size = Vector2(170.0,52.0)*ui_unit
    b.add_theme_font_size_override("font_size",int(17.0*ui_unit))
    STYLE.style_button(b,ui_unit)
    b.pressed.connect(action)
    page.add_child(b)
    return b

func _best(track_id: String) -> int:
    var best: int = 0
    for run in RESULTS.track_runs(track_id):
        best = maxi(best,int((run as Dictionary).get("score",0)))
    return best

func _last_custom_track() -> String:
    if not FileAccess.file_exists(LAST_SAVED):
        return ""
    var path: String = FileAccess.get_file_as_string(LAST_SAVED).strip_edges()
    return path if path.begins_with("user://") and FileAccess.file_exists(path) else ""

func _race(track_path: String) -> void:
    ProjectSettings.set_setting("nitro/selected_track",track_path)
    _go("res://scenes/race.tscn")

func _random_track() -> void:
    # Never start a race with an unvalidated corridor.
    var creator: Variant = load("res://scripts/world/track_generator.gd").new()
    var result: Dictionary = creator.generate(Time.get_ticks_usec())
    if bool(result.get("ok",false)):
        _race(str(result["path"]))
    else:
        status_label.text = "GENERATION FAILED: "+str(result.get("error","unknown"))

func _go(scene: String) -> void:
    get_tree().change_scene_to_file(scene)
