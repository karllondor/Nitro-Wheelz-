extends SceneTree
## Run with a display, GL Compatibility and OUT_DIR. At 1280x720 the raw
## orthographic masterplan is 748 metres tall with north at the top.
const RACE = preload("res://scenes/race.tscn")
const PARK_PATH := "res://tracks/nitro_wheelz_park.json"

var _race: Node3D
var _camera: Camera3D
var _out: String

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _out = OS.get_environment("OUT_DIR")
    if _out.is_empty():
        _out = ProjectSettings.globalize_path("user://park_v2")
    DirAccess.make_dir_recursive_absolute(_out)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    ProjectSettings.set_setting("nitro/selected_track", PARK_PATH)
    ProjectSettings.set_setting("nitro/park_mode", "free")
    ProjectSettings.set_setting("nitro/car_variant", "red")
    var start := Time.get_ticks_usec()
    _race = RACE.instantiate()
    root.add_child(_race)
    _race.set_physics_process(false)
    print("Scene ready CPU %.1f ms" % ((Time.get_ticks_usec() - start) / 1000.0))
    var args := OS.get_cmdline_user_args()
    if "--bench" in args:
        await _bench("Plaza Top-down", Vector2(0, 30), 0.0, false)
        await _bench("Plaza Chase", Vector2(0, 30), 0.0, true)
        if _race.track.has_node("Park 2 Environment"):
            await _bench("Circuit Chase", Vector2(-109, -184), 1.05, true)
            await _bench("Service Chase", Vector2(223, 12), 0.0, true)
            await _bench("Stunt Top-down", Vector2(28, -425), 0.0, false)
    elif "--portrait" in args:
        _race.touch.show()
        _pose(Vector2(-109, -184), 1.05, true)
        await _shot("13_circuit_portrait_touch")
        await _repair("14_repair_portrait_touch")
    else:
        await _screens()
    _race.queue_free()
    await process_frame
    quit()

func _screens() -> void:
    _pose(Vector2(0, 25), 0.0, false)
    await _shot("01_plaza_top_down")
    _pose(Vector2(0, 25), 0.0, true)
    await _shot("02_plaza_chase")
    _race.hud.hide()
    _race.touch.hide()
    _camera = Camera3D.new()
    _camera.far = 2900.0
    _race.add_child(_camera)
    _camera.current = true
    _camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    _camera.keep_aspect = Camera3D.KEEP_HEIGHT
    _camera.size = 748
    _camera.position = Vector3(4, 840, -192.5)
    _camera.rotation_degrees = Vector3(-90, 0, 0)
    await _shot("00_masterplan_raw")
    _camera.size = 350
    _camera.position = Vector3(0, 840, -235)
    await _shot("03_technical_circuit_overview")
    _camera.size = 280
    _camera.position = Vector3(0, 840, 0)
    await _shot("11_plaza_overview")
    _pose(Vector2(-109, -184), 1.05, true)
    await _shot("04_circuit_chase")
    await _wide("05_stunt_area", Vector3(81, 169, -318), Vector3(0, 0, -433), Vector2(23, -405))
    await _wide("06_car_park", Vector3(-214, 38, 72), Vector3(-263, 0, 19), Vector2(-250, 18))
    await _wide("07_service_station", Vector3(243, 25, 42), Vector3(249, 2, -17), Vector2(270, -8))
    await _wide("08_industrial_yard", Vector3(250, 30, 121), Vector3(251, 2, 64), Vector2(241, 77))
    await _wide("09_sakura_and_mountains", Vector3(-151, 13, -116), Vector3(-23, 34, -365), Vector2(-124, -130))
    await _wide("12_service_forecourt", Vector3(234, 6.5, 18), Vector3(231, 2, -22), Vector2(223, 0))
    _race.hud.show()
    await _repair("10_repair_bay")

func _repair(filename: String) -> void:
    _pose(Vector2(273, -23), 0.0, false)
    for i in range(90):
        _race._physics_process(1.0 / 120.0)
    await _shot(filename)

func _pose(at: Vector2, heading: float, chase: bool) -> void:
    _race.model.reset(at, heading)
    _race.camera_mode = 1 if chase else 0
    _race.overhead.current = not chase
    _race.chase.current = chase
    _race._snap_cameras()
    _race._update_visuals()

func _wide(filename: String, from: Vector3, target: Vector3, at: Vector2) -> void:
    _pose(at, 0.0, false)
    _camera.projection = Camera3D.PROJECTION_PERSPECTIVE
    _camera.fov = 57.0
    _camera.position = from
    _camera.look_at(target)
    _camera.current = true
    await _shot(filename)

func _shot(filename: String) -> void:
    for i in range(12):
        await RenderingServer.frame_post_draw
    var frame := root.get_texture().get_image()
    var path := _out.path_join(filename + ".png")
    if frame.save_png(path) != OK:
        printerr("Capture failed: ", path)
        quit(1)

func _bench(label: String, at: Vector2, heading: float, chase: bool) -> void:
    _pose(at, heading, chase)
    for i in range(48):
        await RenderingServer.frame_post_draw
    var times := PackedFloat32Array()
    var peak_draws := 0
    var peak_triangles := 0
    var prior := Time.get_ticks_usec()
    for i in range(150):
        await RenderingServer.frame_post_draw
        var now := Time.get_ticks_usec()
        times.append((now - prior) / 1000.0)
        prior = now
        peak_draws = maxi(peak_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
        peak_triangles = maxi(peak_triangles, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
    times.sort()
    print("%s | 150 frames | median %.2f ms | p95 %.2f ms | peak %d draws | peak %d primitives" %
        [label, times[75], times[142], peak_draws, peak_triangles])
