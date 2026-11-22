extends SceneTree
## Issue #16 evidence (developer tool, needs a display):
##   OUT_DIR=/abs/dir xvfb-run -s "-screen 0 960x540x24" godot --path game \
##     --rendering-driver opengl3 --resolution 960x540 --script res://tests/capture_smoke_probe.gd
## Eight tyre-smoke emitters (the race's exact CPUParticles3D settings) in a
## clean scene, left to right (P = BILLBOARD_PARTICLES, E = BILLBOARD_ENABLED,
## ks = billboard_keep_scale, vc = vertex colour as albedo, all with the ramp):
##   1 QuadMesh  P  ks=false vc    (the v0.1.33 smoke)
##   2 QuadMesh  P  ks=true  vc
##   3 QuadMesh  E  ks=false vc
##   4 QuadMesh  E  ks=true  vc
##   5 QuadMesh  P  ks=false, no vc
##   6 QuadMesh  P  ks=true,  no vc
##   7 QuadMesh  no billboard, vc
##   8 ArrayMesh (white colour array) E ks=true vc    (the shipped fix)
const RACE = preload("res://scripts/race/race.gd")

func _initialize() -> void:
    call_deferred("_run")

func _mat(tex: Texture2D, vertex_colour: bool, mode: int, keep: bool) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_texture = tex
    m.vertex_color_use_as_albedo = vertex_colour
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = mode as BaseMaterial3D.BillboardMode
    m.billboard_keep_scale = keep
    m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    return m

func _emitter(mesh: Mesh, pos: Vector3, ramp: bool) -> void:
    var s := CPUParticles3D.new()
    s.mesh = mesh
    s.amount = 36
    s.lifetime = 1.15
    s.local_coords = false
    s.emitting = true
    s.direction = Vector3(0.0,0.6,1.0)
    s.spread = 35.0
    s.initial_velocity_min = 0.6
    s.initial_velocity_max = 1.8
    s.gravity = Vector3(0.0,0.35,0.0)
    s.damping_min = 0.8
    s.damping_max = 1.4
    s.scale_amount_min = 0.9
    s.scale_amount_max = 1.4
    var grow := Curve.new()
    grow.add_point(Vector2(0.0,0.9))
    grow.add_point(Vector2(1.0,3.4))
    s.scale_amount_curve = grow
    if ramp:
        var fade := Gradient.new()
        fade.set_color(0,Color(0.92,0.92,0.98,0.42))
        fade.set_color(1,Color(0.80,0.80,0.90,0.0))
        s.color_ramp = fade
    s.position = pos
    root.add_child(s)

func _variant(i: int, tex: Texture2D) -> Array:
    var q := QuadMesh.new()
    var P: int = BaseMaterial3D.BILLBOARD_PARTICLES
    var E: int = BaseMaterial3D.BILLBOARD_ENABLED
    var N: int = BaseMaterial3D.BILLBOARD_DISABLED
    match i:
        0:
            q.material = _mat(tex,true,P,false)
        1:
            q.material = _mat(tex,true,P,true)
        2:
            q.material = _mat(tex,true,E,false)
        3:
            q.material = _mat(tex,true,E,true)
        4:
            q.material = _mat(tex,false,P,false)
        5:
            q.material = _mat(tex,false,P,true)
        6:
            q.material = _mat(tex,true,N,false)
        _:
            return [RACE.smoke_quad(_mat(tex,true,E,true)),true]
    return [q,true]

func _run() -> void:
    var out_dir: String = OS.get_environment("OUT_DIR") if OS.get_environment("OUT_DIR") != "" else "user://smoke/"
    DirAccess.make_dir_recursive_absolute(out_dir)
    var cam := Camera3D.new()
    cam.position = Vector3(0,1.5,15)
    root.add_child(cam)
    cam.look_at(Vector3(0,1.5,0))
    cam.current = true
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.18,0.2,0.26)
    var we := WorldEnvironment.new()
    we.environment = env
    root.add_child(we)
    var tex: ImageTexture = RACE.smoke_puff_texture()
    for i in range(8):
        var v: Array = _variant(i,tex)
        _emitter(v[0],Vector3(-8.75+2.5*float(i),0.5,0),bool(v[1]))
    for k in range(60):
        await process_frame
    root.get_viewport().get_texture().get_image().save_png(out_dir.trim_suffix("/")+"/smoke_probe.png")
    print("SMOKE PROBE CAPTURED to %s" % ProjectSettings.globalize_path(out_dir))
    quit(0)
