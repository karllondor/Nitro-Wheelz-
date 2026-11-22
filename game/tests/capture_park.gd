extends SceneTree
## NITRO WHEELZ PARK evidence (issue #27, developer tool, needs a display):
##   OUT_DIR=/abs/dir xvfb-run -a -s "-screen 0 900x2000x24" godot --path game \
##     --rendering-driver opengl3 --resolution 900x2000 --script res://tests/capture_park.gd
## Writes: the whole pad from above (orthographic overview), the game cameras (chase
## and top-down) at the start and at the logo, the tutorial screens (GAS highlight,
## the donut schematic, a running lesson with the ghost) and FREE DRIVE (no overlay).
const RACE = preload("res://scenes/race.tscn")
const LAYOUT = preload("res://scripts/park/park_layout.gd")
const DT: float = 1.0/120.0

var out_dir: String = "user://park/"

func _initialize() -> void:
    call_deferred("_run")

func _frames(n: int) -> void:
    for i in range(n):
        await process_frame

func _shot(name: String) -> void:
    await _frames(5)
    root.get_viewport().get_texture().get_image().save_png(out_dir+name+".png")

func _race(mode: String) -> Node3D:
    ProjectSettings.set_setting("nitro/selected_track",LAYOUT.TRACK_PATH)
    ProjectSettings.set_setting("nitro/park_mode",mode)
    ProjectSettings.set_setting("nitro/car_variant","white")
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    await _frames(30)
    race.touch.visible = true
    return race

func _run() -> void:
    var env_dir: String = OS.get_environment("OUT_DIR")
    if env_dir != "":
        out_dir = env_dir.trim_suffix("/")+"/"
    DirAccess.make_dir_recursive_absolute(out_dir)
    # ---------------------------------------------------------------- free drive
    var race: Node3D = await _race("free")
    race.set_physics_process(false)
    race._toggle_camera()
    for i in range(60):
        race.call("_update_camera",1.0/60.0)
    await _shot("free_1_start_chase")
    # whole pad from straight above
    var cam := Camera3D.new()
    cam.projection = Camera3D.PROJECTION_ORTHOGONAL
    cam.size = 420.0
    cam.rotation_degrees = Vector3(-90,0,0)
    cam.position = Vector3(0,200,0)
    race.add_child(cam)
    cam.current = true
    await _shot("overview_pad")
    cam.size = 120.0
    cam.position = Vector3(0,200,10)
    await _shot("overview_logo")
    cam.queue_free()
    race._toggle_camera()
    race._toggle_camera()
    race.queue_free()
    await _frames(5)
    # ---------------------------------------------------------------- tutorial
    race = await _race("tutorial")
    race.set_physics_process(false)
    race._toggle_camera()
    for i in range(60):
        race.call("_update_camera",1.0/60.0)
    await _shot("tutorial_1_gas")
    race.park.tutorial._begin_lesson(5)        # donut left: the schematic overlay
    await _shot("tutorial_2_donut_schematic")
    race.park.tutorial.dismiss_intro()
    race.model.position = Vector2(-60,10)
    race.model.heading = deg_to_rad(90.0)
    race.set_physics_process(true)
    Input.action_press("throttle")
    for i in range(40):
        race._physics_process(DT)
        race.call("_update_camera",DT)
    await _shot("tutorial_3_donut_running")
    race.park.tutorial._begin_lesson(7)        # large eight schematic
    await _shot("tutorial_4_eight_schematic")
    race.park.tutorial.dismiss_intro()
    race.park.ghost.travelled = 40.0
    await _shot("tutorial_5_eight_ghost")
    race.park.tutorial._begin_lesson(9)
    await _shot("tutorial_6_route_schematic")
    Input.action_release("throttle")
    quit(0)
