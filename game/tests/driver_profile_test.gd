extends SceneTree
## Owner decision 2026-11-22 (issue #23): a local driver name and a TOP RUNS table
## with the columns DRIVER | CAR | STARS | TIME | POINTS (selective port from PR #15,
## not merged).
##  * the driver name is cleaned (spaces collapsed, <= 16 characters, DRIVER when
##    empty) and saved locally; SETTINGS has the field and saves it;
##  * every new run stores the driver and the exact car; older runs without them
##    stay UNKNOWN (never backfilled with the current car); the run's rank / points
##    logic is unchanged (v0.1.32 record ids still work);
##  * the table's columns are in the owner's order and the screen still fits;
##  * local device history only: nothing here talks to a network.
const DRIVER = preload("res://scripts/player/driver_profile.gd")
const RESULTS = preload("res://scripts/ui/race_results.gd")
const PANEL = preload("res://scripts/ui/settings_panel.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const ID: String = "driver_profile_test_track"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var had_driver := FileAccess.file_exists(DRIVER.PATH)
    var driver_text: String = FileAccess.get_file_as_string(DRIVER.PATH) if had_driver else ""
    var had_runs := FileAccess.file_exists(RESULTS.STORAGE)
    var runs_text: String = FileAccess.get_file_as_string(RESULTS.STORAGE) if had_runs else ""
    var err: String = await _checks()
    _restore(DRIVER.PATH,had_driver,driver_text)
    _restore(RESULTS.STORAGE,had_runs,runs_text)
    if not err.is_empty():
        printerr("FAIL: "+err)
        quit(1)
        return
    print("PASS: driver profile - name cleaned (collapsed spaces, <= 16, DRIVER when empty) and saved locally, SETTINGS field saves it, new runs store driver + exact car, older runs stay UNKNOWN (not backfilled), TOP RUNS columns = DRIVER | CAR | STARS | TIME | POINTS, results screen fits portrait + landscape")
    for _f in range(3):
        await process_frame
    quit(0)

func _restore(path: String, had: bool, text: String) -> void:
    if had:
        var f := FileAccess.open(path,FileAccess.WRITE)
        f.store_string(text)
        f.close()
    elif FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _checks() -> String:
    # Name cleaning + persistence.
    if DRIVER.clean("   karll    londor  ") != "karll londor" or DRIVER.clean("") != "DRIVER" or DRIVER.clean("\n\t ") != "DRIVER":
        return "Driver name cleaning (collapsed spaces / empty = DRIVER)"
    if DRIVER.clean("ABCDEFGHIJKLMNOPQRSTUVWXYZ").length() != DRIVER.MAX_LENGTH:
        return "Driver name must be at most %d characters" % DRIVER.MAX_LENGTH
    if DRIVER.set_driver_name("  QA  Driver ") != "QA Driver" or DRIVER.get_driver_name() != "QA Driver":
        return "Driver name must be saved and read back cleaned"
    # SETTINGS field.
    var panel: NitroSettingsPanel = PANEL.new()
    root.add_child(panel)
    panel.build(1.0,false)
    await process_frame
    var row: Node = panel.find_child("Driver name",true,false)
    var input: LineEdit = panel.find_child("Driver input",true,false) as LineEdit
    if row == null or input == null or input.text != "QA Driver" or input.max_length != DRIVER.MAX_LENGTH:
        return "SETTINGS must have a DRIVER field with the saved name"
    input.text = "  Zed   one "
    input.text_submitted.emit(input.text)
    if DRIVER.get_driver_name() != "Zed one" or input.text != "Zed one":
        return "Submitting the SETTINGS field must save the cleaned name"
    panel.queue_free()
    await process_frame
    # Runs: new ones carry the driver and car; old ones stay unknown.
    var legacy: Array = [{"track_id":ID,"seconds":70.0,"score":3000,"stars":2,"date":"2026-11-19T10:00:00"}]
    var f := FileAccess.open(RESULTS.STORAGE,FileAccess.WRITE)
    f.store_string(JSON.stringify(legacy))
    f.close()
    DRIVER.set_driver_name("KARLL")
    CARS.select("blue")
    if not RESULTS.save_run(ID,61.5,7100,3,[],"2026-11-22T09:00:00"):
        return "save_run failed"
    if not RESULTS.save_run(ID,64.0,6900,2,[],"2026-11-22T09:05:00","Guest","e30"):
        return "save_run (explicit driver / car) failed"
    var stored: Array = RESULTS.track_runs(ID)
    var seen_legacy: bool = false
    var seen_mine: bool = false
    var seen_guest: bool = false
    for r in stored:
        var run: Dictionary = r
        if str(run["date"]) == "2026-11-19T10:00:00":
            seen_legacy = not run.has("driver") and not run.has("car")
        elif str(run["date"]) == "2026-11-22T09:00:00":
            seen_mine = str(run.get("driver","")) == "KARLL" and str(run.get("car","")) == "blue"
        elif str(run["date"]) == "2026-11-22T09:05:00":
            seen_guest = str(run.get("driver","")) == "Guest" and str(run.get("car","")) == "e30"
    if not seen_legacy:
        return "An older run must stay without driver / car (UNKNOWN), never backfilled with the current car"
    if not seen_mine or not seen_guest:
        return "New runs must store the driver and the exact car"
    var sm: Dictionary = RESULTS.summarize(ID,"QA",61.5,7100,3,[legacy[0]],stored,"2026-11-22T09:00:00",{})
    if int(sm["rank"]) != 1 or str((sm["this_run"] as Dictionary).get("driver","")) != "KARLL":
        return "Ranking by points must be unchanged and this_run must carry the driver"
    # Column order.
    var want: Array[String] = ["#","DRIVER","CAR","STARS","TIME","POINTS"]
    if RESULTS.TOP_RUN_COLUMNS != want:
        return "TOP RUNS columns must read # | DRIVER | CAR | STARS | TIME | POINTS (got %s)" % str(RESULTS.TOP_RUN_COLUMNS)
    # The screen with these rows fits portrait + landscape.
    var view: NitroRaceResults = RESULTS.new()
    root.add_child(view)
    view.show_race(ID,"QA",61.5,7100,70.0,func(): pass,func(): pass,{"length_m":700.0})
    await process_frame
    for screen in [Vector2(720,1600),Vector2(1280,720),Vector2(1080,1920)]:
        var lay: Dictionary = view.layout(screen)
        for key in lay.keys():
            if lay[key] is Rect2 and not Rect2(Vector2.ZERO,screen).encloses(lay[key]):
                return "Results section '%s' leaves the screen %s" % [key,str(screen)]
    view.queue_free()
    await process_frame
    return ""
