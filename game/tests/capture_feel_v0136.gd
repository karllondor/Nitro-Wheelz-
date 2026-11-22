extends SceneTree
## v0.1.36 evidence (developer tool, needs a display). The same script is run on
## the old and the new code to compare:
##   OUT_DIR=/abs/dir TAG=after TRACK=res://tracks/benchmark_oval.json CAR=red \
##   xvfb-run -a -s "-screen 0 900x2000x24" godot --path game --rendering-driver opengl3 \
##     --resolution 900x2000 --script res://tests/capture_feel_v0136.gd
## Loads a race, accelerates, drifts (handbrake flick + steering) so that tyre
## marks and smoke exist, and writes the whole screen (touch controls, HUD,
## road, clouds) at three moments: standing, mid drift, after the drift.
const RACE = preload("res://scenes/race.tscn")
const DT: float = 1.0/120.0

var out_dir: String = "user://feel/"

func _initialize() -> void:
    call_deferred("_run")

func _frames(n: int) -> void:
    for i in range(n):
        await process_frame

func _shot(name: String) -> void:
    await _frames(4)
    root.get_viewport().get_texture().get_image().save_png(out_dir+name+".png")

func _run() -> void:
    var env_dir: String = OS.get_environment("OUT_DIR")
    if env_dir != "":
        out_dir = env_dir.trim_suffix("/")+"/"
    DirAccess.make_dir_recursive_absolute(out_dir)
    var tag: String = OS.get_environment("TAG") if OS.get_environment("TAG") != "" else "run"
    var track: String = OS.get_environment("TRACK") if OS.get_environment("TRACK") != "" else "res://tracks/benchmark_oval.json"
    ProjectSettings.set_setting("nitro/car_variant",OS.get_environment("CAR") if OS.get_environment("CAR") != "" else "red")
    ProjectSettings.set_setting("nitro/selected_track",track)
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    await _frames(30)
    race.set_physics_process(false)
    race.race_started = true
    if str(OS.get_environment("CAMERA")) != "top":
        race._toggle_camera()      # the chase view of the phone screenshots
    race.touch.visible = true      # touch controls also on the desktop display
    for i in range(60):
        race.call("_update_camera",1.0/60.0)
    await _shot(tag+"_1_start")
    if OS.get_environment("LOGO") != "":
        # Put the car on the road shortly before the first NITRO WHEELZ inscription.
        var spots: Array = race.track.road_logo_spots()
        if not spots.is_empty():
            var at: Dictionary = race.track._road_at_arc(float(spots[0]["arc"])-float(OS.get_environment("LOGO")))
            var across: Vector2 = at["across"]
            var fwd := Vector2(across.y,-across.x)
            race.model.position = at["centre"]
            race.model.heading = atan2(fwd.x,-fwd.y)
            for i in range(90):
                race.call("_update_camera",1.0/60.0)
            await _shot(tag+"_0_logo")
    Input.action_press("throttle")
    for i in range(420):
        race._physics_process(DT)
        race.call("_update_camera",DT)
    for i in range(420):
        if i > 10 and i < 200:
            Input.action_press("steer_right")
        else:
            Input.action_release("steer_right")
        if i > 20 and i < 90:
            Input.action_press("handbrake")
        else:
            Input.action_release("handbrake")
        race._physics_process(DT)
        race.call("_update_camera",DT)
        if i == 110:
            await _shot(tag+"_2_drift")
    await _shot(tag+"_3_after")
    for a in ["throttle","steer_right","handbrake"]:
        Input.action_release(a)
    quit(0)
