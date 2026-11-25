extends SceneTree
## Runs the real scenes in a window. OUT_DIR holds PNGs and stdout has frame timing.
## For two local processes, run the viewer with --lan-host <port> <marker directory>
## and a second executable with --headless and --lan-guest <port> <marker directory>.
const TIME = preload("res://scripts/lighting/time_of_day.gd")
const LAMPS = preload("res://scripts/lighting/car_lamps.gd")
const P = preload("res://scripts/net/net_protocol.gd")
const SESSION = preload("res://scripts/net/net_session.gd")
const RACE = preload("res://scenes/race.tscn")
const BOOT = preload("res://scenes/boot.tscn")
const SITE = preload("res://scripts/park/park_site.gd")

var race
var room: NitroNetSession
var out := OS.get_environment("OUT_DIR")
var errors := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    ProjectSettings.set_setting("nitro/car_variant", "white")
    ProjectSettings.set_setting("nitro/park_mode", "free")
    var args := OS.get_cmdline_user_args()
    if args.size() == 3 and args[0].begins_with("--lan-"):
        await _lan(args[0] == "--lan-host", int(args[1]), args[2])
    else:
        await _solo()
    quit(0 if errors == 0 else 1)

func _launch(path: String) -> void:
    ProjectSettings.set_setting("nitro/selected_track", path)
    race = RACE.instantiate()
    root.add_child(race)
    current_scene = race

func _solo() -> void:
    _launch(P.PARK_PATH)
    race.set_physics_process(false)
    race.touch.hide()
    _pose(Vector2(-5,30), 0.0)
    race._toggle_camera()
    for preset in TIME.LABELS.size():
        race._apply_time_of_day(preset)
        var key: String = TIME.LABELS[preset].to_lower().replace(" ", "-")
        await _shot("park-" + key)
        await _measure("PARK " + TIME.LABELS[preset])
    race._toggle_camera()
    await _shot("night-auto-top-down")
    var beam_on := root.get_texture().get_image()
    race._set_lamp_mode(LAMPS.Mode.OFF)
    await _shot("night-off-top-down")
    _compare_road(beam_on, root.get_texture().get_image())
    race._toggle_camera()
    await _shot("night-off-chase")
    race._set_lamp_mode(LAMPS.Mode.AUTO)
    await _rear_evidence()
    race._apply_time_of_day(TIME.Preset.DAY)
    race._toggle_pause()
    _pause_button("VEHICLE LIGHTS", "ON")
    await _shot("park-pause-manual-on")
    race._toggle_pause()
    await _shot("day-manual-on")
    await _measure("PARK DAY MANUAL ON")
    Input.action_press("brake")
    race._read_lamps()
    await _shot("day-brake")
    race._set_lamp_mode(LAMPS.Mode.OFF)
    await _shot("day-off-brake")
    Input.action_release("brake")
    race._read_lamps()
    race._toggle_pause()
    _pause_button("TIME OF DAY", "NIGHT")
    _pause_button("VEHICLE LIGHTS", "AUTO")
    await _shot("park-pause-live-night")
    race._toggle_pause()
    await _dynamics()
    unload_current_scene()
    await process_frame
    await _setup_evidence()

