extends SceneTree
## Issue #16 evidence (developer tool, needs a display):
##   OUT_DIR=/abs/dir CAR=blue TAG=run xvfb-run -a -s "-screen 0 720x1560x24" godot --path game \
##     --rendering-driver opengl3 --resolution 720x1560 --script res://tests/capture_wheel_first_drift.gd
## Loads a race right after the start (cold, like the phone), launches the car
## and drifts it with the handbrake exactly as wheel_visual_test does, and writes
## crops around the car in BOTH cameras (top-down and chase): before the drift,
## in the drift, and after RESTART. Also writes <out>/wheels_<tag>.txt with the
## measured geometry of every wheel: its mesh bounds in the car frame, the
## projected size of the tyre in px, the angle of its axle against the body and
## which side of the body shell it pokes out.
const RACE = preload("res://scenes/race.tscn")
const DT: float = 1.0/120.0

var out_dir: String = "user://wheels/"
var notes := PackedStringArray()

func _initialize() -> void:
    call_deferred("_run")

func _frames(n: int) -> void:
    for i in range(n):
        await process_frame

func _crop(race: Node3D, name: String) -> void:
    await _frames(4)
    var img: Image = root.get_viewport().get_texture().get_image()
    var cam: Camera3D = root.get_viewport().get_camera_3d()
    var car: Node3D = race.get("car_root")
    # unproject_position is in (stretched) viewport units; the image is in window pixels.
    var p: Vector2 = root.get_final_transform()*cam.unproject_position(car.global_position+Vector3(0,0.5,0))
    var half: int = 190
    var x0: int = clampi(int(p.x)-half,0,maxi(img.get_width()-2*half,0))
    var y0: int = clampi(int(p.y)-half,0,maxi(img.get_height()-2*half,0))
    img.get_region(Rect2i(x0,y0,mini(2*half,img.get_width()),mini(2*half,img.get_height()))).save_png(out_dir+name+".png")
    img.save_png(out_dir+name+"_full.png")

func _mesh_bounds(n: Node3D, car: Node3D) -> AABB:
    var best := AABB()
    var first: bool = true
    for m in n.find_children("*","MeshInstance3D",true,false):
        var mi: MeshInstance3D = m
        if mi.mesh == null:
            continue
        var to_car: Transform3D = car.global_transform.affine_inverse()*mi.global_transform
        var a: AABB = to_car*mi.mesh.get_aabb()
        best = a if first else best.merge(a)
        first = false
    return best

func _measure(race: Node3D, label: String) -> void:
    var car: Node3D = race.get("car_root")
    var wheels: Array = car.get("rolling_wheels")
    var cam: Camera3D = root.get_viewport().get_camera_3d()
    var inv: Basis = car.global_transform.basis.orthonormalized().inverse()
    for i in range(wheels.size()):
        var w: Node3D = wheels[i]
        var b: AABB = _mesh_bounds(w,car)
        var axle: Vector3 = inv*w.global_transform.basis.x.normalized()
        var yaw: float = rad_to_deg(atan2(axle.z,absf(axle.x)))
        var roll_ax: float = rad_to_deg(asin(clampf(axle.y,-1.0,1.0)))
        var c: Vector3 = b.get_center()
        var corners: Array = []
        for sx in [0,1]:
            for sy in [0,1]:
                for sz in [0,1]:
                    var q: Vector3 = b.position+Vector3(b.size.x*sx,b.size.y*sy,b.size.z*sz)
                    corners.append(cam.unproject_position(car.global_transform*q))
        var lo := Vector2(INF,INF)
        var hi := Vector2(-INF,-INF)
        for q2 in corners:
            lo = Vector2(minf(lo.x,q2.x),minf(lo.y,q2.y))
            hi = Vector2(maxf(hi.x,q2.x),maxf(hi.y,q2.y))
        notes.append("%s wheel %d: centre(car frame)=(%.3f, %.3f, %.3f) size=(%.3f, %.3f, %.3f) outer |x|=%.3f axle yaw=%.2f deg axle tilt=%.2f deg projected %.0f x %.0f px" % [
            label,i,c.x,c.y,c.z,b.size.x,b.size.y,b.size.z,absf(c.x)+b.size.x*0.5,yaw,roll_ax,hi.x-lo.x,hi.y-lo.y])

func _drive(race: Node3D, ticks: int, drift: bool) -> void:
    for i in range(ticks):
        Input.action_press("throttle")
        if drift and i > 40 and i < 200:
            Input.action_press("steer_right")
        else:
            Input.action_release("steer_right")
        if drift and i > 50 and i < 110:
            Input.action_press("handbrake")
        else:
            Input.action_release("handbrake")
        race._physics_process(DT)

