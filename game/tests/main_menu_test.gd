extends SceneTree
## Player main menu (owner audit P2): DRIVE / GARAGE / TRACK BUILDER /
## SETTINGS, track list under DRIVE, tools under DEVELOPER, settings panel
## with volumes, no developer tools on the first page.
const BOOT = preload("res://scenes/boot.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _names(menu: Node) -> Array[String]:
    var out: Array[String] = []
    var page: Node = menu.find_child("Menu page",true,false)
    for child in page.get_children():
        if child is Button:
            out.append(str(child.name))
    return out

func _run() -> void:
    var menu: Control = BOOT.instantiate()
    root.add_child(menu)
    await process_frame
    var main: Array[String] = _names(menu)
    if main != ["DRIVE","PARK","LOCAL MULTIPLAYER","GARAGE","TRACK BUILDER","SETTINGS"]:
        _fail("Main page must be DRIVE / PARK / LOCAL MULTIPLAYER / GARAGE / TRACK BUILDER / SETTINGS, got "+str(main))
        return
    if menu.find_child("Diagnostics",true,false) != null:
        _fail("Developer tools must not be on the main page")
        return
    # A player track saved on the device (as the editor writes it).
    var qa: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tracks/benchmark_oval.json"))
    qa["id"] = "custom_qa_menu_track"
    qa["name"] = "QA Menu Track"
    var qf: FileAccess = FileAccess.open("user://nitro_track_qa_menu_track.json",FileAccess.WRITE)
    qf.store_string(JSON.stringify(qa,"  ",false,true))
    qf.close()
    menu.call("show_page","drive")
    await process_frame
    for id in ["shin_kawa_v2","shin_kawa_full_circuit","benchmark_oval","benchmark_sweepers","random"]:
        if menu.find_child("Track "+id,true,false) == null:
            _fail("DRIVE page missing track: "+id)
            return
    # Built-in circuits and the player's own tracks are separate sections.
    var circuits: Node = menu.find_child("Section CIRCUITS",true,false)
    var mine: Node = menu.find_child("Section MY TRACKS",true,false)
    var row: Node = menu.find_child("My track custom_qa_menu_track",true,false)
    if circuits == null or mine == null or row == null or row.find_child("Edit custom_qa_menu_track",true,false) == null:
        _fail("DRIVE must list saved tracks under MY TRACKS with an EDIT button")
        return
    if not (circuits.get_index() < menu.find_child("Track benchmark_oval",true,false).get_index() \
            and menu.find_child("Track benchmark_sweepers",true,false).get_index() < mine.get_index() \
            and mine.get_index() < row.get_index()):
        _fail("Saved tracks must come after the built-in circuits, in their own section")
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://nitro_track_qa_menu_track.json"))
    menu.call("show_page","build")
    await process_frame
    for n in ["Builder 3D","Editor nodes","Generate"]:
        if menu.find_child(n,true,false) == null:
            _fail("TRACK BUILDER page missing: "+n)
            return
    menu.call("show_page","settings")
    await process_frame
    var panel: Node = menu.find_child("Settings panel",true,false)
    if panel == null or panel.find_child("Slider music",true,false) == null:
        _fail("SETTINGS needs a MUSIC volume slider")
        return
    if not ResourceLoader.exists("res://assets/music/night_drift.ogg") or root.get_node_or_null("Music") == null:
        _fail("Background music track / Music autoload missing")
        return
    if panel == null or panel.find_child("Slider engine",true,false) == null or panel.find_child("Accent swatches",true,false) == null:
        _fail("SETTINGS page must hold the shared settings panel")
        return
    menu.call("show_page","dev")
    await process_frame
    if menu.find_child("Diagnostics",true,false) == null:
        _fail("Controller diagnostics must live under DEVELOPER")
        return
    if menu.find_child("Audio debug",true,false) == null:
        _fail("DEVELOPER needs the audio debug overlay switch")
        return
    if menu.find_child("Audio mode",true,false) != null:
        _fail("The recorded-SFX audio mode switch was removed with the recordings")
        return
    if menu.find_child("Baseline physics",true,false) == null or menu.find_child("Audio benchmark",true,false) == null:
        _fail("DEVELOPER needs the baseline-physics switch and the audio benchmark")
        return
    var report: String = menu.call("audio_benchmark")
    # v0.1.36: the Lada engine is the 13B rotary (was an I4); the benchmark lists the engines of the cars.
    if not report.contains("ROTARY") or not report.contains("V8") or not report.contains("ms per second"):
        _fail("Audio benchmark must report both engines: "+report)
        return
    menu.queue_free()
    await process_frame
    print("PASS: main menu DRIVE / GARAGE / TRACK BUILDER / SETTINGS, track list, builder tools, settings panel, developer section")
    print("NOT RUN: thumb reach and readability on the owner's phone")
    quit(0)

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)
