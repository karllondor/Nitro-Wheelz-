extends SceneTree
## Car Factory developer tool (NOT part of the pass/fail suite; needs a
## display). Renders a car from a camera solved by
## tools/car_factory/compare/camera_match.py, at the photo's resolution:
##   xvfb-run -s "-screen 0 1536x860x24" godot --path game --rendering-driver opengl3 \
##     --resolution 1536x860 --script res://tests/car_camera_match_render.gd -- \
##     /abs/cams.json photo_02_front_drift /abs/render.png [grey] [variant]
## Without "grey" the background is pure magenta (mask for overlay.py).
const CARS = preload("res://scripts/vehicles/car_catalog.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var a := OS.get_cmdline_user_args()
    var cams: Array = JSON.parse_string(FileAccess.get_file_as_string(a[0]))
    var cam_data: Dictionary = {}
    for c in cams:
        if c["photo"] == a[1]:
            cam_data = c
    var grey: bool = a.size() > 3 and a[3] == "grey"
    var variant: String = a[4] if a.size() > 4 else "e30"
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color(0.36,0.36,0.375) if grey else Color(1.0,0.0,1.0)
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.9,0.9,0.93)
    e.ambient_light_energy = 0.8
    env.environment = e
    root.add_child(env)
    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-50,35,0)
    key.light_energy = 1.1
    root.add_child(key)
    var car: Node3D = CARS.make(variant)
    root.add_child(car)
    for i in range(2):
        await process_frame
    var sh: Node = car.find_child("Soft contact shadow",true,false)
    if sh != null:
        sh.visible = false
    var cam := Camera3D.new()
    cam.keep_aspect = Camera3D.KEEP_HEIGHT
    cam.fov = float(cam_data["fov_v_deg"])
    cam.near = 0.05
    root.add_child(cam)
    var bx: Array = cam_data["basis_x"]
    var by: Array = cam_data["basis_y"]
    var bz: Array = cam_data["basis_z"]
    var p: Array = cam_data["cam_pos"]
    cam.global_transform = Transform3D(Basis(Vector3(bx[0],bx[1],bx[2]),Vector3(by[0],by[1],by[2]),
        Vector3(bz[0],bz[1],bz[2])),Vector3(p[0],p[1],p[2]))
    cam.current = true
    for i in range(4):
        await process_frame
    root.get_viewport().get_texture().get_image().save_png(a[2])
    quit(0)
