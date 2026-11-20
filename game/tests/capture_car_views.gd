extends SceneTree
## Car Factory QA views for ANY car variant (developer tool, needs a display):
##   xvfb-run -s "-screen 0 900x2000x24" godot --path game --rendering-driver opengl3 \
##     --resolution 900x2000 --script res://tests/capture_car_views.gd -- /abs/out_dir e30 [race]
## Same garage studio, backdrop, card and lights as on the phone; the
## turntable stops at fixed angles (front 3/4, rear 3/4, left, right, front,
## rear) + a top view, then close-ups from cameras placed relative to the
## car's length / width (hood, A-pillar, grille + lamps, wheel, rear bumper,
## tail lamp), the full garage screen, and optionally race top-down + chase on
## the same track. BEFORE / AFTER sets are therefore identical.
const CATALOG = preload("res://scripts/vehicles/car_catalog.gd")
const VIEWS: Dictionary = {
    # name: turntable yaw (deg)
    "front34":145.0, "rear34":-35.0, "left":90.0, "right":-90.0, "front":180.0, "rear":0.0,
}

func _initialize() -> void:
    call_deferred("_run")

func _save(img: Image, path: String) -> void:
    img.save_png(path)

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    var out: String = (args[0] if args.size() > 0 else "user://car_views").trim_suffix("/")+"/"
    var variant: String = args[1] if args.size() > 1 else "e30"
    var with_race: bool = args.size() > 2 and args[2] == "race"
    DirAccess.make_dir_recursive_absolute(out)
    var cfg := ConfigFile.new()
    cfg.load("user://nitro_garage.cfg")
    var old_paint: Variant = cfg.get_value("garage","paint","red")
    cfg.set_value("garage","paint",variant)
    if cfg.has_section("cosmetics_"+variant):
        cfg.erase_section("cosmetics_"+variant)
    cfg.save("user://nitro_garage.cfg")
    ProjectSettings.set_setting("nitro/car_variant",variant)
    var garage: Node = load("res://scenes/garage.tscn").instantiate()
    root.add_child(garage)
    for i in range(6):
        await process_frame
    root.get_viewport().get_texture().get_image().save_png(out+"garage_screen.png")
    garage.spin_speed = 0.0
    var tt: Node3D = garage.turntable
    var preview: SubViewport = garage.preview
    for v in VIEWS.keys():
        tt.rotation.y = deg_to_rad(float(VIEWS[v]))
        for i in range(4):
            await process_frame
        preview.get_texture().get_image().save_png(out+"view_"+str(v)+".png")
    var inf: Dictionary = CATALOG.info(variant)
    var hl: float = float(inf.get("length",4.3))*0.5          # half length
    var hw: float = float(inf.get("width",1.7))*0.5           # half width
    var wb2: float = float(inf.get("wheelbase",2.5))*0.5
    var cam := Camera3D.new()
    cam.near = 0.02
    preview.add_child(cam)
    # name: [turntable yaw, camera position, look-at, fov]  (car faces +z at yaw 180)
    var close: Dictionary = {
        "top":[145.0,Vector3(0.0,9.5,0.01),Vector3.ZERO,34.0],
        "hood":[180.0,Vector3(0.0,1.85,hl+2.0),Vector3(0.0,0.62,hl*0.58),28.0],
        "apillar":[145.0,Vector3(2.4,1.75,2.6),Vector3(hw*0.6,1.0,hl*0.25),24.0],
        "grille":[180.0,Vector3(0.0,0.75,hl+1.75),Vector3(0.0,0.56,hl-0.15),24.0],
        "wheel":[90.0,Vector3(-wb2-0.15,0.55,3.70),Vector3(-wb2-0.15,0.30,hw*0.80),19.0],
        "rear_bumper":[180.0,Vector3(0.6,0.85,-(hl+1.9)),Vector3(0.0,0.42,-(hl-0.1)),26.0],
        "taillight":[180.0,Vector3(-0.85,1.00,-(hl+1.75)),Vector3(-hw*0.62,0.64,-(hl-0.06)),17.0],
    }
    for c in close.keys():
        var d: Array = close[c]
        tt.rotation.y = deg_to_rad(float(d[0]))
        cam.fov = float(d[3])
        cam.position = d[1]
        cam.look_at(d[2],Vector3.UP if c != "top" else Vector3.FORWARD)
        cam.current = true
        for i in range(4):
            await process_frame
        preview.get_texture().get_image().save_png(out+("view_top" if c == "top" else "close_"+str(c))+".png")
    root.remove_child(garage)
    garage.free()
    if with_race:
        for mode in [0,1]:
            ProjectSettings.set_setting("nitro/selected_track","res://tracks/shin_kawa_v2.json")
            var race: Node3D = (load("res://scenes/race.tscn") as PackedScene).instantiate()
            root.add_child(race)
            await process_frame
            race.set_physics_process(false)
            Input.action_press("throttle")
            for i in range(240):
                race._physics_process(1.0/120.0)
            Input.action_release("throttle")
            if mode == 1:
                race.call("_toggle_camera")
            for i in range(90):
                race.call("_update_camera",1.0/60.0)
            for i in range(4):
                await process_frame
            root.get_viewport().get_texture().get_image().save_png(out+("race_topdown" if mode == 0 else "race_chase")+".png")
            root.remove_child(race)
            race.free()
    cfg.set_value("garage","paint",old_paint)
    cfg.save("user://nitro_garage.cfg")
    print("CAR VIEWS SAVED %s %s" % [variant,ProjectSettings.globalize_path(out)])
    quit(0)
