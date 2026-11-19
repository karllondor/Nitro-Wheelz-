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
    if main != ["DRIVE","GARAGE","TRACK BUILDER","SETTINGS"]:
        _fail("Main page must be DRIVE / GARAGE / TRACK BUILDER / SETTINGS, got "+str(main))
        return
    if menu.find_child("Diagnostics",true,false) != null:
        _fail("Developer tools must not be on the main page")
        return
    menu.call("show_page","drive")
    await process_frame
    for id in ["shin_kawa_v2","shin_kawa_full_circuit","benchmark_oval","benchmark_sweepers","random"]:
        if menu.find_child("Track "+id,true,false) == null:
            _fail("DRIVE page missing track: "+id)
            return
    menu.call("show_page","build")
    await process_frame
    for n in ["Builder 3D","Editor nodes","Generate"]:
        if menu.find_child(n,true,false) == null:
            _fail("TRACK BUILDER page missing: "+n)
            return
    menu.call("show_page","settings")
    await process_frame
    var panel: Node = menu.find_child("Settings panel",true,false)
    if panel == null or panel.find_child("Slider engine",true,false) == null or panel.find_child("Accent swatches",true,false) == null:
        _fail("SETTINGS page must hold the shared settings panel")
        return
    menu.call("show_page","dev")
    await process_frame
    if menu.find_child("Diagnostics",true,false) == null:
        _fail("Controller diagnostics must live under DEVELOPER")
        return
    menu.queue_free()
    await process_frame
    print("PASS: main menu DRIVE / GARAGE / TRACK BUILDER / SETTINGS, track list, builder tools, settings panel, developer section")
    print("NOT RUN: thumb reach and readability on the owner's phone")
    quit(0)

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)