func _film(race: Node3D, cam_tag: String, tag: String, variant: String) -> void:
    # Launch on the start straight, then the FIRST drift of the run (steer +
    # handbrake flick at speed, like the phone): one crop every 10 physics
    # ticks (1/12 s) from just before the flick.
    race._restart()
    race.race_started = true
    await _frames(2)
    for i in range(60):
        race.call("_update_camera",1.0/60.0)
    Input.action_press("throttle")
    for i0 in range(300):
        race._physics_process(DT)
        race.call("_update_camera",DT)
    for step in range(24):
        for k in range(10):
            var i2: int = step*10+k
            if i2 < 90:
                Input.action_press("steer_right")
            else:
                Input.action_release("steer_right")
            if i2 > 10 and i2 < 50:
                Input.action_press("handbrake")
            else:
                Input.action_release("handbrake")
            race._physics_process(DT)
            race.call("_update_camera",DT)
        await _crop(race,"film_%s_%s_%s_%02d" % [tag,variant,cam_tag,step])
        var sm: Array = race.tyre_smoke
        notes.append("film %s %02d: drift=%.1f deg steer=%.1f speed=%.0f smoke_emitting=%s" % [cam_tag,step,rad_to_deg(race.model.drift_angle),rad_to_deg(race.model.steering_angle),race.model.speed_kmh(),str((sm[0] as CPUParticles3D).emitting) if not sm.is_empty() else "n/a"])
    for a in ["throttle","steer_right","handbrake"]:
        Input.action_release(a)

func _run() -> void:
    var env_dir: String = OS.get_environment("OUT_DIR")
    if env_dir != "":
        out_dir = env_dir.trim_suffix("/")+"/"
    DirAccess.make_dir_recursive_absolute(out_dir)
    var tag: String = OS.get_environment("TAG") if OS.get_environment("TAG") != "" else "run"
    var variant: String = OS.get_environment("CAR") if OS.get_environment("CAR") != "" else "blue"
    ProjectSettings.set_setting("nitro/car_variant",variant)
    ProjectSettings.set_setting("nitro/selected_track","res://tracks/shin_kawa_v2.json")
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    await _frames(30)
    race.set_physics_process(false)
    race.race_started = true
    if OS.get_environment("FILM") != "":
        for mode0 in [0,1]:
            if int(race.camera_mode) != mode0:
                race._toggle_camera()
            await _film(race,"top" if mode0 == 0 else "chase",tag,variant)
        var nf0 := FileAccess.open(out_dir+"film_"+tag+"_"+variant+".txt",FileAccess.WRITE)
        nf0.store_string("\n".join(notes)+"\n")
        nf0.close()
        print("\n".join(notes))
        print("WHEELS CAPTURED to %s" % ProjectSettings.globalize_path(out_dir))
        quit(0)
        return
    for mode in [0,1]:
        if int(race.camera_mode) != mode:
            race._toggle_camera()
        var cam_tag: String = "top" if mode == 0 else "chase"
        race._restart()
        race.race_started = true
        await _frames(2)
        for i in range(60):
            race.call("_update_camera",1.0/60.0)
        await _crop(race,"wheels_%s_%s_%s_0start" % [tag,variant,cam_tag])
        _measure(race,"%s/%s start" % [variant,cam_tag])
        # Launch, then the first drift of this run.
        _drive(race,100,true)
        for i in range(80):
            race.call("_update_camera",1.0/60.0)
        await _crop(race,"wheels_%s_%s_%s_1drift_a" % [tag,variant,cam_tag])
        _measure(race,"%s/%s drift-a steer=%.1f deg drift=%.1f deg speed=%.0f" % [variant,cam_tag,rad_to_deg(race.model.steering_angle),rad_to_deg(race.model.drift_angle),race.model.speed_kmh()])
        _drive(race,60,true)
        for i in range(30):
            race.call("_update_camera",1.0/60.0)
        await _crop(race,"wheels_%s_%s_%s_2drift_b" % [tag,variant,cam_tag])
        _measure(race,"%s/%s drift-b steer=%.1f deg drift=%.1f deg speed=%.0f" % [variant,cam_tag,rad_to_deg(race.model.steering_angle),rad_to_deg(race.model.drift_angle),race.model.speed_kmh()])
        for a in ["throttle","steer_right","handbrake"]:
            Input.action_release(a)
    var nf := FileAccess.open(out_dir+"wheels_"+tag+"_"+variant+".txt",FileAccess.WRITE)
    nf.store_string("\n".join(notes)+"\n")
    nf.close()
    print("\n".join(notes))
    print("WHEELS CAPTURED to %s" % ProjectSettings.globalize_path(out_dir))
    quit(0)
