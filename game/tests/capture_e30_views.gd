extends SceneTree
## E30 visual refinement evidence (developer tool, needs a display):
##   xvfb-run -s "-screen 0 900x2000x24" godot --path game --rendering-driver opengl3 \
##     --resolution 900x2000 --script res://tests/capture_e30_views.gd -- /abs/out_dir
## Renders the real garage scene (same studio, backdrop and card as on the
## phone) with the turntable stopped at fixed angles, plus close-ups from fixed
## cameras inside the same studio, so BEFORE / AFTER sets are identical.
const VIEWS: Dictionary = {
    # name: turntable yaw (deg)
    "front34":145.0, "side":90.0, "rear34":-35.0, "front":180.0, "rear":0.0,
}
# name: [turntable yaw, camera position, look-at, fov]
const CLOSE: Dictionary = {
    "hood":[180.0,Vector3(0.0,1.85,4.15),Vector3(0.0,0.62,1.25),28.0],
    "apillar":[145.0,Vector3(2.4,1.75,2.6),Vector3(0.55,1.0,0.55),24.0],
    "grille":[180.0,Vector3(0.0,0.75,3.9),Vector3(0.0,0.56,2.0),22.0],
    "headlight":[180.0,Vector3(-1.05,0.80,3.55),Vector3(-0.52,0.57,2.12),15.0],
    "wheel":[90.0,Vector3(-1.40,0.55,3.70),Vector3(-1.40,0.30,0.71),19.0],
    "taillight":[180.0,Vector3(-0.85,1.00,-3.90),Vector3(-0.50,0.64,-2.10),17.0],
    "top":[145.0,Vector3(0.0,9.5,0.01),Vector3(0.0,0.0,0.0),34.0],
}

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    var out: String = (args[0] if args.size() > 0 else "user://e30_views").trim_suffix("/")+"/"
    DirAccess.make_dir_recursive_absolute(out)
    var cfg := ConfigFile.new()
    cfg.load("user://nitro_garage.cfg")
    var old_paint: Variant = cfg.get_value("garage","paint","red")
    cfg.set_value("garage","paint","e30")
    if cfg.has_section("cosmetics_e30"):
        cfg.erase_section("cosmetics_e30")
    cfg.save("user://nitro_garage.cfg")
    var garage: Node = load("res://scenes/garage.tscn").instantiate()
    root.add_child(garage)
    for i in range(6):
        await process_frame
    garage.spin_speed = 0.0
    var tt: Node3D = garage.turntable
    var preview: SubViewport = garage.preview
    for v in VIEWS.keys():
        tt.rotation.y = deg_to_rad(float(VIEWS[v]))
        for i in range(4):
            await process_frame
        preview.get_texture().get_image().save_png(out+"garage_"+str(v)+".png")
        root.get_viewport().get_texture().get_image().save_png(out+"screen_"+str(v)+".png")
    var cam := Camera3D.new()
    cam.near = 0.02
    preview.add_child(cam)
    for c in CLOSE.keys():
        var d: Array = CLOSE[c]
        tt.rotation.y = deg_to_rad(float(d[0]))
        cam.fov = float(d[3])
        cam.position = d[1]
        cam.look_at(d[2],Vector3.UP if c != "top" else Vector3.FORWARD)
        cam.current = true
        for i in range(4):
            await process_frame
        preview.get_texture().get_image().save_png(out+"close_"+str(c)+".png")
    cfg.set_value("garage","paint",old_paint)
    cfg.save("user://nitro_garage.cfg")
    print("E30 VIEWS SAVED ",ProjectSettings.globalize_path(out))
    quit(0)
