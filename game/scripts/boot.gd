extends Control
const STYLE = preload("res://scripts/ui/hud_style.gd")
const RESULTS = preload("res://scripts/ui/race_results.gd")
const DNA = preload("res://scripts/world/track_dna.gd")
const SETTINGS = preload("res://scripts/ui/settings_panel.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const SYNTH = preload("res://scripts/audio/engine_synth.gd")
const LAST_SAVED: String = "user://nitro_editor_last_path.txt"
const PHYS_DEV = preload("res://scripts/world/terrain/physics_dev.gd")
const TERRAIN_TRACK = preload("res://scripts/world/terrain/terrain_track.gd")
const PROFILE = preload("res://scripts/player/driver_profile.gd")
const PROGRESS = preload("res://scripts/player/player_progress.gd")
const PARK_LAYOUT = preload("res://scripts/park/park_layout.gd")
const PARK_PROGRESS = preload("res://scripts/park/park_progress.gd")
const PARK_TUTORIAL = preload("res://scripts/park/park_tutorial.gd")
const AVATAR = preload("res://scripts/ui/avatar.gd")
const EDIT_TOOLS = preload("res://scripts/world/track_edit_tools.gd")
## v0.1.35 flow (owner: "garage: no track, track: no car" was confusing): ONE
## RACE SETUP page (track + car + DRIVE) joins the track list and the garage.
##   main DRIVE -> setup;  setup TRACK -> track list (pick -> back to setup);
##   setup CAR -> garage (back -> setup);  garage TRACK -> track list (pick ->
##   back to the garage);  profile track -> setup (then the garage for the car).
## Scene changes remember where to land via ProjectSettings:
##   nitro/boot_page    first page of the menu after the scene loads (consumed);
##   nitro/track_return "setup" | "garage": where a picked track goes next;
##   nitro/garage_return "main" | "setup": the garage's BACK target.
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
## Tests / tools: do not really change scene; the request is recorded instead.
var navigate_enabled: bool = true
var last_scene: String = ""

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
    var start: String = str(ProjectSettings.get_setting("nitro/boot_page","main"))
    ProjectSettings.set_setting("nitro/boot_page","main")
    # First launch (real game only): ask for the player's name before anything else.
    if get_tree().get_script() == null and not PROFILE.has_profile():
        start = "welcome"
    show_page(start)

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
        "setup": _setup_page()
        "park": _park_page()
        "profile": _profile_page()
        "welcome": _welcome_page()
        "build": _build_page()
        "settings": _settings_page()
        "dev": _dev_page()
        "elev": _elevation_page()
        _: _main_page()
    for child in page.get_children():
        if child is Button:
            (child as Button).grab_focus()
            break

func _main_page() -> void:
    _profile_chip()
    var drive: Button = _big("DRIVE",func(): show_page("setup"),true)
    drive.name = "DRIVE"
    _big("NITRO WHEELZ PARK",func(): show_page("park")).name = "PARK"
    _big("LOCAL MULTIPLAYER",func(): _go("res://scenes/multiplayer_lobby.tscn")).name = "LOCAL MULTIPLAYER"
    _big("GARAGE",func(): _open_garage("main")).name = "GARAGE"
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

## DRIVE: built-in CIRCUITS first, then MY TRACKS (every track the player
## saved from the editor or the 3D builder, newest first, each with its best
## score and an EDIT button) - clearly separated, scrolls when long.
func _drive_page() -> void:
    _title("CHOOSE A TRACK")
    var list: VBoxContainer = _scroll_list()
    _section(list,"CIRCUITS")
    for t in TRACKS:
        var best: int = _best(str(t[2]))
        var label: String = str(t[0])+("\nBEST %s PTS" % RESULTS.points(best) if best > 0 else "\nNO RUN YET")
        var b: Button = _big(label,_pick_track.bind(str(t[1])))
        b.name = "Track "+str(t[2])
        _move(b,list)
    var mine: Array[Dictionary] = saved_tracks()
    _section(list,"MY TRACKS" if not mine.is_empty() else "MY TRACKS • none yet: TRACK BUILDER")
    for t in mine:
        var row := HBoxContainer.new()
        row.name = "My track "+str(t["id"])
        row.add_theme_constant_override("separation",int(10*ui_unit))
        list.add_child(row)
        var best2: int = _best(str(t["id"]))
        var label2: String = "★ %s • %d m\n%s" % [str(t["name"]).to_upper(),int(t["length"]),
            "BEST %s PTS" % RESULTS.points(best2) if best2 > 0 else "NO RUN YET"]
        var drive: Button = _big(label2,_pick_track.bind(str(t["path"])))
        drive.name = "Track custom"
        drive.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        # Player tracks are framed in the accent colour (built-ins neutral).
        STYLE.style_button(drive,ui_unit,true)
        _move(drive,row)
        var edit_b: Button = _small("EDIT",_edit_track.bind(str(t["path"])))
        edit_b.name = "Edit "+str(t["id"])
        edit_b.custom_minimum_size = Vector2(120.0,86.0)*ui_unit
        _move(edit_b,row)
    _section(list,"QUICK")
    _move(_big("RANDOM TRACK",_random_track),list).name = "Track random"
    _small("◀  BACK",_leave_track_list).name = "Back"

## Every valid player track on this device: [{path, id, name, length, time}].
static func saved_tracks() -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    for f in DirAccess.get_files_at("user://"):
        if not (f.begins_with("nitro_track_") and f.ends_with(".json")):
            continue
        var path: String = "user://"+f
        var c: Dictionary = DNA.read_track(path)
        if not bool(c.get("ok",false)):
            continue
        out.append({"path":path,"id":str(c["track_id"]),"name":str(c["track_name"]),
            "length":float(c["length_metres"]),"time":FileAccess.get_modified_time(path)})
    out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["time"]) > int(b["time"]))
    return out

