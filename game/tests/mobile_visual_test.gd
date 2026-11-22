extends SceneTree
## Regression for v0.1.1 Android visual/model alignment and touch hit areas.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://scenes/race.tscn")
    var race: Node3D = packed.instantiate()
    root.add_child(race)
    await process_frame
    await process_frame
    if float(race.get("time_elapsed")) > 0.001 or bool(race.get("race_started")):
        _fail("Race timer started before the first GAS")
        return
    Input.action_press("throttle")
    race._physics_process(1.0/120.0)
    Input.action_release("throttle")
    if not bool(race.get("race_started")) or float(race.get("time_elapsed")) <= 0.0:
        _fail("Race timer did not start on first GAS")
        return
    var model: NitroDriveModel = race.get("model")
    var track: NitroDriftTrack = race.get("track")
    var car: Node3D = race.get("car_root") as Node3D
    if car == null:
        _fail("Race does not contain the selected player car")
        return
    var rolling: Array = car.get("rolling_wheels")
    var front: Array = car.get("front_wheels")
    if rolling.size() != 4 or front.size() != 2:
        _fail("Wrong count of functional wheels")
        return
    var forward2: Vector2 = model.forward()
    var visible_front3: Vector3 = -car.global_transform.basis.z
    var visible_front2 := Vector2(visible_front3.x,visible_front3.z).normalized()
    if visible_front2.dot(forward2) < 0.999:
        _fail("Visual model points away from the driving model heading")
        return
    var road: Dictionary = track.sample_info(model.position)
    if forward2.dot(Vector2(road["tangent"])) < 0.96:
        _fail("Car spawns misaligned with road tangent")
        return
    var before: Vector2 = model.position
    race.call("_toggle_camera")
    if int(race.get("camera_mode")) != 1 or model.position.distance_to(before) > 0.00001:
        _fail("Chase camera altered driving state")
        return
    race._toggle_camera()
    if int(race.get("camera_mode")) != 0:
        _fail("Cannot return to default top-down camera")
        return
    # Drone view is wider, tilted and follows heading with damping.
    var overhead: Camera3D = race.get("overhead")
    race.call("_update_camera",1.0)
    # Dynamic zoom legitimately moves closer when stopped. The camera
    # regression separately tests its full speed range and smoothing.
    if overhead.size < 49.0:
        _fail("Top-down camera is clipped beyond the intended minimum size")
        return
    var north_up: Vector3 = overhead.global_transform.basis.z
    model.heading = wrapf(model.heading + PI*0.75,-PI,PI)
    race.call("_update_camera",1.0)
    if north_up.dot(overhead.global_transform.basis.z) > 0.995:
        _fail("Drone-follow camera did not follow the new car heading")
        return

    var controls: NitroRaceTouch = race.get("touch")
    var rectangles: Dictionary = controls._layout()
    for name in ["drift","brake","gas","camera","pause"]:
        var control: Rect2 = Rect2(rectangles[name])
        if control.size.x <= 0 or control.size.y <= 0:
            _fail("Empty touch area: "+name)
            return
        if controls._zone_at(control.get_center()) != name:
            _fail("Visible control and actual touch zone do not match: "+name)
            return
    controls.contacts[0] = {"zone":"steering","pos":Vector2(rectangles["joystick_center"])+Vector2(40,0)}
    controls.contacts[1] = {"zone":"gas","pos":Rect2(rectangles["gas"]).get_center()}
    controls.contacts[2] = {"zone":"drift","pos":Rect2(rectangles["drift"]).get_center()}
    controls._recompute()
    if controls.steer < 0.1 or controls.throttle < 0.99 or controls.handbrake < 0.99:
        _fail("Three-finger steering/gas/drift input did not combine")
        return

    # Portrait controls are wider/taller and share no overlapping targets.
    var portrait_controls: Dictionary = controls._layout(Vector2(720,1600))
    var gas_pedal: Rect2 = Rect2(portrait_controls["gas"])
    var brake_pedal: Rect2 = Rect2(portrait_controls["brake"])
    var drift_rect: Rect2 = Rect2(portrait_controls["drift"])
    if gas_pedal.size.y < brake_pedal.size.y*1.35 or gas_pedal.position.y >= brake_pedal.position.y:
        _fail("Gas pedal must be taller and start higher than brake")
        return
    if absf(brake_pedal.size.x-720.0*0.160)>1.0 or absf(gas_pedal.size.x-720.0*0.158)>1.0:
        _fail("Portrait pedal sizing diverged from reference")
        return
    if drift_rect.position.y < 1600.0*0.46 or drift_rect.size.y < 1600.0*0.29:
        _fail("Handbrake must stay lowered and be easily pressed")
        return
    if gas_pedal.intersects(brake_pedal) or drift_rect.intersects(gas_pedal):
        _fail("Mobile control hit rectangles overlap")
        return
    controls.release_all()
    if controls.throttle > 0.01 or controls.steer > 0.01 or controls.handbrake > 0.01:
        _fail("Touch controls remained pressed after release")
        return
    race.queue_free()
    await process_frame
    print("PASS: selected car wheels, physics/render forward alignment, road spawn, camera toggle and touch hit areas")
    quit(0)

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)
