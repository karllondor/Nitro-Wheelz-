extends SceneTree
## Developer visual capture (NOT part of the automated pass/fail suite).
## Renders real scenes with a real GPU/software renderer and saves PNG stills
## so art changes can be reviewed against approved references.
##
## Usage (needs a display; Xvfb + Mesa works):
##   xvfb-run -s "-screen 0 720x1600x24" godot --path game \
##       --rendering-driver opengl3 --resolution 720x1600 \
##       --script res://tests/capture_visuals.gd -- /abs/output/dir [shots...]
## Shots: race_drift race_start race_chase garage_red garage_white menu editor
##        editor_help race_pause race_accent builder_partial builder_loop race_built

var out_dir: String = "user://captures"
var shots: PackedStringArray = PackedStringArray([
    "race_drift","race_start","race_chase","garage_red","garage_white","menu","editor"])

func _initialize() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() > 0:
        out_dir = args[0]
    if args.size() > 1:
        shots = args.slice(1)
    DirAccess.make_dir_recursive_absolute(out_dir)
    call_deferred("_run")

func _run() -> void:
    for shot in shots:
        match shot:
            "race_drift":
                await _race_shot(shot,"res://tracks/shin_kawa_v2.json",0,true)
            "race_start":
                await _race_shot(shot,"res://tracks/shin_kawa_v2.json",0,false)
            "race_chase":
                await _race_shot(shot,"res://tracks/shin_kawa_v2.json",1,true)
            "race_white":
                ProjectSettings.set_setting("nitro/car_variant","white")
                await _race_shot(shot,"res://tracks/shin_kawa_v2.json",0,true)
                ProjectSettings.set_setting("nitro/car_variant","red")
            "garage_red":
                await _garage_shot(shot,"red")
            "garage_white":
                await _garage_shot(shot,"white")
            "menu":
                await _scene_shot(shot,"res://scenes/boot.tscn")
            "editor":
                await _scene_shot(shot,"res://scenes/track_editor.tscn","_close_dialog")
            "editor_help":
                load("res://scripts/ui/track_editor.gd").set_help_hidden(false)
                await _scene_shot(shot,"res://scenes/track_editor.tscn")
            "race_pause":
                await _race_shot(shot,"res://tracks/shin_kawa_v2.json",0,false,true)
            "race_accent":
                var style = load("res://scripts/ui/hud_style.gd")
                var before: String = style.accent_name
                style.set_accent("cyan")
                await _race_shot(shot,"res://tracks/shin_kawa_v2.json",0,true)
                style.set_accent(before)
            "builder_partial":
                await _builder_shot(shot,false)
            "builder_loop":
                await _builder_shot(shot,true)
            "race_built":
                var grid: RefCounted = load("res://scripts/world/track_grid.gd").new(8,12)
                grid.generate(4242,24)
                var data: Dictionary = grid.to_track_data("MY BUILT CIRCUIT","player_built_track")
                var f := FileAccess.open("user://nitro_track_capture.json",FileAccess.WRITE)
                f.store_string(JSON.stringify(data))
                f.close()
                await _race_shot(shot,"user://nitro_track_capture.json",0,false)
    quit(0)

func _save(name: String) -> void:
    await process_frame
    await process_frame
    var image: Image = root.get_texture().get_image()
    var path: String = out_dir.path_join(name+".png")
    image.save_png(path)
    print("CAPTURED: "+path)

func _race_shot(name: String,track_path: String,camera_mode: int,drift: bool,pause: bool = false) -> void:
    ProjectSettings.set_setting("nitro/selected_track",track_path)
    var race: Node3D = (load("res://scenes/race.tscn") as PackedScene).instantiate()
    root.add_child(race)
    await process_frame
    var touch: Control = race.get("touch")
    if touch != null:
        touch.visible = true
    race.set_physics_process(false)
    var dt: float = 1.0/120.0
    if drift:
        # Scripted: accelerate, flick the handbrake into the first bend and
        # hold an angle with throttle + countersteer. Visual fixture only.
        Input.action_press("throttle")
        for i in range(330):
            race._physics_process(dt)
        Input.action_press("steer_right",0.85)
        Input.action_press("handbrake")
        for i in range(30):
            race._physics_process(dt)
        Input.action_release("handbrake")
        for i in range(70):
            race._physics_process(dt)
        Input.action_release("steer_right")
        Input.action_press("steer_left",0.25)
        for i in range(40):
            race._physics_process(dt)
        Input.action_release("steer_left")
        Input.action_release("throttle")
    else:
        Input.action_press("throttle")
        for i in range(60):
            race._physics_process(dt)
        Input.action_release("throttle")
    if camera_mode == 1:
        race.call("_toggle_camera")
    for i in range(90):
        race.call("_update_camera",1.0/60.0)
    if drift:
        # Let particle systems (tyre smoke) run for a moment.
        for i in range(36):
            await process_frame
    if pause:
        race.call("_toggle_pause")
        for i in range(4):
            await process_frame
    await _save(name)
    race.queue_free()
    await process_frame

func _builder_shot(name: String, full_loop: bool) -> void:
    var scene: Node3D = (load("res://scenes/track_builder.tscn") as PackedScene).instantiate()
    root.add_child(scene)
    await process_frame
    var grid: RefCounted = scene.get("grid")
    grid.clear()
    if full_loop:
        grid.generate(4242,24)
    else:
        scene.call("begin_stroke",Vector2i(2,3))
        for c in [Vector2i(5,3),Vector2i(5,6),Vector2i(6,6),Vector2i(6,9)]:
            scene.call("move_stroke",c)
        scene.call("end_stroke")
    scene.call("_rebuild")
    for i in range(6):
        await process_frame
    await _save(name)
    scene.queue_free()
    await process_frame

func _garage_shot(name: String,variant: String) -> void:
    ProjectSettings.set_setting("nitro/car_variant",variant)
    var cfg := ConfigFile.new()
    cfg.set_value("garage","paint",variant)
    cfg.save("user://nitro_garage.cfg")
    await _scene_shot(name,"res://scenes/garage.tscn")

func _scene_shot(name: String,path: String,after_ready: String = "") -> void:
    var node: Node = (load(path) as PackedScene).instantiate()
    root.add_child(node)
    await process_frame
    if not after_ready.is_empty() and node.has_method(after_ready):
        node.call(after_ready)
    for i in range(6):
        await process_frame
    await _save(name)
    node.queue_free()
    await process_frame