func _edit_track(path: String) -> void:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
    if raw is Dictionary and not TERRAIN_TRACK.world_of(raw).is_empty() and not EDIT_TOOLS.node_shaped(raw):
        # Terrain-first tracks reopen in the terrain builder (same world); a circuit shaped in the node editor
        # (v0.1.42, keeps its landscape) reopens in the node editor.
        ProjectSettings.set_setting("nitro/terrain_edit_track",path)
        _go("res://scenes/terrain_builder.tscn")
        return
    var f: FileAccess = FileAccess.open(LAST_SAVED,FileAccess.WRITE)
    if f != null:
        f.store_string(path)
        f.close()
    _go("res://scenes/track_editor.tscn")

func _scroll_list() -> VBoxContainer:
    var scroll := ScrollContainer.new()
    scroll.name = "Track list"
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.custom_minimum_size.y = get_viewport_rect().size.y*0.56
    page.add_child(scroll)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation",int(12*ui_unit))
    scroll.add_child(list)
    return list

func _section(parent: Node, txt: String) -> void:
    var l := Label.new()
    l.name = "Section "+txt
    l.text = txt
    l.add_theme_font_override("font",STYLE.BOLD)
    l.add_theme_font_size_override("font_size",int(17*ui_unit))
    l.add_theme_color_override("font_color",STYLE.PINK_SOFT if txt.begins_with("MY") else STYLE.MUTED)
    parent.add_child(l)

func _move(node: Control, parent: Node) -> Control:
    node.get_parent().remove_child(node)
    parent.add_child(node)
    return node

