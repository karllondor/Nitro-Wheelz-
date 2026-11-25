extends Node
## Shared checks for the pinned Godot smoke suite and the exported review APK.
signal complete(ok: bool)

const BOOT = preload("res://scenes/boot.tscn")
const EDITOR = preload("res://scenes/track_editor.tscn")
const RACE = preload("res://scenes/race.tscn")
const DNA = preload("res://scripts/world/track_dna.gd")
const LAN = preload("res://scripts/net/net_protocol.gd")
const RESULTS = preload("res://scripts/ui/race_results.gd")
const FIELD = preload("res://scripts/world/terrain/terrain_field.gd")
const TERRAIN = preload("res://scripts/world/terrain/terrain_track.gd")
const MARKER = "user://nitro_editor_last_path.txt"
const CIRCUITS: Dictionary = {
    "driftwood_circuit": 3549.0,
    "testandori_raceway": 1351.0,
    "fuji_speedway_short": 1286.0,
}

var failures: Array[String] = []
var saved_files: Dictionary = {}
var seen_fingerprints: Array[String] = []
var output: String = OS.get_environment("NITRO_CIRCUIT_CAPTURES")
var android: bool = OS.has_feature("android")

func _ready() -> void:
    _run.call_deferred()

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)

func _run() -> void:
    for path in [MARKER, RESULTS.STORAGE, "user://nitro_driver.cfg"]:
        saved_files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
    var previous_scene := get_tree().current_scene as Control
    if previous_scene != null:
        previous_scene.hide()
    var menu = BOOT.instantiate()
    add_child(menu)
    menu.navigate_enabled = false
    var editor = EDITOR.instantiate()
    add_child(editor)
    editor._close_help()
    for id: String in CIRCUITS:
        var path := "res://tracks/"+id+".json"
        var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
        var compiled: Dictionary = DNA.compile(raw)
        if not compiled.ok:
            _check(false,id+" failed validation: "+str(compiled.errors))
            continue
        _check(compiled.track_id == id and compiled.closed,id+" identity or topology")
        _check(absf(compiled.length_metres-CIRCUITS[id]) < CIRCUITS[id]*0.02,id+" length")
        _check(compiled.halfwidths.count(12.0) == compiled.centerline.size(),id+" road width")
        var fingerprint: String = LAN.track_fingerprint(path)
        _check(LAN.track_allowed(path) and fingerprint.length() == 64 and not seen_fingerprints.has(fingerprint),
            id+" LAN identity")
        seen_fingerprints.append(fingerprint)
        print("CIRCUIT ",id," %.3f m" % compiled.length_metres)

        menu.show_page("drive")
        var pick := menu.find_child("Track "+id,true,false) as Button
        if pick == null:
            _check(false,id+" missing DRIVE entry")
            continue
        pick.pressed.emit()
        var launch := menu.page.get_node_or_null("Setup drive") as Button
        if launch == null:
            _check(false,id+" missing race setup")
            continue
        launch.pressed.emit()
        _check(menu.last_scene == RACE.resource_path and menu.current_track() == path,id+" menu selection")
        menu.hide()
        editor.show()
        await _check_editor(editor,id,path,raw,compiled)
        editor.hide()
        await _check_race(id,raw)
    editor.free()
    menu.free()
    for path: String in saved_files:
        if saved_files[path] == null:
            if FileAccess.file_exists(path):
                DirAccess.remove_absolute(path)
        else:
            var restored := FileAccess.open(path,FileAccess.WRITE)
            restored.store_buffer(saved_files[path])
            restored.close()
    if previous_scene != null:
        previous_scene.show()
    var summary := "PASS: three circuits, menu, editor round trip, throttle, laps, records, LAN identity and PRO sectors"
    if not failures.is_empty():
        summary = "FAIL: "+str(failures)
    print(summary)
    if android:
        var verdict := FileAccess.open("user://circuits-verdict.txt",FileAccess.WRITE)
        verdict.store_line(summary)
        verdict.close()
    complete.emit(failures.is_empty())
    queue_free()

func _check_editor(editor, id: String, path: String, raw: Dictionary, compiled: Dictionary) -> void:
    editor._request_open()
    var entry := editor.find_child("Open "+id,true,false) as Button
    if entry == null:
        _check(false,id+" missing editor OPEN entry")
        editor._close_dialog()
        return
    entry.pressed.emit()
    _check(editor.ready_to_play and editor.preview.centerline == compiled.centerline,id+" editor opening")
    var original: Array = raw.control_points
    if raw.has("world"):
        # The exported game opens terrain behind its loading card.
        for frame in range(60):
            if editor.terrain_field != null:
                break
            await get_tree().process_frame
        var world: Dictionary = raw.world
        var evaluation: Dictionary = TERRAIN.evaluate(FIELD.new(world.archetype,world.terrain_seed),raw)
        _check(evaluation.ok and editor.message_label.text.contains("TERRAIN OK"),id+" terrain classification "+str(evaluation.errors)+" "+editor.message_label.text)
    await _capture(id+"-editor")
    editor._auto_smooth()
    _check(editor.data.control_points == original,id+" AUTO-SMOOTH moved a valid track")
    editor.selected = 4
    editor._set_start()
    editor._reverse()
    _check(editor.data.control_points[0] == original[4] and editor.data.control_points[1] == original[3],
        id+" start/direction")
    if raw.has("elevation"):
        var heights: Array = raw.elevation.knot_heights
        _check(editor.data.elevation.knot_heights[0] == heights[4] and
            editor.data.elevation.knot_heights[1] == heights[3],id+" altitude permutation")
    var changed: Dictionary = DNA.compile(editor.data)
    _check(changed.ok and absf(changed.length_metres-compiled.length_metres) < 0.02,id+" editor rotation length "+str(changed.errors)+" "+str(changed.length_metres))
    var title := "QA three circuits %s %s" % [id,Time.get_ticks_usec()]
    if not editor._persist_track(title):
        _check(false,id+" SAVE AS")
        return
    var copy: String = editor.last_saved_path
    editor._load_path(copy)
    _check(editor.preview.centerline == changed.centerline and editor.data.id != raw.id,id+" reopen geometry or identity")
    _check(LAN.track_fingerprint(path) in seen_fingerprints,id+" built-in changed during edits")
    DirAccess.remove_absolute(copy)

