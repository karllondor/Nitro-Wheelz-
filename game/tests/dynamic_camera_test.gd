extends SceneTree
## P1 camera numerical regression. Real view composition still requires
## playable Android/desktop recording.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene = load("res://scenes/race.tscn")
    var race: Node3D = scene.instantiate()
    root.add_child(race)
    await process_frame
    var overhead: Camera3D = race.get("overhead")
    var chase: Camera3D = race.get("chase")
    var model: NitroDriveModel = race.get("model")
    if overhead == null or chase == null or model == null:
        _fail("Cameras/model missing")
        return
    for test in [[0.0,1.15],[20.0,1.15],[50.0,1.0],
            [90.0,0.82],[120.0,0.72],[180.0,0.72]]:
        if absf(float(race._zoom_factor_for_speed(float(test[0])))-float(test[1])) > 0.001:
            _fail("Speed zoom calibration incorrect at "+str(test[0]))
            return
    model.velocity = Vector2.ZERO
    race._update_camera(1.0)
    var nearby_size: float = overhead.size
    model.velocity = Vector2(0,-25.0) # 90 km/h
    race._update_camera(1.0)
    var far_size: float = overhead.size
    if far_size < nearby_size*1.24:
        _fail("Overhead camera failed to zoom out during acceleration")
        return
    var velocity_lead: Vector3 = race.get("camera_velocity_lead")
    if velocity_lead.z > -6.0 or velocity_lead.length() > 19.01:
        _fail("Camera does not look forward along true velocity")
        return
    var initial_orientation: Vector3 = overhead.global_transform.basis.z
    model.heading = PI*0.72
    race._update_camera(0.15)
    if initial_orientation.dot(overhead.global_transform.basis.z) > 0.995:
        _fail("Drone follow view did not respond to heading")
        return
    var lateral: Vector3 = race._camera_lead_target(Vector2(18,0))
    if lateral.x < 7.0 or absf(lateral.z) > 0.001:
        _fail("Camera lead uses bonnet direction rather than travel direction")
        return
    var before: float = overhead.size
    model.velocity = Vector2.ZERO
    race._update_camera(1.0/120.0)
    if not (overhead.size < before and overhead.size > nearby_size-0.1):
        _fail("Zoom snapped instantly instead of smoothing on braking")
        return
    race._update_camera(1.0)
    if overhead.size >= far_size:
        _fail("Braking does not bring camera back towards car")
        return
    if chase.fov < 75.0 or chase.fov > 84.0:
        _fail("Chase FOV outside intended playtest bounds")
        return
    race.queue_free()
    await process_frame
    # v0.1.21: the same camera for both car profiles. Drive each car the same
    # way; the camera settings at a given speed are identical and the car
    # stays in the playable part of the screen in both views.
    var sizes: Array = []
    for variant in ["red","blue"]:
        load("res://scripts/vehicles/car_catalog.gd").select(variant)
        var r: Node3D = scene.instantiate()
        root.add_child(r)
        await process_frame
        var view: Vector2 = r.get_viewport().get_visible_rect().size
        var m: Dictionary = load("res://scripts/ui/hud_style.gd").metrics(view)
        var play := Rect2(0.0,Rect2(m["header"]).end.y,view.x,view.y*0.80-Rect2(m["header"]).end.y)
        Input.action_press("throttle",1.0)
        for i in range(150):
            await physics_frame
            if i == 90:
                Input.action_press("steer_right",0.6)
        for cam_mode in [0,1]:
            if int(r.get("camera_mode")) != cam_mode:
                r.call("_toggle_camera")
            r.call("_update_camera",1.0/60.0)
            var cam: Camera3D = r.get("overhead") if cam_mode == 0 else r.get("chase")
            var car_pos: Vector3 = (r.get("car_root") as Node3D).global_position
            if cam.is_position_behind(car_pos) or not play.has_point(cam.unproject_position(car_pos)):
                Input.action_release("throttle")
                Input.action_release("steer_right")
                _fail("%s car leaves the playable view in camera %d (%s)" % [variant,cam_mode,str(cam.unproject_position(car_pos))])
                return
        Input.action_release("throttle")
        Input.action_release("steer_right")
        var rm: NitroDriveModel = r.get("model")
        rm.velocity = Vector2(0,-25.0)
        if int(r.get("camera_mode")) != 0:
            r.call("_toggle_camera")
        for i in range(120):
            r.call("_update_camera",1.0/60.0)
        sizes.append([float((r.get("overhead") as Camera3D).size),float(r._zoom_factor_for_speed(90.0))])
        r.queue_free()
        await process_frame
    load("res://scripts/vehicles/car_catalog.gd").select("red")
    if absf(float(sizes[0][0])-float(sizes[1][0])) > 0.01 or sizes[0][1] != sizes[1][1]:
        _fail("Camera differs between car profiles at the same speed: "+str(sizes))
        return
    print("PASS: dynamic Camera3D zoom, acceleration/braking smoothing, true-velocity lookahead and drone-follow orientation, same camera for Lada and RYU-32 with the car in view")
    print("NOT RUN: real handset visibility, chase occlusion by decorative scenery")
    quit(0)

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)