func _build_page() -> void:
    _title("TRACK BUILDER")
    _big("TERRAIN BUILDER\nCOUNTRY • LANDSCAPE • ROAD",func(): _go("res://scenes/terrain_builder.tscn"),true).name = "Terrain builder"
    _big("BUILD • 3D TILES\nTAP TO LAY ROAD",func(): _go("res://scenes/track_builder.tscn")).name = "Builder 3D"
    _big("EDIT NODES\nSHAPE ANY CIRCUIT",func():
        ProjectSettings.set_setting("nitro/editor_open_latest",true)
        _go("res://scenes/track_editor.tscn")).name = "Editor nodes"
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
    # v0.1.38 (owner decision 2026-11-22, #25): the physics mode used by the NEXT race. ARCADE_PLUS
    # (default) = the approved arcade handling with credible top speeds; REAL_POWER_TEST = a power-curve
    # drivetrain with game-shifted gears for a same-car A/B test. Runs in REAL_POWER_TEST are not saved.
    var pmode: String = CARS.physics_mode()
    var real_on: bool = pmode == CARS.MODE_REAL_POWER
    var mode_b: Button = _big("ACTIVE PHYSICS MODE:\n"+pmode+(" (DEFAULT)" if not real_on else "  •  RUNS NOT SAVED")+"\nAPPLIES TO THE NEXT RACE • TAP TO SWITCH",func():
        CARS.set_physics_mode(CARS.MODE_ARCADE_PLUS if CARS.physics_mode() == CARS.MODE_REAL_POWER else CARS.MODE_REAL_POWER)
        show_page("dev"))
    mode_b.name = "Physics mode"
    STYLE.style_button(mode_b,ui_unit,real_on)
    # Way back to the old handling: every car on the Lada baseline physics.
    var forced: bool = CARS.baseline_physics_forced()
    var phys: Button = _big("BASELINE PHYSICS FOR ALL CARS: "+("ON" if forced else "OFF"),func():
        CARS.set_baseline_physics_forced(not CARS.baseline_physics_forced())
        show_page("dev"))
    phys.name = "Baseline physics"
    STYLE.style_button(phys,ui_unit,forced)
    # v0.1.34: the Car Factory GLB models are the normal player-visible cars;
    # this switch shows the earlier procedural Lada / RYU-32 for comparison
    # (looks only, saves untouched).
    var fac: bool = CARS.factory_test_models()
    var fac_b: Button = _big("CAR FACTORY GLB CARS: "+("ON" if fac else "OFF")+"\nDEFAULT ON • OFF = EARLIER PROCEDURAL LADA / RYU-32",func():
        CARS.set_factory_test_models(not CARS.factory_test_models())
        show_page("dev"))
    fac_b.name = "Factory test models"
    STYLE.style_button(fac_b,ui_unit,not fac)
    var dbg_on: bool = load("res://scripts/ui/audio_debug_overlay.gd").enabled()
    var dbg_b: Button = _big("AUDIO DEBUG OVERLAY: "+("ON" if dbg_on else "OFF"),func():
        load("res://scripts/ui/audio_debug_overlay.gd").set_enabled(not dbg_on)
        show_page("dev"))
    dbg_b.name = "Audio debug"
    STYLE.style_button(dbg_b,ui_unit,dbg_on)
    # Issue #20: strength of the foliage sway (trees); lets a phone test tell wind
    # from any other movement. DEFAULT 1.0 / HALF 0.5 / OFF 0.0.
    var wind: float = float(load("res://scripts/dev_settings.gd").get_value("developer","vegetation_wind",1.0))
    var wind_steps: Array = [1.0,0.5,0.0]
    var wind_names: Array = ["DEFAULT","HALF","OFF"]
    var wind_i: int = 0
    for wi in range(wind_steps.size()):
        if absf(float(wind_steps[wi])-wind) < 0.01:
            wind_i = wi
    var wind_b: Button = _big("VEGETATION WIND: "+str(wind_names[wind_i])+"\nTREE SWAY • TERRAIN TRACKS",func():
        load("res://scripts/dev_settings.gd").set_value("developer","vegetation_wind",float(wind_steps[(wind_i+1)%wind_steps.size()]))
        show_page("dev"))
    wind_b.name = "Vegetation wind"
    STYLE.style_button(wind_b,ui_unit,wind_i != 0)
    _big("ELEVATION PHYSICS ▶\nTERRAIN TRACKS",func(): show_page("elev")).name = "Elevation physics"
    # v0.1.32 mobile QA: touch / hitbox / input-order / FPS / wheel-angle
    # overlay in the Track Builder and the race.
    var td_on: bool = load("res://scripts/ui/touch_diagnostics.gd").enabled()
    var td_b: Button = _big("TOUCH DIAGNOSTICS: "+("ON" if td_on else "OFF")+"\nTOUCH IDS • HITBOXES • FPS • WHEELS",func():
        load("res://scripts/ui/touch_diagnostics.gd").set_enabled(not td_on)
        show_page("dev"))
    td_b.name = "Touch diagnostics"
    STYLE.style_button(td_b,ui_unit,td_on)
    # Issue #16: hide ONE visual layer of the car in a race so a phone test can
    # tell which layer draws a black shape during the first drift.
    var layers: Array = ["off","smoke","skid","shadow","wheels"]
    var hidden: String = str(load("res://scripts/dev_settings.gd").get_value("developer","hide_layer","off"))
    if not layers.has(hidden):
        hidden = "off"
    var iso_b: Button = _big("DRIFT LAYER ISOLATION: "+("OFF" if hidden == "off" else "HIDE "+hidden.to_upper())+"\nTYRE SMOKE • SKID MARKS • CONTACT SHADOW • WHEELS",func():
        var next: String = str(layers[(layers.find(hidden)+1)%layers.size()])
        load("res://scripts/dev_settings.gd").set_value("developer","hide_layer",next)
        show_page("dev"))
    iso_b.name = "Drift layer isolation"
    STYLE.style_button(iso_b,ui_unit,hidden != "off")
    var dev_info := Label.new()
    dev_info.name = "Developer preset info"
    dev_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    dev_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dev_info.add_theme_font_size_override("font_size",int(15*ui_unit))
    dev_info.add_theme_color_override("font_color",STYLE.MUTED)
    dev_info.text = "Developer options are stored apart from your game settings."
    _big("RESET DEVELOPER DEFAULTS",func():
        load("res://scripts/dev_settings.gd").reset_defaults()
        show_page("dev")).name = "Developer reset"
    _big("EXPORT DEVELOPER PRESET",func():
        var path: String = load("res://scripts/dev_settings.gd").export_preset()
        dev_info.text = "Saved %s (also copied to the clipboard)" % ProjectSettings.globalize_path(path)).name = "Developer export"
    page.add_child(dev_info)
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

