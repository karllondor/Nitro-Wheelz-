extends SceneTree
## Verify the connected site through the regular Park race scene and driver.
const RACE = preload("res://scenes/race.tscn")
const SITE = preload("res://scripts/park/park_site.gd")
const PLAZA = preload("res://scripts/park/park_layout.gd")
const DT := 1.0 / 120.0

var _service_count := 0

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    printerr("FAIL: ", message)
    quit(1)

func _run() -> void:
    ProjectSettings.set_setting("nitro/selected_track", PLAZA.TRACK_PATH)
    ProjectSettings.set_setting("nitro/park_mode", "free")
    ProjectSettings.set_setting("nitro/car_variant", "red")
    var race := RACE.instantiate()
    root.add_child(race)
    race.set_physics_process(false)
    var track := race.track as NitroParkTrack
    if track.site == null:
        _fail("Park scene did not load its site")
        return
    for zone in ["Technical Drift Circuit", "Stunt Area", "Car Park", "Japanese Service Station", "Industrial Yard", "Japanese Landscape"]:
        if not track.site.has_node(zone):
            _fail("Missing zone: " + zone)
            return
    var loop := SITE.road(SITE.LOOP, true)
    var entry := SITE.road(SITE.ENTRY_LANE)
    var exit_lane := SITE.road(SITE.EXIT_LANE)
    if loop.size() < 300 or loop[0].distance_to(loop[-1]) > 3.0 or not entry[-1].is_equal_approx(loop[0]):
        _fail("The circuit is not a continuous loop with an entry junction")
        return
    var exit_index := 0
    for i in range(loop.size()):
        if loop[i].distance_to(exit_lane[0]) < loop[exit_index].distance_to(exit_lane[0]):
            exit_index = i
    if loop[exit_index].distance_to(exit_lane[0]) > 2.0 or exit_index < 100:
        _fail("The exit must join the far side of the loop")
        return
    for path in [loop, entry, exit_lane, SITE.road(SITE.STUNT_ACCESS)]:
        for point: Vector2 in path:
            if not SITE.BOUNDS.has_point(point) or track.resolve_body(point, 0.0, Vector2.ZERO).hit:
                _fail("Access or circuit centerline blocked at " + str(point))
                return
    for ramp in SITE.RAMPS:
        var landing: Rect2 = ramp.landing
        var approach: Rect2 = ramp.approach
        var stop: Vector2 = ramp.start + Vector2(0, 2.8)
        if approach.size.y < 80.0 or landing.size.y < 45.0 or not track.resolve_body(stop, 0.0, Vector2.ZERO).hit:
            _fail("Ramp interface or visible closure invalid: " + str(ramp.id))
            return
        for point in [landing.get_center(), landing.position + Vector2(4, 4), landing.end - Vector2(4, 4),
                approach.get_center(), Vector2(approach.get_center().x, approach.end.y - 3.0)]:
            if track.resolve_body(point, 0.0, Vector2.ZERO).hit:
                _fail("Ramp approach or landing is occupied at " + str(point))
                return

    # Start at the real spawn, pass the seam twice and exit to the plaza.
    var drive := SITE.road([PLAZA.START_POS, Vector2(-52, 2), Vector2(-115, -43), entry[0]])
    drive.append_array(entry.slice(1, -1))
    drive.append_array(loop)
    drive.append_array(loop)
    drive.append_array(loop.slice(0, exit_index))
    drive.append_array(exit_lane)
    drive.append_array(SITE.road([exit_lane[-1], Vector2(105, -73), Vector2(69, -22), Vector2(32, 10)]).slice(1))
    if not _drive_route(race, drive):
        return
    if race.finished or race.lap != 1 or race.wall_collision_count != 0 or race.net != null:
        _fail("Free-roam loop triggered race logic or came into contact")
        return

    # A fast pass does not count. A stopped visit fires once per entry.
    race.park.repair_requested.connect(func(): _service_count += 1)
    var inside := SITE.REPAIR.get_center()
    race.model.reset(inside, 0.0)
    race.model.velocity = Vector2(0, -12)
    for i in range(8):
        race._physics_process(DT)
    if _service_count != 0:
        _fail("A rolling pass fired the repair signal")
        return
    for visit in range(2):
        race.model.reset(inside, 0.0)
        for i in range(240):
            race._physics_process(DT)
        if _service_count != visit + 1:
            _fail("A stopped visit must fire the repair signal once")
            return
        race.model.reset(Vector2(273, 4), 0.0)
        race._physics_process(DT)

    var contact: Dictionary = track.resolve_body(Vector2(240, 31.3), PI, Vector2(0, 8))
    if not contact.hit or contact.velocity.y > 0.1:
        _fail("Visible industrial fencing did not stop the vehicle")
        return
    race.queue_free()
    await process_frame
    print("PASS: Park 2 connected site, %.0f m loop, two continuous laps with plaza access and exit, clear run-ups and landings, visible fences and repeatable stop-to-service" %
        PLAZA.path_length(loop))
    quit(0)

func _drive_route(race: Node3D, path: PackedVector2Array) -> bool:
    var cursor := 0
    var max_error := 0.0
    for tick in range(60000):
        var model: NitroDriveModel = race.model
        var nearest := INF
        for i in range(maxi(cursor - 3, 0), mini(cursor + 12, path.size())):
            var d := model.position.distance_squared_to(path[i])
            if d < nearest:
                nearest = d
                cursor = i
        if cursor > 20:
            max_error = maxf(max_error, sqrt(nearest))
        if nearest > 6.5 * 6.5 and tick > 120:
            _fail("Starter car left the corridor at %s (%.1f m at point %d/%d)" %
                [str(model.position), sqrt(nearest), cursor, path.size()])
            return false
        if cursor >= path.size() - 3:
            Input.action_release("steer_left")
            Input.action_release("steer_right")
            Input.action_release("throttle")
            print("Park route drive %.1f s, worst centerline error %.2f m" % [tick * DT, max_error])
            return true
        var aim := path[mini(cursor + 5, path.size() - 1)] - model.position
        var error := wrapf(atan2(aim.x, -aim.y) - model.heading, -PI, PI)
        var steer := clampf(error * 1.85, -1.0, 1.0)
        var target := lerpf(38.0, 27.0, absf(steer))
        Input.action_press("steer_left", maxf(-steer, 0.0))
        Input.action_press("steer_right", maxf(steer, 0.0))
        Input.action_press("throttle", clampf(0.40 + (target - model.speed_kmh()) * 0.11, 0.0, 1.0))
        race._physics_process(DT)
    _fail("Driver did not complete the loop and exit (%d/%d at %s)" % [cursor, path.size(), str(race.model.position)])
    return false