func _check_race(id: String, raw: Dictionary) -> void:
    var race = RACE.instantiate()
    add_child(race)
    while not race.track.pending_terrain.is_empty():
        await get_tree().process_frame
    race.set_physics_process(false)
    _check(race.track.track_id == id and race.laps_total == 3,id+" race identity")
    var origin: Vector2 = race.model.position
    Input.action_press("throttle")
    for tick in range(115):
        race._physics_process(1.0/120.0)
    Input.action_release("throttle")
    var distance: float = race.model.position.distance_to(origin)
    _check(distance > 1.0 and race.race_started,id+" throttle did not launch")
    print("DRIVE ",id," %.2f m" % distance)
    race._snap_cameras()
    await _capture(id+"-race")
    if raw.has("world"):
        _check_pro(race)
    race._restart()
    race.time_elapsed = 10.0
    race.last_progress = 0.01
    race.lap_winding = 0
    race.model.velocity = Vector2(-20,0)
    race._lap_logic(0.98,Vector2.RIGHT,1.0/120.0)
    race.model.velocity = Vector2(20,0)
    race._lap_logic(0.01,Vector2.RIGHT,1.0/120.0)
    _check(race.lap == 1 and race.lap_splits.is_empty(),id+" reverse shuffle credited a lap")
    var runs_before: Dictionary = {}
    for other: String in CIRCUITS:
        runs_before[other] = RESULTS.track_runs(other)
    for lap_index in range(3):
        race.time_elapsed += 80.0
        for progress in [0.25,0.5,0.75,0.98,0.01]:
            race._lap_logic(progress,Vector2.RIGHT,1.0/120.0)
    _check(race.finished and race.lap_splits.size() == 3,id+" three-lap finish")
    race._show_results()
    for other: String in CIRCUITS:
        var runs: Array = RESULTS.track_runs(other)
        if other == id and not raw.has("world"):
            _check(runs.size() == runs_before[other].size()+1,id+" result storage")
        else:
            _check(runs == runs_before[other],id+" modified "+other+" records")
    race.free()

func _check_pro(race) -> void:
    var zones: Array = race.track.event_layout.zones
    _check(race.track.event_mode == "pro" and zones.size() >= 3,"Fuji PRO event or missing sectors")
    var sector: Dictionary = {}
    var end: float = 0.0
    for zone in zones:
        _check(zone.a >= end and zone.b > zone.a and zone.b < race.track.length_metres and absf(zone.d) < 12.0,
            "Fuji sector outside its ordered racing corridor")
        end = zone.b
        if sector.is_empty() and zone.kind == "OUTSIDE":
            sector = zone
    if sector.is_empty():
        _check(false,"Fuji has no outside sector")
        return
    race._restart()
    var travel: float = sector.a + 0.25
    while travel < sector.b:
        _judge_at(race,sector,travel)
        travel += 0.25
    var award: float = race.judge.technical
    var claims: int = race.judge.claimed.size()
    _check(award > 0.0 and race.judge.claimed.has(sector.id),"Fuji judged drift must award technical points")
    _judge_at(race,sector,sector.a+0.25)
    _judge_at(race,sector,sector.a+0.5)
    _check(is_equal_approx(race.judge.technical,award) and race.judge.claimed.size() == claims,
        "Fuji sector re-entry awarded repeat points")
    print("PRO Fuji ",zones.size()," sectors; forward entry %.2f technical points" % award)

func _judge_at(race, sector: Dictionary, station: float) -> void:
    var frame: Dictionary = race.track._road_at_arc(station)
    var across: Vector2 = frame.across
    var forward := Vector2(across.y,-across.x)
    var model = race.model
    model.reset(frame.centre,forward.angle()+PI/2.0+deg_to_rad(26.0)*sector.turn)
    model.velocity = forward * float(sector.pace)
    model.drift_angle = -26.0 * sector.turn
    var offset: float = sector.d+model.forward().dot(across)*race.track.body_half_length \
        -signf(sector.d)*absf(model.right().dot(across))*race.track.body_half_width
    model.position += across*offset
    var info := {"progress":station/race.track.length_metres,"point":frame.centre,
        "tangent":forward,"distance":absf(offset),"width":12.0}
    race.judge.tick(1.0/60.0,race.track,model,info,{},1,race.scorer)

func _capture(label: String) -> void:
    if not android and output.is_empty():
        return
    for frame in range(4):
        await get_tree().process_frame
    await RenderingServer.frame_post_draw
    if android:
        var marker := FileAccess.open("user://ready-"+label,FileAccess.WRITE)
        marker.store_line(label)
        marker.close()
        while not FileAccess.file_exists("user://captured-"+label):
            await get_tree().create_timer(0.15).timeout
    else:
        var png := get_viewport().get_texture().get_image()
        _check(png.save_png(output+"/"+label+".png") == OK,label+" screenshot write")
