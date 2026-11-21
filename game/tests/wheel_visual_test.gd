extends SceneTree
## v0.1.32 mobile QA ("rear wheels steer on the first drift after starting a
## run"): for every car model (procedural Lada / RYU-32, E30 GLB, the Car
## Factory test models) the race drives a scripted launch + handbrake drift
## right after the start and again after a RESTART; every physics step the
## visual yaw of each wheel relative to the body is measured.
##  * a rear wheel never turns (RWD: no visual steering on the rear axle);
##  * the front wheels show the physics steering angle (same sign / value);
##  * the body yaw equals the physics heading;
##  * the first drift and the drift after RESTART read the same.
const RACE = preload("res://scenes/race.tscn")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const DT: float = 1.0/120.0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var was_factory: bool = CARS.factory_test_models()
    var err: String = ""
    var summary: PackedStringArray = []
    for factory in [false,true]:
        CARS.set_factory_test_models(factory)
        for variant in ["red","white","blue","e30"]:
            if factory and variant == "e30":
                continue
            var r: Dictionary = await _drive(variant)
            if not str(r.get("err","")).is_empty():
                err = "%s%s: %s" % [variant,(" (factory)" if factory else ""),r["err"]]
                break
            summary.append("%s%s rear %.2f / front err %.2f / body %.2f deg" % [variant,("*" if factory else ""),
                float(r["rear"]),float(r["front_err"]),float(r["body"])])
        if not err.is_empty():
            break
    CARS.set_factory_test_models(was_factory)
    for a in ["throttle","steer_right","steer_left","handbrake"]:
        Input.action_release(a)
    if not err.is_empty():
        printerr("FAIL: "+err)
        quit(1)
        return
    print("wheel visuals: "+"; ".join(summary))
    print("PASS: wheel visuals on every car (procedural, E30 GLB, factory test models) - rear wheels never steer (0.00 deg), front wheels = physics steering angle, body yaw = physics heading, first drift after the start == drift after RESTART")
    for _f in range(3):
        await process_frame
    quit(0)

func _wheels(car: Node3D) -> Array:
    var out: Array = []
    var rolling: Variant = car.get("rolling_wheels")
    if rolling is Array:
        out = rolling
    return out

func _drive(variant: String) -> Dictionary:
    ProjectSettings.set_setting("nitro/car_variant",variant)
    ProjectSettings.set_setting("nitro/selected_track","res://tracks/shin_kawa_v2.json")
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    await process_frame
    race.set_physics_process(false)
    var out: Dictionary = {"rear":0.0,"front_err":0.0,"body":0.0}
    var runs: Array = []
    for run in range(2):
        if run == 1:
            race._restart()
        race.race_started = true
        var car: Node3D = race.get("car_root")
        var wheels: Array = _wheels(car)
        if wheels.size() != 4:
            out["err"] = "expected 4 rolling wheels, found %d" % wheels.size()
            break
        var trace: PackedFloat32Array = []
        for i in range(420):
            var t: float = i*DT
            Input.action_press("throttle")
            if t > 1.1 and t < 2.6:
                Input.action_press("steer_right")
            else:
                Input.action_release("steer_right")
            if t > 1.3 and t < 1.7:
                Input.action_press("handbrake")
            else:
                Input.action_release("handbrake")
            race._physics_process(DT)
            var inv: Basis = car.global_transform.basis.orthonormalized().inverse()
            var fwd: Vector3 = -car.global_transform.basis.z
            var pf: Vector2 = race.model.forward()
            out["body"] = maxf(float(out["body"]),absf(rad_to_deg(Vector2(fwd.x,fwd.z).angle_to(pf))))
            for w in wheels:
                var n: Node3D = w
                var axle: Vector3 = inv*n.global_transform.basis.x.normalized()
                var yaw: float = rad_to_deg(atan2(axle.z,absf(axle.x)))
                var at: Vector3 = inv*(n.global_position-car.global_position)
                if at.z > 0.0:
                    out["rear"] = maxf(float(out["rear"]),absf(yaw))
                else:
                    # Visual front yaw vs the physics steering angle.
                    out["front_err"] = maxf(float(out["front_err"]),absf(absf(yaw)-absf(rad_to_deg(race.model.steering_angle))))
            if i % 12 == 0:
                trace.append(rad_to_deg(race.model.steering_angle))
        runs.append(trace)
        for a in ["throttle","steer_right","handbrake"]:
            Input.action_release(a)
    root.remove_child(race)
    race.free()
    if out.has("err"):
        return out
    if float(out["rear"]) > 0.01:
        out["err"] = "a REAR wheel turned %.2f deg" % float(out["rear"])
    elif float(out["front_err"]) > 0.6:
        out["err"] = "front wheel visual differs from the physics steering by %.2f deg" % float(out["front_err"])
    elif float(out["body"]) > 0.05:
        out["err"] = "body yaw differs from the physics heading by %.2f deg" % float(out["body"])
    else:
        var a: PackedFloat32Array = runs[0]
        var b: PackedFloat32Array = runs[1]
        for k in range(mini(a.size(),b.size())):
            if absf(a[k]-b[k]) > 0.5:
                out["err"] = "first drift differs from the drift after RESTART (steer %.1f vs %.1f deg at %.2f s)" % [a[k],b[k],k*12*DT]
                break
    return out