func _dynamics() -> void:
    _pose(Vector2(155, -69), -0.64)
    await _shot("night-circuit-access")
    _pose(Vector2(5, 46), 0.0)
    Input.action_press("throttle", 1.0)
    for tick in 270:
        race._physics_process(1.0/120.0)
    Input.action_press("steer_right", 0.8)
    Input.action_press("handbrake", 1.0)
    for tick in 40:
        race._physics_process(1.0/120.0)
    race._snap_cameras()
    await _shot("night-drift-handbrake")
    Input.action_release("steer_right")
    Input.action_release("handbrake")
    var ramp: Dictionary = SITE.RAMPS[2]
    _pose(Vector2(ramp.start) + Vector2(0, 55), 0.0)
    var airborne := false
    for tick in 600:
        race._physics_process(1.0/120.0)
        if race.park.air.height > float(ramp.rise) + 0.35:
            airborne = true
            break
    Input.action_release("throttle")
    if airborne:
        race._snap_cameras()
        await _shot("night-headlights-airborne")
    else:
        _fail("ramp capture did not reach the airborne sample")
    _pose(Vector2(SITE.RAMPS[2].start) + Vector2(0, -48), 0.0)
    var stunt: Node = race.park.stunts
    var at: Vector3 = stunt.fixtures[13].at
    stunt.contact(at, at, 0.0, Vector2(0,-23), Vector2(2.5,1.2))
    await _measure("PARK NIGHT INTERACTIVE")
    await _shot("night-stunt-wall-impact")

func _rear_evidence() -> void:
    # Close runtime view to show the source lamp surfaces at evaluation scale.
    var rear := Camera3D.new()
    root.add_child(rear)
    rear.position = race.car_root.position + Vector3(0, 2.6, 7.0)
    rear.look_at(race.car_root.position + Vector3(0, 0.55, 0))
    rear.make_current()
    await _shot("rear-position")
    Input.action_press("brake")
    race._read_lamps()
    await _shot("rear-brake")
    Input.action_press("handbrake")
    race._read_lamps()
    await _shot("rear-both-brakes")
    Input.action_release("brake")
    race._read_lamps()
    await _shot("rear-handbrake")
    Input.action_release("handbrake")
    race._read_lamps()
    await _shot("rear-both-released")
    race._apply_time_of_day(TIME.Preset.DAY)
    race._set_lamp_mode(LAMPS.Mode.OFF)
    Input.action_press("brake")
    race._read_lamps()
    await _shot("rear-day-off-brake")
    Input.action_release("brake")
    race._apply_time_of_day(TIME.Preset.NIGHT)
    race._set_lamp_mode(LAMPS.Mode.AUTO)
    race.chase.make_current()
    rear.queue_free()

func _setup_evidence() -> void:
    var menu = BOOT.instantiate()
    root.add_child(menu)
    current_scene = menu
    menu.navigate_enabled = false
    ProjectSettings.set_setting("nitro/selected_track", P.TRACKS[2])
    TIME.select(TIME.Preset.DAY)
    menu.show_page("setup")
    await _shot("official-track-setup")
    var temporary := "user://nitro_track_lighting_capture.json"
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(P.TRACKS[1]))
    data["name"] = "Lighting Test Circuit"
    data["id"] = "lighting_capture"
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    file.store_string(JSON.stringify(data))
    file.close()
    menu._pick_track(temporary)
    TIME.select(TIME.Preset.GOLDEN_HOUR)
    menu.show_page("setup")
    await _shot("custom-track-setup")
    DirAccess.remove_absolute(temporary)