## DEVELOPER > ELEVATION PHYSICS (terrain tracks only; flat tracks never
## change). Local setting, switchable at any time, no regeneration.
func _elevation_page() -> void:
    _title("ELEVATION PHYSICS")
    var s: Dictionary = PHYS_DEV.load_settings()
    var grade: int = int(s["grade_force"])
    var g: Button = _big("GRADE FORCE: %d %%" % grade,func():
        PHYS_DEV.set_value("grade_force",PHYS_DEV.next_grade(int(PHYS_DEV.load_settings()["grade_force"])))
        show_page("elev"))
    g.name = "Grade force"
    STYLE.style_button(g,ui_unit,grade > 0)
    for item in [["camera_pitch","CAMERA PITCH"],["banking","BANKING / BODY ROLL"],["suspension","SUSPENSION (VISUAL)"],
            ["telemetry","TELEMETRY OVERLAY"]]:
        var key: String = str(item[0])
        var on: bool = bool(s[key])
        var b: Button = _big("%s: %s" % [str(item[1]),"ON" if on else "OFF"],func():
            PHYS_DEV.set_value(key,not bool(PHYS_DEV.load_settings()[key]))
            show_page("elev"))
        b.name = str(item[1])
        STYLE.style_button(b,ui_unit,on)
    var smooth: bool = str(s["grounding"]) == "smooth"
    var gr: Button = _big("GROUNDING: %s" % ("SMOOTH" if smooth else "SNAP"),func():
        PHYS_DEV.set_value("grounding","snap" if str(PHYS_DEV.load_settings()["grounding"]) == "smooth" else "smooth")
        show_page("elev"))
    gr.name = "Grounding"
    var note := Label.new()
    note.text = "0 % = the flat arcade handling. Grade force adds g·sin(slope) along the road; the other switches are visual or readouts."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.add_theme_font_size_override("font_size",int(14*ui_unit))
    note.add_theme_color_override("font_color",STYLE.MUTED)
    page.add_child(note)
    _small("◀  BACK",func(): show_page("dev"))

