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
    var car: NitroLadaLowPoly = race.car_root as NitroLadaLowPoly
    if car == null:
        _fail("Race does not contain the procedural low-poly Lada")
        return
    if car.rolling_wheels.size() != 4 or car.front_wheels.size() != 2:
        _fail("Wrong count of functional wheels")
        return
    var forward2: Vector2 = race.model.forward()
    var visible_front3: Vector3 = -car.global_transform.basis.z
    var visible_front2 := Vector2(visible_front3.x,visible_front3.z).normalized()
    if visible_front2.dot(forward2) < 0.999:
        _fail("Visual model points away from the driving model heading")
        return
    var road: Dictionary = race.track.sample_info(race.model.position)
    if forward2.dot(Vector2(road["tangent"])) < 0.96:
        _fail("Car spawns misaligned with road tangent")
        return
    var before: Vector2 = race.model.position
    race._toggle_camera()
    if race.camera_mode != 1 or race.model.position.distance_to(before) > 0.00001:
        _fail("Chase camera altered driving state")
        return
    race._toggle_camera()
    if race.camera_mode != 0:
        _fail("Cannot return to default top-down camera")
        return
    var controls: NitroRaceTouch = race.touch
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
    controls.release_all()
    if controls.throttle > 0.01 or controls.steer > 0.01 or controls.handbrake > 0.01:
        _fail("Touch controls remained pressed after release")
        return
    race.queue_free()
    await process_frame
    print("PASS: Lada wheels, physics/render forward alignment, road spawn, camera toggle and touch hit areas")
    quit(0)

func _fail(message: String) -> void:
    printerr("FAIL: "+message)
    quit(1)
