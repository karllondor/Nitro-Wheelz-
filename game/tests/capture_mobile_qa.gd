extends SceneTree
## v0.1.32 mobile QA evidence (developer tool, needs a display):
##   OUT_DIR=/abs/dir xvfb-run -s "-screen 0 720x1560x24" godot --path game \
##     --rendering-driver opengl3 --resolution 720x1560 --script res://tests/capture_mobile_qa.gd
## TOUCH DIAGNOSTICS in the Track Builder (two touches: the former dead strip
## and the MOVE button) and in a race (live wheel angles), plus the builder
## with the new near-road tile markers. Restores the developer switch.
const BUILDER = preload("res://scenes/terrain_builder.tscn")
const RACE = preload("res://scenes/race.tscn")
const TT = preload("res://scripts/world/terrain/terrain_track.gd")
const DIAG = preload("res://scripts/ui/touch_diagnostics.gd")

var out_dir: String = "user://mobile_qa/"

func _initialize() -> void:
    call_deferred("_run")

func _shot(name: String) -> void:
    for i in range(5):
        await process_frame
    root.get_viewport().get_texture().get_image().save_png(out_dir+name+".png")

func _touch(i: int, p: Vector2, on: bool) -> void:
    var e := InputEventScreenTouch.new()
    e.index = i
    # parse_input_event takes window coordinates (the viewport is stretched).
    e.position = root.get_final_transform()*p
    e.pressed = on
    Input.parse_input_event(e)

func _run() -> void:
    var env_dir: String = OS.get_environment("OUT_DIR")
    if env_dir != "":
        out_dir = env_dir.trim_suffix("/")+"/"
    DirAccess.make_dir_recursive_absolute(out_dir)
    var was: bool = DIAG.enabled()
    DirAccess.remove_absolute("user://nitro_terrain_builder_draft.json")
    DIAG.set_enabled(false)
    var b: Node3D = BUILDER.instantiate()
    root.add_child(b)
    await process_frame
    b._pick_country("japan")
    b._pick_landscape("jp_touge")
    b.terrain_seed = 1
    b.generate_terrain(false)
    b._enter_build()
    TT.generate_loop(b.grid,b.world.field,b.descriptor(),7)
    b.route_start = TT.route_order(b.grid)["order"][0]
    b._after_edit()
    b._set_view("3D")
    b._fit()
    b.cam_target = b.goal_target
    b.cam_dist = b.goal_dist
    b.cam_pitch = b.goal_pitch
    b.cam_yaw = 20.0
    b.goal_yaw = 20.0
    b._apply_camera()
    await _shot("builder_tile_markers")
    root.remove_child(b)
    b.free()
    # Builder with TOUCH DIAGNOSTICS: one finger in the former dead strip,
    # one on the MOVE button.
    DIAG.set_enabled(true)
    var b2: Node3D = BUILDER.instantiate()
    root.add_child(b2)
    await process_frame
    b2._pick_country("poland")
    b2._pick_landscape("pl_tatry")
    b2.terrain_seed = 3
    b2.generate_terrain(false)
    b2._enter_build()
    TT.generate_loop(b2.grid,b2.world.field,b2.descriptor(),5)
    b2.route_start = TT.route_order(b2.grid)["order"][0]
    b2._after_edit()
    b2._fit()
    b2.cam_target = b2.goal_target
    b2.cam_dist = b2.goal_dist
    b2._apply_camera()
    await process_frame
    var s: Vector2 = root.get_visible_rect().size
    var move_btn: Button = b2.buttons["MOVE"]
    var strip := Vector2(s.x*0.20,(b2.map_rect_setup.end.y+move_btn.get_global_rect().end.y)*0.5)
    b2.pan_mode = true
    _touch(0,strip,true)
    _touch(1,move_btn.get_global_rect().get_center(),true)
    await _shot("diag_builder")
    _touch(1,move_btn.get_global_rect().get_center(),false)
    _touch(0,strip,false)
    await process_frame
    root.remove_child(b2)
    b2.free()
    # Race with TOUCH DIAGNOSTICS: wheel angles during the first drift.
    ProjectSettings.set_setting("nitro/selected_track","res://tracks/shin_kawa_v2.json")
    ProjectSettings.set_setting("nitro/car_variant","red")
    var race: Node3D = RACE.instantiate()
    root.add_child(race)
    await process_frame
    race.set_physics_process(false)
    race.race_started = true
    Input.action_press("throttle")
    for i in range(170):
        if i == 130:
            Input.action_press("steer_right")
            Input.action_press("handbrake")
        race._physics_process(1.0/120.0)
    Input.action_release("handbrake")
    for i in range(30):
        race._physics_process(1.0/120.0)
    for i in range(60):
        race.call("_update_camera",1.0/60.0)
    await _shot("diag_race")
    for a in ["throttle","steer_right","handbrake"]:
        Input.action_release(a)
    root.remove_child(race)
    race.free()
    DIAG.set_enabled(was)
    DirAccess.remove_absolute("user://nitro_terrain_builder_draft.json")
    print("MOBILE QA CAPTURED to %s" % ProjectSettings.globalize_path(out_dir))
    quit(0)