# ------------------------------------------------------------------ helpers

## CPU cost of the engine synth for each car profile on THIS device.
func audio_benchmark() -> String:
    var lines: PackedStringArray = []
    for v in ["red","blue"]:
        var ms: float = SYNTH.benchmark(CARS.engine(v),1.0)
        lines.append("%s: %.1f ms per second of audio (%.1f%% of one core)" % [
            str(CARS.engine(v).get("layout","?")),ms,ms/10.0])
    return "\n".join(lines)

# ------------------------------------------------- v0.1.35 profile + flow

## Every track that can be loaded again: built-in circuits + MY TRACKS.
func _known_tracks() -> Array:
    var out: Array = []
    for t in TRACKS:
        out.append({"id":str(t[2]),"name":str(t[0]),"path":str(t[1])})
    for t2 in saved_tracks():
        out.append({"id":str(t2["id"]),"name":str(t2["name"]).to_upper(),"path":str(t2["path"])})
    return out

## The track DRIVE would start now: this session's pick, else the last one the
## player chose (saved), else SHIN-KAWA.
static func current_track() -> String:
    var chosen: String = str(ProjectSettings.get_setting("nitro/selected_track",""))
    if chosen == "":
        chosen = PROFILE.last_track()
    if chosen == PARK_LAYOUT.TRACK_PATH:
        # the Park is a place of its own, never "the track you last raced"
        chosen = PROFILE.last_track()
    if chosen == "" or not FileAccess.file_exists(chosen) or chosen == PARK_LAYOUT.TRACK_PATH:
        chosen = "res://tracks/shin_kawa_v2.json"
    return chosen

## Display name of a track file ("RANDOM TRACK" for a generated one).
static func track_label(path: String) -> String:
    for t in TRACKS:
        if str(t[1]) == path:
            return str(t[0])
    for t2 in saved_tracks():
        if str(t2["path"]) == path:
            return str(t2["name"]).to_upper()
    return "RANDOM TRACK"

func _current_track() -> String:
    return current_track()

func _track_info(path: String) -> Dictionary:
    for t in _known_tracks():
        if str(t["path"]) == path:
            return t
    return {"id":"","name":"RANDOM TRACK","path":path}

func _pick_track(path: String) -> void:
    ProjectSettings.set_setting("nitro/selected_track",path)
    PROFILE.set_last_track(path)
    _after_track_pick()

func _after_track_pick() -> void:
    var back: String = str(ProjectSettings.get_setting("nitro/track_return","setup"))
    ProjectSettings.set_setting("nitro/track_return","setup")
    if back == "garage":
        _go("res://scenes/garage.tscn")
    else:
        show_page("setup")

func _leave_track_list() -> void:
    var back: String = str(ProjectSettings.get_setting("nitro/track_return","setup"))
    ProjectSettings.set_setting("nitro/track_return","setup")
    if back == "garage":
        _go("res://scenes/garage.tscn")
    else:
        show_page("setup")

func _open_garage(from_page: String) -> void:
    ProjectSettings.set_setting("nitro/garage_return",from_page)
    _go("res://scenes/garage.tscn")