func _lan(host: bool, port: int, sync_dir: String) -> void:
    var listening := sync_dir.path_join("lighting-listening")
    var guest_saw_night := sync_dir.path_join("lighting-guest-saw-night")
    var finished := sync_dir.path_join("lighting-finished")
    room = SESSION.new()
    root.add_child(room)
    room.start_requested.connect(func(path: String): _launch.call_deferred(path))
    if host:
        if room.host(port, "HOST", "white", P.PARK_PATH) != OK:
            _fail("could not host Park")
            return
        room.set_time_of_day(TIME.Preset.DAWN)
        _mark(listening)
    else:
        if not await _wait(func(): return FileAccess.file_exists(listening)):
            return
        if room.join("127.0.0.1", port, "JOINER", "red") != OK:
            _fail("could not join Park")
            return
    if not await _wait(func(): return room.state == SESSION.State.LOBBY):
        return
    room.set_ready(true)
    if host:
        if not await _wait(room.can_start):
            return
        room.start_race()
    if not await _wait(func(): return room.state == SESSION.State.PARK and race != null and race.net != null):
        return
    if host:
        race.touch.hide()
        race._toggle_camera()
        await _shot("lan-shared-dawn")
        race._toggle_pause()
        _pause_button("TIME OF DAY", "NIGHT")
        race._toggle_pause()
        if not await _wait(func(): return FileAccess.file_exists(guest_saw_night) and race.net.remote_lamps.bits == (LAMPS.POSITION | LAMPS.BRAKING)):
            return
        await _shot("lan-shared-night")
        var other: Node3D = race.net.remote_car
        var view := Camera3D.new()
        root.add_child(view)
        view.position = other.global_position + Vector3(3.5, 4.0, 9.0)
        view.look_at(other.global_position + Vector3(-2.0, 0.4, -1.0))
        view.make_current()
        await _shot("lan-remote-braking")
        await _measure("PARK NIGHT TWO PLAYERS")
        _mark(finished)
    else:
        if not await _wait(func(): return race.time_of_day == TIME.Preset.NIGHT):
            return
        _mark(guest_saw_night)
        Input.action_press("brake")
        await _wait(func(): return FileAccess.file_exists(finished))
        Input.action_release("brake")
    print("LAN_RENDER ", "host" if host else "guest", " shared=", TIME.LABELS[race.time_of_day])
    room.leave()

func _pause_button(group: String, target: String) -> void:
    var picker: Node = race.pause_menu.find_child(group, true, false)
    (picker.get_node(target) as Button).pressed.emit()

func _pose(at: Vector2, heading: float) -> void:
    race.park.air.reset()
    race.car_y = 0.0
    race.body_pitch = 0.0
    race.model.reset(at, heading)
    race._update_visuals()
    race._snap_cameras()

func _shot(name: String) -> void:
    for i in 4:
        await process_frame
    await RenderingServer.frame_post_draw
    var path := out.path_join(name + ".png")
    if root.get_texture().get_image().save_png(path) != OK:
        _fail("could not write " + path)
    else:
        print("IMAGE ", path)

func _compare_road(enabled: Image, disabled: Image) -> void:
    for distance in [10.0, 20.0, 30.0, 40.0, 47.0]:
        var point := Vector2i(race.overhead.unproject_position(Vector3(-5.0, 0.06, 30.0 - distance)))
        if not Rect2i(Vector2i.ZERO, enabled.get_size()).grow(-2).has_point(point):
            continue
        var brighter := 0.0
        for y in range(-2, 3):
            for x in range(-2, 3):
                var delta := enabled.get_pixelv(point + Vector2i(x,y)) - disabled.get_pixelv(point + Vector2i(x,y))
                brighter += delta.get_luminance()
        print("ASPHALT d=%.0f m luminance_delta_8bit=%.1f" % [distance, brighter * 255.0 / 25.0])

func _measure(label: String) -> void:
    var samples := PackedFloat32Array()
    for i in 8:
        await process_frame
    var previous := Time.get_ticks_usec()
    for i in 32:
        await process_frame
        var now := Time.get_ticks_usec()
        samples.append(float(now - previous) / 1000.0)
        previous = now
    samples.sort()
    var median := float(samples[16])
    print("FRAME ", label, " median_ms=%.2f p95_ms=%.2f median_fps=%.1f draw_calls=%d" %
        [median, samples[30], 1000.0 / median, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])

func _wait(condition: Callable) -> bool:
    var deadline := Time.get_ticks_msec() + 48000
    while not condition.call() and Time.get_ticks_msec() < deadline:
        await process_frame
    if condition.call():
        return true
    _fail("LAN render synchronization timed out")
    return false

func _mark(path: String) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        _fail("could not create LAN marker " + path)
    else:
        file.store_string("ready")

func _fail(message: String) -> void:
    errors += 1
    printerr("FAIL: " + message)
