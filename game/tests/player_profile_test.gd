extends SceneTree
## v0.1.35 (owner request 2026-11-22, issue #24): player card + one RACE SETUP flow.
##  * length rules: a player name has 2 .. 14 characters (letters incl. Polish,
##    digits, space - _ . '), every catalog car label has at most 14; the TOP RUNS
##    table puts POINTS flush right and a 14-character name / car label fits;
##  * avatar: skin / hair / style / t-shirt cycle through their palettes and are
##    always in range, saved locally;
##  * progress: the tracks driven (only ones that can still be loaded) with the
##    best time / points / stars, total stars = the best stars per track summed;
##  * the first-launch WELCOME page asks for a name (CONTINUE only with a valid
##    one) and saves it; the main menu shows the player chip;
##  * the flow: DRIVE -> RACE SETUP (track + car + DRIVE); a track pick returns to
##    the page it was opened from (setup or garage), it never starts the race;
##    setup CAR opens the garage and BACK returns to setup; the garage has a TRACK
##    button (track list, then back to the garage); a profile track goes to setup.
const PROFILE = preload("res://scripts/player/driver_profile.gd")
const PROGRESS = preload("res://scripts/player/player_progress.gd")
const RESULTS = preload("res://scripts/ui/race_results.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")
const BOOT = preload("res://scripts/boot.gd")

func _initialize() -> void:
    call_deferred("_run")

func _read(path: String) -> Variant:
    return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null

func _restore(path: String, text: Variant) -> void:
    if text != null:
        var f := FileAccess.open(path,FileAccess.WRITE)
        f.store_string(str(text))
        f.close()
    elif FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _run() -> void:
    var keep_profile: Variant = _read(PROFILE.PATH)
    var keep_runs: Variant = _read(RESULTS.STORAGE)
    var keep_garage: Variant = _read(CARS.GARAGE_PATH)
    var keep_track: Variant = ProjectSettings.get_setting("nitro/selected_track","")
    var err: String = await _checks()
    _restore(PROFILE.PATH,keep_profile)
    _restore(RESULTS.STORAGE,keep_runs)
    _restore(CARS.GARAGE_PATH,keep_garage)
    ProjectSettings.set_setting("nitro/selected_track",keep_track)
    for k in ["boot_page","track_return","garage_return"]:
        ProjectSettings.set_setting("nitro/"+k,"main" if k == "boot_page" else ("setup" if k == "track_return" else "main"))
    if not err.is_empty():
        printerr("FAIL: "+err)
        quit(1)
        return
    print("PASS: player card - name 2..14 characters (Polish letters kept, junk dropped), every car label <= 14, TOP RUNS points flush right with a 14-character name / car fitting, avatar palettes cycle + saved, progress rows (only loadable tracks, best time / points / stars, total stars), WELCOME asks for a name, DRIVE -> RACE SETUP -> track list / garage -> back, garage has a TRACK button, profile track -> setup")
    for _f in range(3):
        await process_frame
    quit(0)

func _boot() -> Control:
    var b: Control = (load("res://scenes/boot.tscn") as PackedScene).instantiate()
    b.set("navigate_enabled",false)
    root.add_child(b)
    await process_frame
    return b

func _find_button(b: Control, node_name: String) -> Button:
    return b.find_child(node_name,true,false) as Button