func _open_track_list(from: String) -> void:
    ProjectSettings.set_setting("nitro/track_return",from)
    show_page("drive")

## The profile picture + name + stars at the top of the main menu (opens the card).
func _profile_chip() -> void:
    var row := HBoxContainer.new()
    row.name = "Player chip"
    row.add_theme_constant_override("separation",int(12*ui_unit))
    page.add_child(row)
    var av: NitroAvatar = AVATAR.new()
    av.name = "Avatar"
    av.custom_minimum_size = Vector2(86,86)*ui_unit
    av.set_look(PROFILE.avatar())
    row.add_child(av)
    var stars: int = PROGRESS.total_stars(PROGRESS.rows(_known_tracks()))
    var chip: Button = _big("%s\n%s %d" % [PROFILE.get_driver_name().to_upper(),"★",stars]+" STARS",func(): show_page("profile"))
    chip.name = "PROFILE"
    chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _move(chip,row)

## RACE SETUP: the one place where track, car and DRIVE meet.
func _setup_page() -> void:
    _title("YOUR RACE")
    var path: String = _current_track()
    var info: Dictionary = _track_info(path)
    var best: int = _best(str(info["id"])) if str(info["id"]) != "" else 0
    var track_b: Button = _big("TRACK  ▸  %s\n%s" % [str(info["name"]),("BEST %s PTS" % RESULTS.points(best)) if best > 0 else "NO RUN YET"],
        func(): _open_track_list("setup"))
    track_b.name = "Setup track"
    var car: String = CARS.selected()
    var cinfo: Dictionary = CARS.info(car)
    var car_b: Button = _big("CAR  ▸  %s\n%s • TAP TO CHANGE" % [str(cinfo["short"]),str(cinfo["paint"])],func(): _open_garage("setup"))
    car_b.name = "Setup car"
    var go: Button = _big("DRIVE",_race.bind(path),true)
    go.name = "Setup drive"
    _small("◀  BACK",func(): show_page("main")).name = "Back"

## NITRO WHEELZ PARK (issue #27): ONE open pavement, two ways in. START TUTORIAL = the
## guided lessons (resumes where you stopped); FREE DRIVE = the same pavement with no
## lessons, no gates, no scoring - skip the tutorial any time, also later in the pause menu.
func _park_page() -> void:
    _title("NITRO WHEELZ PARK")
    var lead := Label.new()
    lead.text = "ONE BIG OPEN PAVEMENT\nDonuts • figure-eights • a long eight • orange cones that never stop you"
    lead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    lead.add_theme_font_size_override("font_size",int(17*ui_unit))
    lead.add_theme_color_override("font_color",STYLE.MUTED)
    page.add_child(lead)
    var total: int = PARK_TUTORIAL.LESSONS.size()
    var done: int = PARK_PROGRESS.completed().size()
    var label: String = "START TUTORIAL" if done == 0 else ("CONTINUE TUTORIAL  %d / %d" % [mini(done,total),total])
    var tut: Button = _big(label,_start_park.bind("tutorial"),true)
    tut.name = "Park tutorial"
    if done > 0:
        _big("RESTART TUTORIAL",func(): ProjectSettings.set_setting("nitro/park_reset",true); _start_park("tutorial")).name = "Park tutorial restart"
    _big("FREE DRIVE  •  SKIP TUTORIAL",_start_park.bind("free")).name = "Park free drive"
    var car: String = CARS.selected()
    var cinfo: Dictionary = CARS.info(car)
    _big("CAR  ▸  %s\n%s • TAP TO CHANGE" % [str(cinfo["short"]),str(cinfo["paint"])],func(): _open_garage("park")).name = "Park car"
    _small("◀  BACK",func(): show_page("main")).name = "Back"

## Start the Park in "tutorial" or "free" mode (the same race scene, same pavement).
func _start_park(mode: String) -> void:
    ProjectSettings.set_setting("nitro/park_mode",mode)
    _race(PARK_LAYOUT.TRACK_PATH)

