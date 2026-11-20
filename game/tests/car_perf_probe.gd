extends SceneTree
## Developer performance probe (NOT part of the pass/fail suite; needs a
## display, e.g. xvfb-run + Mesa llvmpipe). For each car: (1) the car alone
## in front of a camera at race distance, (2) the full race scene with that
## car. Prints draw calls, primitives and mean / p95 frame time.
##
##   xvfb-run -s "-screen 0 720x1600x24" godot --path game --rendering-driver opengl3 \
##       --resolution 720x1600 --script res://tests/car_perf_probe.gd -- red blue e30
## Numbers from a software renderer are only RELATIVE between cars; phone and
## browser numbers must be measured on the devices.
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const FRAMES: int = 150

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var variants: PackedStringArray = OS.get_cmdline_user_args()
    if variants.is_empty():
        variants = PackedStringArray(["red","blue","e30"])
    print("CAR_PERF renderer=%s adapter=%s" % [RenderingServer.get_current_rendering_method(),
        RenderingServer.get_video_adapter_name()])
    for v in variants:
        var alone: Dictionary = await _alone(v)
        var race: Dictionary = await _race(v)
        print("CAR_PERF %s | alone: draw_calls %d primitives %d frame_ms mean %.2f p95 %.2f | race: draw_calls %d primitives %d frame_ms mean %.2f p95 %.2f" % [
            v,alone["calls"],alone["prims"],alone["mean"],alone["p95"],race["calls"],race["prims"],race["mean"],race["p95"]])
    quit(0)

func _alone(v: String) -> Dictionary:
    var holder := Node3D.new()
    root.add_child(holder)
    var env := WorldEnvironment.new()
    env.environment = Environment.new()
    holder.add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50,35,0)
    holder.add_child(sun)
    var car: Node3D = CARS.make(v)
    car.scale = Vector3.ONE*1.15
    holder.add_child(car)
    var cam := Camera3D.new()
    holder.add_child(cam)
    cam.position = Vector3(-4.0,3.2,-6.5)
    cam.look_at(Vector3(0,0.6,0),Vector3.UP)
    cam.current = true
    var r: Dictionary = await _measure(func(_i): car.rotation.y += 0.01)
    holder.queue_free()
    await process_frame
    return r

func _race(v: String) -> Dictionary:
    ProjectSettings.set_setting("nitro/car_variant",v)
    ProjectSettings.set_setting("nitro/selected_track","res://tracks/shin_kawa_v2.json")
    var race: Node3D = (load("res://scenes/race.tscn") as PackedScene).instantiate()
    root.add_child(race)
    await process_frame
    Input.action_press("throttle")
    var r: Dictionary = await _measure(func(_i): pass)
    Input.action_release("throttle")
    race.queue_free()
    await process_frame
    return r

func _measure(step: Callable) -> Dictionary:
    for i in range(20):
        await process_frame
    var times: Array[float] = []
    var calls: int = 0
    var prims: int = 0
    for i in range(FRAMES):
        step.call(i)
        var t0: int = Time.get_ticks_usec()
        await process_frame
        RenderingServer.force_draw(false)
        times.append(float(Time.get_ticks_usec()-t0)/1000.0)
        calls = maxi(calls,RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
        prims = maxi(prims,RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
    times.sort()
    var mean: float = 0.0
    for t in times:
        mean += t
    mean /= float(times.size())
    return {"calls":calls,"prims":prims,"mean":mean,"p95":times[int(times.size()*0.95)]}
