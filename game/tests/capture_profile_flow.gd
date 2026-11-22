extends SceneTree
## Issue #24 evidence (developer tool, needs a display):
##   OUT_DIR=/abs/dir xvfb-run -a -s "-screen 0 720x1560x24" godot --path game \
##     --rendering-driver opengl3 --resolution 720x1560 --script res://tests/capture_profile_flow.gd
## Seeds a player card + run history (backs up and restores the local files) and
## captures: WELCOME, main menu with the player chip, RACE SETUP, track list,
## PLAYER CARD, the garage with its TRACK button, and the finish screen table.
const PROFILE = preload("res://scripts/player/driver_profile.gd")
const RESULTS = preload("res://scripts/ui/race_results.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")

func _initialize() -> void:
    call_deferred("_run")

func _shot(out: String, name: String) -> void:
    for i in range(10):
        await process_frame
    root.get_viewport().get_texture().get_image().save_png(out+name+".png")

func _keep(path: String) -> Variant:
    return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null

func _put(path: String, text: Variant) -> void:
    if text != null:
        var f := FileAccess.open(path,FileAccess.WRITE)
        f.store_string(str(text))
        f.close()
    elif FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _run() -> void:
    var out: String = OS.get_environment("OUT_DIR")
    out = (out if out != "" else "user://flow").trim_suffix("/")+"/"
    DirAccess.make_dir_recursive_absolute(out)
    var keep_p: Variant = _keep(PROFILE.PATH)
    var keep_r: Variant = _keep(RESULTS.STORAGE)
    var keep_g: Variant = _keep(CARS.GARAGE_PATH)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE.PATH))
    var runs: Array = [
        {"track_id":"shin_kawa_v2","seconds":71.2,"score":28400,"stars":3,"date":"2026-11-20T10:00:00","driver":"KARLL","car":"e30"},
        {"track_id":"benchmark_oval","seconds":52.9,"score":9068,"stars":2,"date":"2026-11-21T10:00:00","driver":"KARLL","car":"blue"},
        {"track_id":"benchmark_sweepers","seconds":88.4,"score":3100,"stars":1,"date":"2026-11-21T11:00:00","driver":"KARLL","car":"red"}]
    _put(RESULTS.STORAGE,JSON.stringify(runs))
    var b: Control = (load("res://scenes/boot.tscn") as PackedScene).instantiate()
    b.set("navigate_enabled",false)
    root.add_child(b)
    await process_frame
    b.call("show_page","welcome")
    var input: LineEdit = b.find_child("Welcome name",true,false) as LineEdit
    input.text = "Karll"
    input.text_changed.emit("Karll")
    await _shot(out,"flow_1_welcome")
    (b.find_child("Welcome continue",true,false) as Button).pressed.emit()
    PROFILE.cycle_avatar("hair")
    PROFILE.cycle_avatar("shirt")
    PROFILE.cycle_avatar("style")
    b.call("show_page","main")
    await _shot(out,"flow_2_main")
    ProjectSettings.set_setting("nitro/selected_track","res://tracks/shin_kawa_v2.json")
    b.call("show_page","setup")
    await _shot(out,"flow_3_setup")
    b.call("show_page","drive")
    await _shot(out,"flow_4_tracks")
    b.call("show_page","profile")
    await _shot(out,"flow_5_profile")
    b.queue_free()
    await process_frame
    var garage: Control = (load("res://scenes/garage.tscn") as PackedScene).instantiate()
    garage.set("navigate_enabled",false)
    root.add_child(garage)
    await process_frame
    await _shot(out,"flow_6_garage")
    garage.queue_free()
    await process_frame
    CARS.select("blue")
    var view: NitroRaceResults = RESULTS.new()
    root.add_child(view)
    var more: Array = runs.duplicate()
    more.append({"track_id":"shin_kawa_v2","seconds":69.4,"score":19800,"stars":2,"date":"2026-11-21T09:30:00","driver":"A VERY LONG NAM","car":"flame"})
    more.append({"track_id":"shin_kawa_v2","seconds":75.0,"score":12050,"stars":1,"date":"2026-11-21T09:50:00","driver":"ZED ONE","car":"white"})
    _put(RESULTS.STORAGE,JSON.stringify(more))
    view.show_race("shin_kawa_v2","SHIN-KAWA",64.3,25600,70.0,func(): pass,func(): pass,{"length_m":860.0,"laps":[{"time":21.4,"score":8300},{"time":21.5,"score":8700},{"time":21.4,"score":8600}]})
    await _shot(out,"flow_7_results")
    _put(PROFILE.PATH,keep_p)
    _put(RESULTS.STORAGE,keep_r)
    _put(CARS.GARAGE_PATH,keep_g)
    print("FLOW CAPTURED to %s" % ProjectSettings.globalize_path(out))
    quit(0)