## PLAYER CARD: avatar, name, stars, tracks driven (tap = load it, then pick a car).
func _profile_page() -> void:
    _title("PLAYER CARD")
    var head := HBoxContainer.new()
    head.name = "Card head"
    head.add_theme_constant_override("separation",int(14*ui_unit))
    page.add_child(head)
    var av: NitroAvatar = AVATAR.new()
    av.name = "Avatar"
    av.custom_minimum_size = Vector2(150,150)*ui_unit
    av.set_look(PROFILE.avatar())
    head.add_child(av)
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_theme_constant_override("separation",int(8*ui_unit))
    head.add_child(col)
    var name_in := LineEdit.new()
    name_in.name = "Player name"
    name_in.text = PROFILE.get_driver_name()
    name_in.max_length = PROFILE.MAX_LENGTH
    name_in.placeholder_text = "YOUR NAME"
    name_in.custom_minimum_size.y = 52.0*ui_unit
    name_in.add_theme_font_size_override("font_size",int(24*ui_unit))
    _style_input(name_in)
    name_in.text_submitted.connect(func(v: String) -> void:
        if PROFILE.is_valid_input(v):
            name_in.text = PROFILE.set_driver_name(v))
    name_in.focus_exited.connect(func() -> void:
        if PROFILE.is_valid_input(name_in.text):
            name_in.text = PROFILE.set_driver_name(name_in.text)
        else:
            name_in.text = PROFILE.get_driver_name())
    col.add_child(name_in)
    var rows: Array = PROGRESS.rows(_known_tracks())
    var stars_l := Label.new()
    stars_l.name = "Total stars"
    stars_l.text = "★ %d STARS  •  %d TRACKS" % [PROGRESS.total_stars(rows),rows.size()]
    stars_l.add_theme_font_override("font",STYLE.BOLD)
    stars_l.add_theme_font_size_override("font_size",int(20*ui_unit))
    stars_l.add_theme_color_override("font_color",STYLE.GOLD)
    col.add_child(stars_l)
    # Look: each button cycles one part of the character.
    var look := HBoxContainer.new()
    look.name = "Look"
    look.add_theme_constant_override("separation",int(8*ui_unit))
    page.add_child(look)
    for part in [["skin","SKIN"],["hair","HAIR"],["style","STYLE"],["shirt","T-SHIRT"]]:
        var lb := Button.new()
        lb.name = "Look "+str(part[0])
        lb.text = str(part[1])
        lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        lb.custom_minimum_size.y = 56.0*ui_unit
        lb.add_theme_font_size_override("font_size",int(17*ui_unit))
        STYLE.style_button(lb,ui_unit)
        lb.pressed.connect(func(): av.set_look(PROFILE.cycle_avatar(str(part[0]))))
        look.add_child(lb)
    var list: VBoxContainer = _scroll_list()
    _section(list,"TRACKS DRIVEN  •  TAP TO DRIVE AGAIN" if not rows.is_empty() else "NO TRACK DRIVEN YET")
    for r in rows:
        var row: Dictionary = r
        var label: String = "%s\n%s   %s  •  %s PTS" % [str(row["name"]),PROGRESS.star_text(int(row["best_stars"])),
            RESULTS.clock(float(row["best_seconds"])),RESULTS.points(int(row["best_points"]))]
        var b: Button = _big(label,_pick_track.bind(str(row["path"])))
        b.name = "Driven "+str(row["id"])
        _move(b,list)
    _small("◀  BACK",func(): show_page("main")).name = "Back"

