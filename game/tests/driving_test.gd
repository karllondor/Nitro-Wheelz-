extends SceneTree

const DRIVE = preload("res://scripts/driving/drive_model.gd")
const TRACK = preload("res://scripts/world/drift_track.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var a: NitroDriveModel = DRIVE.new()
    var b: NitroDriveModel = DRIVE.new()
    a.reset(Vector2.ZERO,0.0)
    b.reset(Vector2.ZERO,0.0)
    var idle: NitroDriveModel = DRIVE.new()
    idle.reset(Vector2.ZERO,0.0)
    for frame in range(120):
        idle.step(1.0/240.0,1.0,0.0,1.0,0.0)
    if idle.speed_mps()>0.01 or absf(idle.heading)>0.01:
        _fail("Stopped car moved or rotated under brake/steer without throttle")
        return
    var starting_speed: float = a.speed_mps()
    for i in range(1600):
        var steer: float = 0.65 if i>300 and i<1050 else -0.25
        var gas: float = 1.0 if i<900 else 0.52
        var handbrake: float = 1.0 if i>=420 and i<500 else 0.0
        a.step(1.0/240.0,steer,gas,0.0,handbrake)
        b.step(1.0/240.0,steer,gas,0.0,handbrake)
    if a.speed_mps() <= starting_speed+2.0:
        _fail("Cannot accelerate")
        return
    if not is_finite(a.heading) or not is_finite(a.velocity.x) or not is_finite(a.position.y):
        _fail("Physics diverged to non-finite state")
        return
    if a.position.distance_to(b.position)>0.00001 or absf(a.heading-b.heading)>0.00001:
        _fail("Identical inputs are not deterministic")
        return
    var c: NitroDriveModel = DRIVE.new()
    c.reset(Vector2.ZERO,0.0)
    c.velocity=Vector2(0,-14)
    for i in range(20):
        c.step(1.0/240.0,0.65,0.8,0.0,1.0)
    if c.rear_traction >= 0.75:
        _fail("Handbrake failed to reduce rear grip")
        return
    var course: NitroDriftTrack = TRACK.new()
    root.add_child(course)
    await process_frame
    if course.centerline.size()<100:
        _fail("Track spline failed")
        return
    var info: Dictionary = course.sample_info(course.start_position())
    if float(info["distance"]) > 0.1:
        _fail("Start does not lie on driving surface")
        return
    course.queue_free()
    print("PASS: deterministic driving, acceleration, handbrake rear grip, Japanese track geometry")
    quit(0)

func _fail(message: String) -> void:
    printerr("FAIL: " + message)
    quit(1)