func _checks() -> String:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE.PATH))
    # ---- length rules
    if PROFILE.MIN_LENGTH != 2 or PROFILE.MAX_LENGTH != 14 or PROFILE.CAR_LABEL_MAX != 14:
        return "Limits must be name 2..14 and car label <= 14"
    for v in CARS.ORDER:
        if str(CARS.info(v)["short"]).length() > PROFILE.CAR_LABEL_MAX:
            return "Car label '%s' is longer than %d characters" % [str(CARS.info(v)["short"]),PROFILE.CAR_LABEL_MAX]
    if PROFILE.clean("Zażółć Gęślą") != "Zażółć Gęślą" or PROFILE.clean("A😀B") != "AB" or PROFILE.clean("  x   y  ") != "x y":
        return "Name cleaning (Polish letters kept, emoji dropped, spaces collapsed)"
    if PROFILE.clean("ABCDEFGHIJKLMNOPQRSTUVWXYZ").length() != 14 or PROFILE.clean("###") != "DRIVER":
        return "Name length 14 / empty -> DRIVER"
    if PROFILE.is_valid_input("A") or PROFILE.is_valid_input("  ") or PROFILE.is_valid_input("😀😀") or not PROFILE.is_valid_input("Ola"):
        return "A name needs at least 2 usable characters"
    # ---- table layout
    for width in [900.0,960.0,1000.0]:
        var c: Dictionary = RESULTS.top_run_columns(width)
        if absf(float(c["points"])+float(c["points_w"])-(width-24.0)) > 0.01:
            return "POINTS must sit flush right (width %.0f)" % width
        var order: Array = [float(c["rank"])+46.0,float(c["driver"]),float(c["driver"])+float(c["driver_w"]),float(c["car"]),
            float(c["car"])+float(c["car_w"]),float(c["stars"]),float(c["stars"])+float(c["stars_w"]),float(c["time"]),
            float(c["time"])+float(c["time_w"]),float(c["points"])]
        for i in range(order.size()-1):
            if float(order[i]) > float(order[i+1])+0.01:
                return "TOP RUNS columns overlap at width %.0f (%s)" % [width,str(order)]
        if float(c["driver_w"]) < float(c["car_w"]):
            return "DRIVER must get at least as much room as CAR"
        # A 14-character name and every real car label must stay readable.
        var dsize: float = STYLE.fit_size("ABCDEFGHIJKLMN",26.0,float(c["driver_w"]),true)
        if dsize < 17.0:
            return "A 14-character name shrinks to %.1f px at width %.0f" % [dsize,width]
        for v2 in CARS.ORDER:
            var csize: float = STYLE.fit_size(str(CARS.info(v2)["short"]),22.0,float(c["car_w"]),false)
            if csize < 17.0:
                return "Car label '%s' shrinks to %.1f px at width %.0f" % [str(CARS.info(v2)["short"]),csize,width]
    # ---- avatar
    var look: Dictionary = PROFILE.avatar()
    for part in ["skin","hair","shirt","style"]:
        var size: int = PROFILE.HAIR_STYLES.size() if part == "style" else PROFILE.palette(part).size()
        var first: int = int(PROFILE.avatar()[part])
        var seen: Dictionary = {}
        for k in range(size):
            seen[int(PROFILE.cycle_avatar(part)[part])] = true
        if seen.size() != size or int(PROFILE.avatar()[part]) != first:
            return "Avatar part '%s' must cycle through all %d choices and wrap" % [part,size]
    var cfg := ConfigFile.new()
    cfg.load(PROFILE.PATH)
    cfg.set_value("avatar","skin",99)
    cfg.set_value("avatar","style",-5)
    cfg.save(PROFILE.PATH)
    if int(PROFILE.avatar()["skin"]) != PROFILE.SKIN.size()-1 or int(PROFILE.avatar()["style"]) != 0:
        return "A corrupted avatar value must be clamped into range"
    # ---- progress
    var runs: Array = [
        {"track_id":"t_a","seconds":70.0,"score":5000,"stars":1,"date":"2026-11-20T10:00:00"},
        {"track_id":"t_a","seconds":64.5,"score":9000,"stars":3,"date":"2026-11-21T10:00:00"},
        {"track_id":"t_b","seconds":80.0,"score":3000,"stars":2,"date":"2026-11-22T10:00:00"},
        {"track_id":"t_deleted","seconds":60.0,"score":1000,"stars":3,"date":"2026-11-22T11:00:00"}]
    var rf := FileAccess.open(RESULTS.STORAGE,FileAccess.WRITE)
    rf.store_string(JSON.stringify(runs))
    rf.close()
    var known: Array = [{"id":"t_a","name":"TRACK A","path":"res://tracks/benchmark_oval.json"},
        {"id":"t_b","name":"TRACK B","path":"res://tracks/benchmark_sweepers.json"},{"id":"t_none","name":"NEVER DRIVEN","path":"x"}]
    var rows: Array = PROGRESS.rows(known)
    if rows.size() != 2 or str(rows[0]["id"]) != "t_b" or str(rows[1]["id"]) != "t_a":
        return "Progress rows: only loadable driven tracks, newest first (%s)" % str(rows)
    if absf(float(rows[1]["best_seconds"])-64.5) > 0.001 or int(rows[1]["best_points"]) != 9000 or int(rows[1]["best_stars"]) != 3 or int(rows[1]["runs"]) != 2:
        return "Best time / points / stars of a track"
    if PROGRESS.total_stars(rows) != 5:
        return "Total stars = best stars per track summed (got %d)" % PROGRESS.total_stars(rows)
    if PROGRESS.star_text(2) != "★★☆":
        return "Star text"
    # ---- welcome
    var b: Control = await _boot()
    b.call("show_page","welcome")
    var input: LineEdit = b.find_child("Welcome name",true,false) as LineEdit
    var go: Button = _find_button(b,"Welcome continue")
    if input == null or go == null or not go.disabled:
        return "WELCOME needs a name field and a disabled CONTINUE"
    input.text = "A"
    input.text_changed.emit("A")
    if not go.disabled:
        return "One character must not enable CONTINUE"
    input.text = "Ola K"
    input.text_changed.emit("Ola K")
    if go.disabled:
        return "A valid name must enable CONTINUE"
    go.pressed.emit()
    if not PROFILE.has_profile() or PROFILE.get_driver_name() != "Ola K" or str(b.get("page_name")) != "main":
        return "CONTINUE must save the name and open the main menu"
    if b.find_child("PROFILE",true,false) == null or b.find_child("Avatar",true,false) == null:
        return "The main menu needs the player chip (avatar + name + stars)"
    # ---- DRIVE -> setup -> track list -> pick returns to setup (never starts the race)
    _find_button(b,"DRIVE").pressed.emit()
    if str(b.get("page_name")) != "setup" or _find_button(b,"Setup track") == null or _find_button(b,"Setup car") == null or _find_button(b,"Setup drive") == null:
        return "DRIVE must open RACE SETUP with TRACK, CAR and DRIVE"
    _find_button(b,"Setup track").pressed.emit()
    if str(b.get("page_name")) != "drive" or str(ProjectSettings.get_setting("nitro/track_return","")) != "setup":
        return "The setup TRACK button must open the track list that returns to setup"
    var oval: Button = _find_button(b,"Track benchmark_oval")
    if oval == null:
        return "The track list must list the built-in circuits"
    oval.pressed.emit()
    if str(b.get("page_name")) != "setup" or str(ProjectSettings.get_setting("nitro/selected_track","")) != "res://tracks/benchmark_oval.json":
        return "Picking a track must select it and return to RACE SETUP"
    if str(b.get("last_scene")).ends_with("race.tscn"):
        return "Picking a track must not start the race"
    if PROFILE.last_track() != "res://tracks/benchmark_oval.json":
        return "The picked track must be remembered for the next launch"
    _find_button(b,"Setup car").pressed.emit()
    if not str(b.get("last_scene")).ends_with("garage.tscn") or str(ProjectSettings.get_setting("nitro/garage_return","")) != "setup":
        return "The setup CAR button must open the garage that returns to setup"
    # ---- profile
    b.call("show_page","profile")
    var pname: LineEdit = b.find_child("Player name",true,false) as LineEdit
    if pname == null or pname.text != "Ola K" or pname.max_length != 14:
        return "The profile page must show the editable name (max 14)"
    var skin_before: int = int(PROFILE.avatar()["skin"])
    _find_button(b,"Look skin").pressed.emit()
    if int(PROFILE.avatar()["skin"]) != (skin_before+1) % PROFILE.SKIN.size():
        return "SKIN must cycle the avatar"
    var stars_l: Label = b.find_child("Total stars",true,false) as Label
    if stars_l == null or not stars_l.text.contains("★"):
        return "The profile page must show the total stars"
    var driven: Button = _find_button(b,"Driven t_a")
    if driven != null:
        driven.pressed.emit()   # only when t_a is a known track (it is not: ids are real ones)
    # Use a real record id: the built-in oval.
    var oval_runs: Array = [{"track_id":"benchmark_oval","seconds":59.0,"score":4000,"stars":2,"date":"2026-11-22T12:00:00"}]
    var rf2 := FileAccess.open(RESULTS.STORAGE,FileAccess.WRITE)
    rf2.store_string(JSON.stringify(oval_runs))
    rf2.close()
    b.call("show_page","profile")
    var d2: Button = _find_button(b,"Driven benchmark_oval")
    if d2 == null or not d2.text.contains("0:59.00") or not d2.text.contains("4,000"):
        return "A driven track must be listed with its best time and points (text: %s)" % (d2.text if d2 != null else "missing")
    ProjectSettings.set_setting("nitro/selected_track","res://tracks/shin_kawa_v2.json")
    d2.pressed.emit()
    if str(b.get("page_name")) != "setup" or str(ProjectSettings.get_setting("nitro/selected_track","")) != "res://tracks/benchmark_oval.json":
        return "Tapping a driven track must load it and continue to RACE SETUP (then the garage entry for the car)"
    b.queue_free()
    await process_frame
    # ---- a scene change asks the menu for a start page
    ProjectSettings.set_setting("nitro/boot_page","setup")
    var b2: Control = await _boot()
    if str(b2.get("page_name")) != "setup" or str(ProjectSettings.get_setting("nitro/boot_page","")) != "main":
        return "nitro/boot_page must open that page once"
    b2.queue_free()
    await process_frame
    # ---- garage
    var garage: Control = (load("res://scenes/garage.tscn") as PackedScene).instantiate()
    garage.set("navigate_enabled",false)
    root.add_child(garage)
    await process_frame
    var tb: Button = garage.find_child("Garage track",true,false) as Button
    if tb == null or not tb.text.contains(BOOT.track_label(BOOT.current_track())):
        return "The garage needs a TRACK button showing the selected track"
    tb.pressed.emit()
    if not str(garage.get("last_scene")).ends_with("boot.tscn") or str(ProjectSettings.get_setting("nitro/track_return","")) != "garage" \
            or str(ProjectSettings.get_setting("nitro/boot_page","")) != "drive":
        return "The garage TRACK button must open the track list that returns to the garage"
    ProjectSettings.set_setting("nitro/garage_return","setup")
    (garage.find_child("Garage back",true,false) as Button).pressed.emit()
    if str(ProjectSettings.get_setting("nitro/boot_page","")) != "setup":
        return "Garage BACK must return to where it was opened from"
    (garage.find_child("Garage drive",true,false) as Button).pressed.emit()
    if not str(garage.get("last_scene")).ends_with("race.tscn"):
        return "Garage DRIVE must start the race on the selected track"
    garage.queue_free()
    await process_frame
    return ""
