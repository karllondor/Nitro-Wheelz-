extends SceneTree

const DRIVE = preload("res://scripts/driving/drive_model.gd")
const TRACK = preload("res://scripts/world/drift_track.gd")
const STEP: float = 1.0 / 240.0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    # Brake at rest is reverse, not a no-op. Steering alone stays stationary.
    var idle: NitroDriveModel = DRIVE.new()
    idle.reset(Vector2.ZERO,0.0)
    for i in range(120):
        idle.step(STEP,1.0,0.0,0.0,0.0)
    if idle.speed_mps() > 0.01 or absf(idle.heading) > 0.01:
        _fail("Steering without movement causes stationary spin")
        return

    var reverse: NitroDriveModel = DRIVE.new()
    reverse.reset(Vector2.ZERO,0.0)
    for i in range(480):
        reverse.step(STEP,0.0,0.0,1.0,0.0)
    if reverse.signed_forward_speed_mps() > -1.5 or not reverse.is_reversing():
        _fail("Holding BRAKE after stopping must engage reverse")
        return
    if reverse.signed_forward_speed_mps() < -REVERSE_SAFE_CAP():
        _fail("Reverse exceeds safety speed limit")
        return

    # Signed reversing: steer right -> the rear moves right, nose rotates left.
    var reverse_right: NitroDriveModel = DRIVE.new()
    reverse_right.reset(Vector2.ZERO,0.0)
    reverse_right.velocity = Vector2(0.0,4.0)
    for i in range(240):
        reverse_right.step(STEP,1.0,0.0,1.0,0.0)
    if reverse_right.heading >= -0.10 or reverse_right.position.x < 0.15:
        _fail("Reverse steering right has inverted yaw or translation")
        return
    var reverse_left: NitroDriveModel = DRIVE.new()
    reverse_left.reset(Vector2.ZERO,0.0)
    reverse_left.velocity = Vector2(0.0,4.0)
    for i in range(240):
        reverse_left.step(STEP,-1.0,0.0,1.0,0.0)
    if reverse_left.heading <= 0.10 or reverse_left.position.x > -0.15:
        _fail("Reverse steering left has inverted yaw or translation")
        return

    # GAS should recover through neutral and take the car forward.
    for i in range(960):
        reverse.step(STEP,0.0,1.0,0.0,0.0)
    if reverse.signed_forward_speed_mps() < 2.0:
        _fail("GAS does not bring car forwards after reversing")
        return

    # Braking at speed must slow first, not immediately propel backwards.
    var forward_brake: NitroDriveModel = DRIVE.new()
    forward_brake.reset(Vector2.ZERO,0.0)
    forward_brake.velocity = Vector2(0,-16.0)
    forward_brake.step(STEP,0.0,0.0,1.0,0.0)
    if forward_brake.signed_forward_speed_mps() < 0.0:
        _fail("BRAKE flipped a moving car to reverse in one tick")
        return
    for i in range(600):
        forward_brake.step(STEP,0.0,0.0,1.0,0.0)
    if forward_brake.signed_forward_speed_mps() >= -0.5:
        _fail("BRAKE does not change from stopping to reversing")
        return

    # Repeated exact inputs are deterministic, preserving the starter contract.
    var a: NitroDriveModel = DRIVE.new()
    var b: NitroDriveModel = DRIVE.new()
    a.reset(Vector2.ZERO,0.0)
    b.reset(Vector2.ZERO,0.0)
    for i in range(1600):
        var steer: float = 0.65 if i > 300 and i < 1050 else -0.25
        var gas: float = 1.0 if i < 900 else 0.52
        var handbrake: float = 1.0 if i >= 420 and i < 500 else 0.0
        a.step(STEP,steer,gas,0.0,handbrake)
        b.step(STEP,steer,gas,0.0,handbrake)
    if a.speed_mps() < 2.0:
        _fail("Cannot accelerate")
        return
    if not is_finite(a.heading) or not is_finite(a.velocity.x) or not is_finite(a.position.y):
        _fail("Physics diverged to non-finite state")
        return
    if a.position.distance_to(b.position) > 0.00001 or absf(a.heading-b.heading) > 0.00001:
        _fail("Same inputs have different results")
        return

    var c: NitroDriveModel = DRIVE.new()
    c.reset(Vector2.ZERO,0.0)
    c.velocity = Vector2(0,-14.0)
    for i in range(20):
        c.step(STEP,0.65,0.8,0.0,1.0)
    if c.rear_traction >= 0.75:
        _fail("Handbrake did not reduce rear grip")
        return

    # At 72 km/h full throttle should cost far less rear grip than at 36 km/h.
    if absf(a._power_grip_factor(1.0,10.0) - 0.40) > 0.02:
        _fail("Rear power-grip calibration at 36 km/h is wrong")
        return
    if absf(a._power_grip_factor(1.0,20.0) - 0.63) > 0.02:
        _fail("Rear power-grip calibration at 72 km/h is wrong")
        return
    if absf(rad_to_deg(a._max_steer_for_speed(20.0)) - 20.0) > 0.1:
        _fail("Speed dependent steering reference mismatch")
        return

    # Driving straight on throttle must remain straight, without accidental drift.
    var grip: NitroDriveModel = DRIVE.new()
    grip.reset(Vector2.ZERO,0.0)
    for i in range(2400):
        grip.step(STEP,0.0,1.0,0.0,0.0)
    if absf(grip.drift_angle) > 2.0 or absf(grip.yaw_rate) > 0.05:
        _fail("Full throttle on a straight causes unwanted sliding")
        return

    # Flick the rear loose and lift: within 2.5 s the car should stop
    # rotating continuously and begin to reattach.
    var recovery: NitroDriveModel = DRIVE.new()
    recovery.reset(Vector2.ZERO,0.0)
    recovery.velocity = Vector2(0,-13.0)
    for i in range(75):
        recovery.step(STEP,0.65,0.75,0.0,1.0)
    for i in range(600):
        recovery.step(STEP,0.0,0.0,0.0,0.0)
    print("FEEL RECOVERY: angle=",recovery.drift_angle,
        " yaw=",recovery.yaw_rate," traction=",recovery.rear_traction)
    if recovery.rear_traction < 0.96 or absf(recovery.yaw_rate) > 0.65:
        _fail("Slide stays loose or keeps spinning after lifting throttle")
        return

    # v0.1.3: at 72+ km/h the car must not rotate like a low-speed donut.
    if a._yaw_rate_limit(20.0,0.0) > 0.68 or a._yaw_rate_limit(20.0,0.0) < 0.52:
        _fail("High speed yaw limit not proportional to available lateral grip")
        return
    if a._yaw_rate_limit(10.0,0.0) <= a._yaw_rate_limit(20.0,0.0):
        _fail("Low-speed turn authority must exceed high-speed turn authority")
        return
    var sweeper: NitroDriveModel = DRIVE.new()
    sweeper.reset(Vector2.ZERO,0.0)
    sweeper.velocity = Vector2(0,-20.0)
    var maximum_yaw_rate: float = 0.0
    var maximum_slip_angle: float = 0.0
    for i in range(480):
        sweeper.step(STEP,0.68,0.70,0.0,0.0)
        maximum_yaw_rate = maxf(maximum_yaw_rate,absf(sweeper.yaw_rate))
        maximum_slip_angle = maxf(maximum_slip_angle,absf(sweeper.drift_angle))
        if not is_finite(sweeper.yaw_rate) or not is_finite(sweeper.drift_angle):
            _fail("High-speed cornering diverged")
            return
        if absf(sweeper.yaw_rate) > sweeper._yaw_rate_limit(sweeper.speed_mps(),0.99)+0.001:
            _fail("Speed-dependent turning limit exceeded during sweeper")
            return
    print("HIGH SPEED SWEEPER: speed=",sweeper.speed_kmh(),
        " yaw_peak=",maximum_yaw_rate," angle_peak=",maximum_slip_angle)
    if maximum_yaw_rate < 0.42:
        _fail("Car stopped responding to steering")
        return

    # Immediate handbrake grab under steering, not a visibly delayed
    # grip lerp after multiple rendering frames.
    var flick: NitroDriveModel = DRIVE.new()
    flick.reset(Vector2.ZERO,0.0)
    flick.velocity = Vector2(0,-14.0)
    flick.step(STEP,0.72,0.9,0.0,1.0)
    if flick.rear_traction >= 0.70 or absf(flick.yaw_rate) <= 0.08:
        _fail("DRIFT did not trigger rear release and yaw impulse immediately")
        return
    if absf(flick.steering_angle) <= 0.055:
        _fail("Steering remains sluggish during the first driving tick")
        return

    var track: NitroDriftTrack = TRACK.new()
    root.add_child(track)
    await process_frame
    if track.centerline.size() < 100:
        _fail("Track spline failed")
        return
    if float(track.sample_info(track.start_position())["distance"]) > 0.1:
        _fail("Start does not lie on the road")
        return
    # The initial road MUST run up the portrait screen (-Z in world),
    # with the first turn to the right after the vertical section.
    var start_forward: Vector2 = (track.centerline[3]-track.centerline[0]).normalized()
    if start_forward.distance_to(Vector2(0,-1)) > 0.09:
        _fail("Start straight is not aligned vertically north")
        return
    if absf(track.centerline[12].x-track.centerline[0].x)>1.0:
        _fail("Start starts turning before the first long straight")
        return
    var tangent: Vector2 = Vector2(track.sample_info(track.start_position())["tangent"])
    var normal: Vector2 = Vector2(-tangent.y,tangent.x)
    for sign_side in [-1.0,1.0]:
        var outward: Vector2 = normal*sign_side
        var penetrating_pos: Vector2 = track.start_position() + outward*(track.HALF_ROAD_WIDTH+2.0)
        var moving_out: Vector2 = outward*12.0 + tangent*5.0
        var collision: Dictionary = track.resolve_wall(penetrating_pos,moving_out)
        if not bool(collision["hit"]):
            _fail("Visible wall does not produce a collision")
            return
        if float(collision["impact_speed"]) < 11.5:
            _fail("Wall did not record the impact speed")
            return
        if Vector2(collision["velocity"]).dot(outward) >= 0.0:
            _fail("Wall failed to bounce car back toward track")
            return
        var corrected: Dictionary = track.sample_info(Vector2(collision["position"]))
        if float(corrected["distance"]) > track.HALF_ROAD_WIDTH-track.CAR_WALL_CLEARANCE+0.08:
            _fail("Collision left car center outside the visible wall")
            return
    var inner: Vector2 = track.start_position()+normal*2.0
    if bool(track.resolve_wall(inner,normal*2.0)["hit"]):
        _fail("Wall collision triggers on normal driving surface")
        return
    track.queue_free()
    print("PASS: reverse, brake transition, grip calibration, recoverable drift, deterministic physics and circuit")
    quit(0)

func REVERSE_SAFE_CAP() -> float:
    return 9.5

func _fail(message: String) -> void:
    printerr("FAIL: " + message)
    quit(1)
