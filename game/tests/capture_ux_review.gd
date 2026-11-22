extends SceneTree
## Issue #28 evidence (developer tool, needs a display; DESIGN REVIEW ONLY, changes no game code):
##   OUT_DIR=/abs/dir xvfb-run -a -s "-screen 0 720x1600x24" godot --path game \
##     --rendering-driver opengl3 --resolution 720x1600 --script res://tests/capture_ux_review.gd
## Captures every menu page and the race HUD / pause / PARK as the player sees them (portrait 9:20),
## and prints the touch hit areas of the race HUD as JSON at 1080 x 2400 (the owner's phone recording
## resolution) so that sizes can be converted to millimetres.
const RACE = preload("res://scenes/race.tscn")
const BOOT = preload("res://scenes/boot.tscn")
const TOUCH = preload("res://scripts/ui/race_touch.gd")
const STYLE = preload("res://scripts/ui/hud_style.gd")
const CARS = preload("res://scripts/vehicles/car_catalog.gd")
const DT: float = 1.0/60.0

var out_dir: String = "user://ux_review/"

func _initialize() -> void:
    call_deferred("_run")

func _shot(name: String, frames: int = 8) -> void:
    for i in range(frames):
        await process_frame
    root.get_viewport().get_texture().get_image().save_png(out_dir+name+".png")

func _race(track: String, car: String) -> Node3D:
    ProjectSettings.set_setting("nitro/car_variant",car)
    ProjectSettings.set_setting("nitro/selected_track",track)
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    return race

func _run() -> void:
    var env_dir: String = OS.get_environment("OUT_DIR")
    if env_dir != "":
        out_dir = env_dir.trim_suffix("/")+"/"
    DirAccess.make_dir_recursive_absolute(out_dir)
    # Hit areas at 1080 x 2400 (portrait) for the millimetre table.
    var t = TOUCH.new()
    var geo: Dictionary = t._layout(Vector2(1080,2400))
    var out: Dictionary = {}
    for key in ["drift","brake","gas","pause","camera"]:
        var r: Rect2 = Rect2(geo[key])
        out[key] = [r.position.x,r.position.y,r.size.x,r.size.y]
    out["joystick_center"] = [Vector2(geo["joystick_center"]).x,Vector2(geo["joystick_center"]).y]
    out["joystick_radius"] = float(geo["joystick_radius"])
    var hud: Dictionary = STYLE.metrics(Vector2(1080,2400))
    out["gauge"] = [Vector2(hud["gauge_centre"]).x,Vector2(hud["gauge_centre"]).y,float(hud["gauge_radius"])]
    print("UX_GEOMETRY_JSON "+JSON.stringify(out))
    t.free()
    # Menus.
    var b: Control = BOOT.instantiate()
    b.set("navigate_enabled",false)
    root.add_child(b)
    await process_frame
    for page in ["main","setup","drive","park","profile","settings","dev"]:
        b.call("show_page",page)
        await _shot("menu_"+page)
    b.queue_free()
    await process_frame
    # Garage.
    var garage: Control = (load("res://scenes/garage.tscn") as PackedScene).instantiate()
    garage.set("navigate_enabled",false)
    root.add_child(garage)
    await _shot("menu_garage",12)
    garage.queue_free()
    await process_frame
    # Race HUD (chase view, driving) + pause.
    var race: Node3D = _race("res://tracks/shin_kawa_v2.json","red")
    for i in range(30):
        await process_frame
    race.set_physics_process(false)
    race.race_started = true
    race._toggle_camera()
    race.touch.visible = true
    Input.action_press("throttle")
    for i in range(300):
        race._physics_process(DT)
        race.call("_update_camera",DT)
    for i in range(40):
        if i < 30:
            Input.action_press("steer_right")
            Input.action_press("handbrake")
        race._physics_process(DT)
        race.call("_update_camera",DT)
    Input.action_release("steer_right")
    Input.action_release("handbrake")
    await _shot("race_hud_chase")
    # The same frame without HUD and touch controls: the background of the mock-ups.
    race.hud.visible = false
    race.touch.visible = false
    await _shot("race_world_clean")
    race.hud.visible = true
    race.touch.visible = true
    race._toggle_camera()
    for i in range(40):
        race.call("_update_camera",DT)
    await _shot("race_hud_topdown")
    race.call("_toggle_pause")
    await _shot("race_pause",12)
    Input.action_release("throttle")
    race.queue_free()
    await process_frame
    # PARK in free drive (the HUD without lap / score).
    ProjectSettings.set_setting("nitro/park_mode","free")
    var park: Node3D = _race("res://tracks/nitro_wheelz_park.json","e30")
    for i in range(40):
        await process_frame
    park.set_physics_process(false)
    park.race_started = true
    park.touch.visible = true
    Input.action_press("throttle")
    for i in range(200):
        park._physics_process(DT)
        park.call("_update_camera",DT)
    await _shot("park_free_drive")
    Input.action_release("throttle")
    quit(0)
