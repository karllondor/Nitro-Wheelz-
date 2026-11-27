extends Node
signal complete(ok: bool)

const RACE = preload("res://scenes/race.tscn")
const RESULTS = preload("res://scripts/ui/race_results.gd")
const TIME = preload("res://scripts/lighting/time_of_day.gd")
const PAINT = preload("res://scripts/events/event_paint.gd")
const CIRCUIT = "res://tracks/fuji_speedway_short.json"
const CUSTOM = "user://nitro_track_qa_hotfix.json"
const VARIANT = "e30"

var failures: Array[String] = []
var android := OS.has_feature("android")
var captures := OS.get_environment("NITRO_HOTFIX_CAPTURES")
var before_path: Variant
var before_car: Variant
var saves: Dictionary = {}

func _ready() -> void:
    _run.call_deferred()

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)

func _read(path: String) -> Dictionary:
    return JSON.parse_string(FileAccess.get_file_as_string(path))

func _snapshot_files() -> void:
    for path in [CUSTOM,RESULTS.STORAGE]:
        saves[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null

func _restore() -> void:
    for path: String in saves:
        if saves[path] == null:
            if FileAccess.file_exists(path):
                DirAccess.remove_absolute(path)
        else:
            var file := FileAccess.open(path,FileAccess.WRITE)
            file.store_buffer(saves[path])
            file.close()
    ProjectSettings.set_setting("nitro/selected_track",before_path)
    ProjectSettings.set_setting("nitro/car_variant",before_car)

func _race(path: String) -> Node3D:
    ProjectSettings.set_setting("nitro/selected_track",path)
    var race = RACE.instantiate()
    add_child(race)
    while not race.track.pending_terrain.is_empty():
        await get_tree().process_frame
    race.set_physics_process(false)
    return race

func _run() -> void:
    before_path = ProjectSettings.get_setting("nitro/selected_track",null)
    before_car = ProjectSettings.get_setting("nitro/car_variant",null)
    _snapshot_files()
    var active := get_tree().current_scene as Control
    if active != null:
        active.hide()
    ProjectSettings.set_setting("nitro/car_variant",VARIANT)
    _check_diagonal()
    var wide = await _race(CIRCUIT)
    _compare_layout(wide.track,true)
    await _paint_and_retries(wide)
    wide.free()

    var custom := _read(CIRCUIT)
    custom.id = "qa_hotfix_custom"
    custom.name = "QA saved route"
    custom.width_m = 12.0
    custom.road_style = "road"
    custom.world.road_style = "road"
    custom.world.event_mode = "club"
    _write_custom(custom)
    var road = await _race(CUSTOM)
    _check(road.track.road_style == "road" and is_equal_approx(road.track.halfwidths[0],6.0),
        "saved ROAD HARD did not reopen at 12 m")
    _compare_layout(road.track,false)
    _check_three_fingers(road.touch)
    await _finish(road,"club")
    road.free()

    custom.world.event_mode = "practice"
    _write_custom(custom)
    var practice = await _race(CUSTOM)
    _check(practice.track.event_layout.zones.is_empty(),"Practice has judged zones")
    await _finish(practice,"practice")
    practice.free()

    var ordinary = await _race("res://tracks/driftwood_circuit.json")
    await _finish(ordinary,"ordinary")
    ordinary.free()
    var testandori = await _race("res://tracks/testandori_raceway.json")
    _check(testandori.track.track_valid and testandori.laps_total == 3,"Testandori regression")
    testandori.free()
    _restore()
    if active != null:
        active.show()
    var verdict := "PASS: results in four modes, exact GAS contacts, ROAD/CIRCUIT A/B, paint in all presets and five retries"
    if not failures.is_empty():
        verdict = "FAIL: "+str(failures)
    print(verdict)
    if android:
        var file := FileAccess.open("user://hotfix-verdict.txt",FileAccess.WRITE)
        file.store_line(verdict)
        file.close()
    complete.emit(failures.is_empty())
    queue_free()

func _write_custom(raw: Dictionary) -> void:
    var file := FileAccess.open(CUSTOM,FileAccess.WRITE)
    file.store_string(JSON.stringify(raw))
    file.close()

func _compare_layout(track, wide: bool) -> void:
    var layout = track.EVENT_LAYOUT
    for style in ["club","pro"]:
        var base: Array = layout.generate(track,style,false).zones
        var changed: Array = layout.generate(track,style).zones
        if not wide:
            _check(base == changed,"ROAD "+style+" judging changed")
        else:
            var old_total := _outside_metres(base)
            var new_total := _outside_metres(changed)
            _check(new_total > old_total*1.05,"wide "+style+" Outside opportunity did not grow")
            _check(not changed.filter(func(z): return z.kind == "CLIP").is_empty(),"wide "+style+" lost Inside")
            _check(not changed.filter(func(z): return z.kind == "FLICK").is_empty(),"wide "+style+" lost Transfer")
            print("OUTSIDE ",style," linear metres on the same 24 m circuit, baseline %.1f → prototype %.1f" % [old_total,new_total])
        var last_b := -1.0
        for z in changed:
            _check(z.a >= last_b-0.0001 and z.b > z.a and z.b <= track.length_metres,
                "overlapping or invalid sector")
            last_b = z.b

func _outside_metres(zones: Array) -> float:
    var total := 0.0
    for z in zones:
        if z.kind == "OUTSIDE":
            total += z.b-z.a
    return total

func _check_diagonal() -> void:
    var quad := [Vector2(0.15,0.2),Vector2(0.8,0.2),Vector2(0.8,0.6),Vector2(0.15,0.6)]
    var below := PAINT._clip_diagonal(quad,1.0)
    var above := PAINT._clip_diagonal(quad,-1.0)
    _check(below.size() >= 3 and above.size() >= 3,"paint diagonal split missing a side")
    for p in below:
        _check(p.x+p.y<1.00001,"triangle straddles asphalt planes")
    for p in above:
        _check(p.x+p.y>0.99999,"triangle straddles asphalt planes")

func _paint_and_retries(race) -> void:
    var paint := race.track.get_node_or_null("Road paint") as MeshInstance3D
    _check(paint != null and paint.mesh.get_surface_count() == 1,"no single batched event paint mesh")
    if paint == null:
        return
    # Even a 16-bit orthographic depth buffer has several steps between
    # the road and the paint in the same view ray over the playable area.
    _check((race.overhead.far-race.overhead.near)/65535.0 < 0.031/4.0
        and race.chase.near >= 0.6-0.00001,"event camera depth precision")
    var colours: Material = paint.material_override
    var mesh := paint.mesh
    var z: Dictionary = race.track.event_layout.zones.filter(func(zone): return zone.kind == "OUTSIDE").front()
    var frame: Dictionary = race.track._road_at_arc(z.a-4.0)
    var forward := Vector2(frame.across.y,-frame.across.x)
    race.model.reset(frame.centre,atan2(forward.x,-forward.y))
    race.road_y = frame.y
    race.car_y = frame.y
    race._update_visuals()
    race._snap_cameras()
    for preset in [TIME.Preset.DAWN,TIME.Preset.DAY,TIME.Preset.GOLDEN_HOUR,TIME.Preset.NIGHT]:
        race._apply_time_of_day(preset)
        _check(paint.material_override == colours and paint.mesh == mesh,"preset mutated scoring paint")
        await _shot("paint-%d" % preset)
        race._toggle_camera()
        await _shot("chase-paint-%d" % preset)
        race._toggle_camera()
    race._apply_time_of_day(TIME.Preset.GOLDEN_HOUR)
    for attempt in range(5):
        race.scorer.chain_points = 45.0
        race.scorer.in_chain = true
        race.scorer.multiplier = 2.0
        race.combo = 2.0
        var position: Vector2 = race.model.position
        race.skid_segments.assign([PackedVector2Array([position,position+race.model.forward()])])
        race.skid_heights.assign([race.road_y])
        race._refresh_skid_mesh()
        _check(race.skid_mesh.get_surface_count() > 0 and race.scorer.pending_total() > 0,
            "retry fixture lacks a live skid and chain")
        var view: NitroRaceResults = await _finish(race,"pro",attempt==0)
        if view == null:
            break
        view.buttons[0].pressed.emit()
        await get_tree().process_frame
        _check(race.results_layer == null and not race.results_open and not race.finished
            and race.scorer.total == 0 and race.scorer.pending_total() == 0 and race.combo == 1.0
            and race.judge.technical == 0.0 and race.lap == 1 and race.time_elapsed == 0.0
            and race.skid_mesh.get_surface_count() == 0, "Drive Again reset %d" % attempt)
        _check(race.track.get_node_or_null("Road paint") == paint
            and race.track.find_children("Road paint","MeshInstance3D",false,false).size() == 1,
            "repeat allocated duplicate paint")
    await _shot("retry-five")
    # Retest the same painted corner after the five resets.
    race.model.reset(frame.centre,atan2(forward.x,-forward.y))
    race.road_y = frame.y
    race.car_y = frame.y
    race._update_visuals()
    race._snap_cameras()
    await _shot("retry-paint")

func _finish(race, mode: String, capture: bool = true) -> NitroRaceResults:
    var prior := FileAccess.get_file_as_string(RESULTS.STORAGE)
    race.finished = true
    race.time_elapsed = 86.34
    race.scorer.total = 12040
    race.scorer.best_chain = 865
    race.lap_score = race.scorer.total
    race.lap_splits.assign([{"time":86.34,"score":12040}])
    if mode in ["club","pro"]:
        race.judge.complete = 3
        race.judge.missed = 2
        race.judge.technical = 164.0
    race._show_results()
    race._show_results()
    await get_tree().process_frame
    var view: NitroRaceResults = race.results_layer.get_child(0) as NitroRaceResults
    if view == null:
        _check(false,mode+" finished without the shared results board")
        return null
    var event: Dictionary = view.data.get("event",{})
    _check(view.data.score == 12040 and view.data.seconds == 86.34 and view.data.stats.best_chain == 865,
        mode+" results lost race statistics")
    _check(event.is_empty() if mode=="ordinary" else event.get("mode")==mode,mode+" result mode")
    if mode in ["club","pro"]:
        _check(event.get("filled")==3 and event.get("missed")==2 and event.get("technical")==164,mode+" sector statistics")
    if mode != "ordinary":
        _check(FileAccess.get_file_as_string(RESULTS.STORAGE)==prior,mode+" changed earned records")
    for button in view.buttons:
        var r := button.get_global_rect()
        var screen := get_viewport().get_visible_rect()
        _check(screen.encloses(r) and r.size.y >= screen.size.y*0.05,mode+" unreadable or clipped action")
    if capture:
        await _shot("results-"+mode)
    return view

func _check_three_fingers(touch) -> void:
    var geo: Dictionary = touch._layout()
    var gas: Rect2 = geo.gas
    for contact in [
        [0,Vector2(geo.joystick_center)+Vector2(float(geo.joystick_radius)*0.5,0)],
        [1,gas.position+gas.size*Vector2(0.1,0.80)],
        [2,Rect2(geo.drift).get_center()]]:
        var event := InputEventScreenTouch.new()
        event.index = contact[0]
        event.position = contact[1]
        event.pressed = true
        touch._input(event)
    _check(touch.throttle == 1.0 and touch.handbrake == 1.0 and touch.steer > 0.2,
        "three screen-touch events did not combine")
    touch.release_all()

func _shot(label: String) -> void:
    if not android and captures.is_empty():
        return
    for frame in range(3):
        await get_tree().process_frame
    await RenderingServer.frame_post_draw
    if android:
        var marker := FileAccess.open("user://ready-"+label,FileAccess.WRITE)
        marker.store_line(label)
        marker.close()
        while not FileAccess.file_exists("user://captured-"+label):
            await get_tree().create_timer(0.15).timeout
    else:
        get_viewport().get_texture().get_image().save_png(captures+"/"+label+".png")