## FIRST LAUNCH: the player card starts with a name.
func _welcome_page() -> void:
    _title("WELCOME, DRIVER")
    var q := Label.new()
    q.text = "WHAT SHOULD WE CALL YOU?"
    q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    q.add_theme_font_size_override("font_size",int(20*ui_unit))
    q.add_theme_color_override("font_color",STYLE.MUTED)
    page.add_child(q)
    var input := LineEdit.new()
    input.name = "Welcome name"
    input.max_length = PROFILE.MAX_LENGTH
    input.placeholder_text = "YOUR NAME"
    input.alignment = HORIZONTAL_ALIGNMENT_CENTER
    input.custom_minimum_size.y = 64.0*ui_unit
    input.add_theme_font_size_override("font_size",int(28*ui_unit))
    _style_input(input)
    page.add_child(input)
    var hint := Label.new()
    hint.text = "%d – %d CHARACTERS  •  LETTERS, DIGITS, SPACE\nYOU CAN CHANGE IT AND DRESS YOUR DRIVER IN PROFILE" % [PROFILE.MIN_LENGTH,PROFILE.MAX_LENGTH]
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size",int(15*ui_unit))
    hint.add_theme_color_override("font_color",STYLE.DIM)
    page.add_child(hint)
    var go: Button = _big("CONTINUE",func(): _confirm_welcome(input),true)
    go.name = "Welcome continue"
    go.disabled = true
    input.text_changed.connect(func(v: String) -> void: go.disabled = not PROFILE.is_valid_input(v))
    input.text_submitted.connect(func(_v: String) -> void: _confirm_welcome(input))
    _focus_later(input)

## A readable text field in the menu style (glass fill, accent border, white text).
func _style_input(le: LineEdit) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.07,0.06,0.11)
    normal.border_color = STYLE.PINK_SOFT
    normal.set_border_width_all(maxi(2,int(2.0*ui_unit)))
    normal.set_corner_radius_all(int(12.0*ui_unit))
    normal.content_margin_left = 14.0*ui_unit
    normal.content_margin_right = 14.0*ui_unit
    le.add_theme_stylebox_override("normal",normal)
    var focus: StyleBoxFlat = normal.duplicate()
    focus.border_color = STYLE.PINK
    le.add_theme_stylebox_override("focus",focus)
    le.add_theme_color_override("font_color",STYLE.WHITE)
    le.add_theme_color_override("font_placeholder_color",STYLE.DIM)
    le.add_theme_color_override("caret_color",STYLE.PINK)
    le.add_theme_font_override("font",STYLE.BOLD)

func _focus_later(c: Control) -> void:
    await get_tree().process_frame
    if is_instance_valid(c) and c.is_inside_tree():
        c.grab_focus()

func _confirm_welcome(input: LineEdit) -> void:
    if not PROFILE.is_valid_input(input.text):
        status_label.text = "NAME: AT LEAST %d LETTERS OR DIGITS" % PROFILE.MIN_LENGTH
        return
    PROFILE.set_driver_name(input.text)
    show_page("main")

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

func _race(track_path: String) -> void:
    ProjectSettings.set_setting("nitro/selected_track",track_path)
    _go("res://scenes/race.tscn")

func _random_track() -> void:
    # Never start a race with an unvalidated corridor.
    var creator: Variant = load("res://scripts/world/track_generator.gd").new()
    var result: Dictionary = creator.generate(Time.get_ticks_usec())
    if bool(result.get("ok",false)):
        _pick_track(str(result["path"]))
    else:
        status_label.text = "GENERATION FAILED: "+str(result.get("error","unknown"))

func _go(scene: String) -> void:
    last_scene = scene
    if not navigate_enabled:
        return
    if get_tree().get_script() == null and (scene.ends_with("race.tscn") or scene.ends_with("terrain_builder.tscn")):
        # v0.1.27: the loading card appears at once (no frozen menu while
        # the next screen is prepared).
        var b: CanvasLayer = load("res://scripts/ui/busy_overlay.gd").open(self,"LOADING",false,true)
        await get_tree().process_frame
        await get_tree().process_frame
    get_tree().change_scene_to_file(scene)
