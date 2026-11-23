extends SceneTree
## User-visible regressions at the editor/road and lap/event boundaries (#33).
const EDITOR = preload("res://scenes/track_editor.tscn")
const RACE = preload("res://scenes/race.tscn")
const DNA = preload("res://scripts/world/track_dna.gd")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const CAT = preload("res://scripts/world/terrain/terrain_catalog.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const SOURCE = "res://tracks/shin_kawa_v2.json"
const TRACK = "user://qa33_seam.json"
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, msg: String) -> void:
    if not ok:
        failures.append(msg)

func _run() -> void:
    var editor = EDITOR.instantiate()
    root.add_child(editor)
    var marker = editor.LAST_SAVED
    var had_marker := FileAccess.file_exists(marker)
    var old_marker := FileAccess.get_file_as_string(marker) if had_marker else ""
    editor._load_path(SOURCE,"SHIN-KAWA")
    var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    var expected: Array = original.widths_m.duplicate()
    print("OPEN: expected max width ",expected.max()," m, actual ",editor.data.get("widths_m",[editor.data.width_m]).max()," m")
    check(editor.preview.halfwidths == DNA.compile(original).halfwidths,"OPEN changed Shin-Kawa road edges")
    editor.selected = 4
    editor._set_start()
    editor._reverse()
    var reordered: Array = []
    for i in range(expected.size()):
        reordered.append(expected[posmod(4-i,expected.size())])
    var saved := bool(editor._persist_track("QA33 preserved width profile"))
    check(saved,"SAVE AS failed")
    if saved:
        var path: String = editor.last_saved_path
        editor._load_path(path)
        check(editor.data.get("widths_m",[]) == reordered,"OPEN/SET START/REVERSE/SAVE AS/reopen lost knot widths")
        check(DNA.read_track(path).halfwidths == editor.preview.halfwidths,"editor/race width mismatch")
        editor.selected = 0
        editor._add_point()
        var extended: Array = reordered.duplicate()
        extended.insert(1,0.5*(float(reordered[0])+float(reordered[1])))
        check(editor.data.get("widths_m",[]) == extended,"inserted node lost width")
        editor._delete_point()
        check(editor.data.get("widths_m",[]) == reordered,"delete failed to preserve surviving widths")
        DirAccess.remove_absolute(path)
    if had_marker:
        var file := FileAccess.open(marker,FileAccess.WRITE)
        file.store_string(old_marker)
        file.close()
    elif FileAccess.file_exists(marker):
        DirAccess.remove_absolute(marker)
    editor.free()

    var desc: Dictionary = CAT.descriptor("pl_ojcow",621727,-1,"club")
    desc.road_style = "road"
    var gen: Dictionary = TT.generate_loop(TT.new_grid(),FIELD.new("pl_ojcow",621727),desc,3)
    if not gen.ok:
        printerr("FAIL: Ojców fixture did not generate")
        quit(1)
        return
    var track_file := FileAccess.open(TRACK,FileAccess.WRITE)
    track_file.store_string(JSON.stringify(gen.data,"",false,true))
    track_file.close()
    ProjectSettings.set_setting("nitro/selected_track",TRACK)
    var race = RACE.instantiate()
    root.add_child(race)
    race.set_physics_process(false)
    var count: int = race.track.event_layout.zones.size()
    check(count>0,"expected Club zones")
    # Start the clock, then roll a few metres behind the start with the actual car.
    Input.action_press("throttle")
    race._physics_process(1.0/120)
    Input.action_release("throttle")
    for frame in range(930):
        race._physics_process(1.0/120)
    Input.action_press("brake")
    for frame in range(120):
        race._physics_process(1.0/120)
    Input.action_release("brake")
    print("reverse: lap ",race.lap,", progress ",race.last_progress,", missed ",race.judge.missed,"/",count)
    check(race.last_progress>0.95,"reverse control did not cross the start")
    check(race.judge.missed==0 and race.judge.potential==0,"backing over start consumed Club sectors")
    Input.action_press("throttle")
    for frame in range(180):
        race._physics_process(1.0/120)
    Input.action_release("throttle")
    print("return: lap ",race.lap,", progress ",race.last_progress,", splits ",race.lap_splits.size())
    check(race.last_progress<0.05,"forward control did not recross the start")
    check(race.lap==1 and race.lap_splits.is_empty(),"start-line shuffle credited a lap")
    race.free()
    DirAccess.remove_absolute(TRACK)
    if failures.is_empty():
        print("PASS: editor preserves variable road edges and a start-line shuffle consumes no laps or Club sectors")
    else:
        printerr("FAIL: ",failures)
    quit(0 if failures.is_empty() else 1)
