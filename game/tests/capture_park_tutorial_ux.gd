extends SceneTree
## Issue #27 tutorial bugfix evidence (developer tool, needs a display):
##   OUT_DIR=/abs/dir TAG=720 xvfb-run -a -s "-screen 0 720x1600x24" godot --path game \
##     --rendering-driver opengl3 --resolution 720x1600 --script res://tests/capture_park_tutorial_ux.gd
## Captures the welcome card, lesson 1, the schematic of lesson 6, the navigation to the left donut
## (banner + orbiting arrow + ring + guide line) from the start, and inside the exercise zone.
const RACE = preload("res://scenes/race.tscn")
const LAYOUT = preload("res://scripts/park/park_layout.gd")
const DT: float = 1.0/60.0
var out_dir: String = "user://park_ux/"
var tag: String = "run"

func _initialize() -> void:
    call_deferred("_run")

func _shot(name: String, frames: int = 6) -> void:
    for i in range(frames):
        await process_frame
    root.get_viewport().get_texture().get_image().save_png(out_dir+tag+"_"+name+".png")

func _cams(race: Node3D, n: int = 90) -> void:
    for i in range(n):
        race.call("_update_camera",DT)

func _run() -> void:
    var env_dir: String = OS.get_environment("OUT_DIR")
    if env_dir != "":
        out_dir = env_dir.trim_suffix("/")+"/"
    if OS.get_environment("TAG") != "":
        tag = OS.get_environment("TAG")
    DirAccess.make_dir_recursive_absolute(out_dir)
    ProjectSettings.set_setting("nitro/car_variant","e30")
    ProjectSettings.set_setting("nitro/selected_track","res://tracks/nitro_wheelz_park.json")
    ProjectSettings.set_setting("nitro/park_mode","tutorial")
    ProjectSettings.set_setting("nitro/park_reset",true)
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    for i in range(40):
        await process_frame
    race.set_physics_process(false)
    race.race_started = true
    race.touch.visible = true
    _cams(race)
    await _shot("1_welcome")
    race.park.tutorial.dismiss_intro()
    _cams(race,30)
    await _shot("2_gas_lesson")
    race.park.tutorial.start(5)
    await _shot("3_donut_schematic")
    race.park.tutorial.dismiss_intro()
    race.model.reset(Vector2(0,30),0.0)
    race.park.after_step(DT,0.0,0.0,0.0,0.0)
    _cams(race)
    await _shot("4_donut_far_topdown")
    race._toggle_camera()
    _cams(race)
    await _shot("5_donut_far_chase")
    # heading towards the ring, a little closer
    race.model.reset(Vector2(-55,25),deg_to_rad(-70.0))
    race.park.after_step(DT,0.0,0.0,0.0,0.0)
    _cams(race)
    await _shot("6_donut_closer_chase")
    race._toggle_camera()
    race.model.reset(Vector2(-105,0)+Vector2(14,0),deg_to_rad(-90.0))
    race.model.velocity = race.model.forward()*8.0
    race.park.after_step(DT,0.0,0.4,0.0,0.0)
    _cams(race)
    await _shot("7_donut_in_zone")
    quit(0)
