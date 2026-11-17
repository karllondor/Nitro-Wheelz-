extends Node3D
## Nitro Wheelz v0.1 driving laboratory: one original Japanese-style circuit.
## Authoritative vehicle state is planar; camera/visuals never modify the physics.

const TRACK = preload("res://scripts/world/drift_track.gd")
const DRIVE = preload("res://scripts/driving/drive_model.gd")
const HUD = preload("res://scripts/ui/race_hud.gd")
const TOUCH = preload("res://scripts/ui/race_touch.gd")

var model: NitroDriveModel
var track: NitroDriftTrack
var car_root: Node3D
var front_wheels: Array[Node3D] = []
var overhead: Camera3D
var chase: Camera3D
var touch: NitroRaceTouch
var hud: NitroRaceHUD
var camera_mode: int = 0
var time_elapsed: float = 0.0
var lap: int = 1
var last_progress: float = 0.0
var lap_started_at: float = 0.0
var lap_score: int = 0
var combo: float = 1.0
var combo_timer: float = 0.0
var paused: bool = false
var finished: bool = false
var offroad: bool = false

var skid_mesh: ImmediateMesh
var skid_material: StandardMaterial3D
var skid_segments: Array[PackedVector2Array] = []
var last_left: Vector2 = Vector2.ZERO
var last_right: Vector2 = Vector2.ZERO
var had_skid: bool = false
var skid_clock: float = 0.0

func _ready() -> void:
    track = TRACK.new()
    track.name = "Shin-Kawa Drift Park"
    add_child(track)
    model = DRIVE.new()
    model.reset(track.start_position(),track.start_heading())
    _make_car()
    _make_cameras()
    _make_tyre_marks()
    _make_ui()
    last_progress = float(track.sample_info(model.position)["progress"])
    _update_visuals()

func _make_car() -> void:
    car_root = Node3D.new()
    car_root.name = "Kumo Coupe - Prototype"
    add_child(car_root)
    _box(car_root, "Body",Vector3(1.84,0.48,3.75),Vector3(0,0.65,0),
        Color(0.86,0.29,0.19))
    _box(car_root, "Roof",Vector3(1.49,0.33,1.7),Vector3(0,1.02,0.08),
        Color(0.17,0.18,0.24))
    _box(car_root, "Windshield",Vector3(1.36,0.035,0.66),Vector3(0,1.20,-0.51),
        Color(0.09,0.12,0.18))
    _box(car_root, "Rear window",Vector3(1.36,0.035,0.50),Vector3(0,1.20,0.59),
        Color(0.09,0.12,0.18))
    _box(car_root, "Front hood line",Vector3(1.65,0.022,0.08),Vector3(0,0.91,-1.21),
        Color(0.98,0.41,0.26))
    for x_side in [-1.0,1.0]:
        _box(car_root,"Headlight",Vector3(0.47,0.15,0.07),
            Vector3(x_side*0.57,0.67,-1.91),Color(1.0,0.97,0.79),true)
        _box(car_root,"Tail lamp",Vector3(0.50,0.16,0.08),
            Vector3(x_side*0.56,0.69,1.92),Color(0.95,0.15,0.13),true)
        for z in [-1.26,1.26]:
            var steering_pivot := Node3D.new()
            steering_pivot.position = Vector3(x_side*1.01,0.39,z)
            car_root.add_child(steering_pivot)
            _box(steering_pivot,"Tyre",Vector3(0.41,0.67,0.80),
                Vector3.ZERO,Color(0.055,0.060,0.065))
            _box(steering_pivot,"Wheel centre",Vector3(0.08,0.36,0.38),
                Vector3(x_side*0.22,0,0),Color(0.58,0.59,0.62))
            if z < 0.0:
                front_wheels.append(steering_pivot)

func _box(parent: Node3D, item_name: String, dimensions: Vector3,
        local_position: Vector3, tint: Color, unshaded: bool=false) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = item_name
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    instance.mesh = mesh
    instance.position = local_position
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = 0.12
    mat.roughness = 0.5
    if unshaded:
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    instance.material_override = mat
    parent.add_child(instance)
    return instance

func _make_cameras() -> void:
    overhead = Camera3D.new()
    overhead.name = "DRIFTIT-like overhead"
    overhead.projection = Camera3D.PROJECTION_ORTHOGONAL
    overhead.size = 44.0
    overhead.current = true
    add_child(overhead)
    chase = Camera3D.new()
    chase.name = "Behind car"
    chase.fov = 68.0
    chase.current = false
    add_child(chase)
    _update_camera(1.0)

func _make_tyre_marks() -> void:
    skid_mesh = ImmediateMesh.new()
    skid_material = StandardMaterial3D.new()
    skid_material.albedo_color = Color(0.055,0.055,0.065,0.78)
    skid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    skid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    skid_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    var marks := MeshInstance3D.new()
    marks.name = "Persistent skid marks"
    marks.mesh = skid_mesh
    marks.material_override = skid_material
    add_child(marks)

func _make_ui() -> void:
    var overlay := CanvasLayer.new()
    overlay.layer = 4
    overlay.name = "Race HUD"
    add_child(overlay)
    hud = HUD.new()
    hud.name = "Lap / Speed / Score"
    overlay.add_child(hud)
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var touch_layer := CanvasLayer.new()
    touch_layer.layer = 6
    touch_layer.name = "Multitouch controls"
    add_child(touch_layer)
    touch = TOUCH.new()
    touch.name = "Steering / Drift / Brake / Gas"
    touch_layer.add_child(touch)
    touch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    touch.visible = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
    touch.camera_requested.connect(_toggle_camera)
    touch.pause_requested.connect(_toggle_pause)
    touch.restart_requested.connect(_restart)
    touch.menu_requested.connect(func():get_tree().change_scene_to_file("res://scenes/boot.tscn"))

func _physics_process(delta: float) -> void:
    if paused or finished:
        return
    time_elapsed += delta

    var steer: float = Input.get_axis("steer_left","steer_right")
    var gas: float = Input.get_action_strength("throttle")
    var braking: float = Input.get_action_strength("brake")
    var handbrake: float = Input.get_action_strength("handbrake")
    if touch != null and touch.visible:
        if touch.active_joystick:
            steer = touch.steer
        gas = maxf(gas,touch.throttle)
        braking = maxf(braking,touch.brake)
        handbrake = maxf(handbrake,touch.handbrake)

    # Fixed 120 Hz Godot tick and two internal model substeps (240 Hz).
    model.step(delta*0.5,steer,gas,braking,handbrake)
    model.step(delta*0.5,steer,gas,braking,handbrake)

    var info: Dictionary = track.sample_info(model.position)
    var lateral_distance: float = float(info["distance"])
    offroad = lateral_distance > track.HALF_ROAD_WIDTH
    if offroad:
        model.velocity *= maxf(0.0,1.0-1.15*delta)
    if lateral_distance > track.HALF_ROAD_WIDTH+2.1:
        var outward: Vector2 = model.position - Vector2(info["point"])
        if outward.length_squared() > 0.001:
            model.position = Vector2(info["point"]) + outward.normalized()*(track.HALF_ROAD_WIDTH+2.0)
        model.velocity *= 0.45
        model.yaw_rate *= 0.55

    _lap_logic(float(info["progress"]),Vector2(info["tangent"]),delta)
    _drift_scoring(delta)
    _record_marks(delta)
    _update_visuals()

func _lap_logic(progress: float, tangent: Vector2, _delta: float) -> void:
    # Count only a forward finish-line crossing after sufficient driving time.
    if last_progress > 0.94 and progress < 0.06 and time_elapsed-lap_started_at > 7.0:
        if model.velocity.dot(tangent) > 1.5:
            lap += 1
            lap_started_at = time_elapsed
            combo = 1.0
            if lap > 3:
                lap = 3
                finished = true
                model.velocity = Vector2.ZERO
    last_progress = progress

func _drift_scoring(dt: float) -> void:
    if model.is_drifting() and not offroad:
        var angle_ratio: float = minf(absf(model.drift_angle),75.0)/45.0
        var points: float = model.speed_mps()*pow(angle_ratio,1.2)*combo*dt*3.0
        lap_score += int(maxf(points,0.0)*10.0)
        combo_timer += dt
        if combo_timer > 1.8:
            combo = minf(5.0,combo+0.1)
            combo_timer = 0.0
    elif offroad:
        combo = 1.0
        combo_timer = 0.0
    else:
        combo_timer = maxf(combo_timer-dt,0.0)

func _record_marks(dt: float) -> void:
    skid_clock += dt
    if skid_clock < 0.07:
        return
    skid_clock = 0.0
    if not model.is_drifting() or offroad:
        had_skid = false
        return
    var p: Vector2 = model.position-model.forward()*1.22
    var left_p: Vector2 = p-model.right()*0.72
    var right_p: Vector2 = p+model.right()*0.72
    if had_skid:
        skid_segments.append(PackedVector2Array([last_left,left_p]))
        skid_segments.append(PackedVector2Array([last_right,right_p]))
        while skid_segments.size()>700:
            skid_segments.pop_front()
        _refresh_skid_mesh()
    last_left = left_p
    last_right = right_p
    had_skid = true

func _refresh_skid_mesh() -> void:
    skid_mesh.clear_surfaces()
    if skid_segments.is_empty():
        return
    skid_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,skid_material)
    for line in skid_segments:
        var a: Vector2 = line[0]
        var b: Vector2 = line[1]
        var delta: Vector2 = b-a
        if delta.length_squared() < 0.0001:
            continue
        var n: Vector2 = Vector2(-delta.y,delta.x).normalized()*0.13
        for p in [a-n,b-n,a+n,a+n,b-n,b+n]:
            skid_mesh.surface_set_normal(Vector3.UP)
            skid_mesh.surface_add_vertex(Vector3(p.x,0.08,p.y))
    skid_mesh.surface_end()

func _update_visuals() -> void:
    if car_root == null:
        return
    car_root.position = Vector3(model.position.x,0.0,model.position.y)
    car_root.rotation.y = model.heading
    for wheel in front_wheels:
        wheel.rotation.y = model.steering_angle
    if hud != null:
        hud.race_time = time_elapsed
        hud.lap = lap
        hud.speed = model.speed_kmh()
        hud.drift_degrees = model.drift_angle
        hud.score = lap_score
        hud.combo = combo
        hud.mode = "TOP-DOWN" if camera_mode == 0 else "CHASE"
        hud.paused = paused
        hud.finished = finished
        hud.road_status = "OFF TRACK" if offroad else "ON TRACK"
    if touch != null:
        touch.overlay_visible = paused or finished

func _process(delta: float) -> void:
    _update_camera(delta)

func _update_camera(delta: float) -> void:
    if model == null or overhead == null or chase == null:
        return
    var car_position: Vector3 = Vector3(model.position.x,0.0,model.position.y)
    var forward_dir: Vector2 = model.forward()
    var f: Vector3 = Vector3(forward_dir.x,0.0,forward_dir.y)
    var portrait: bool = get_viewport().get_visible_rect().size.y > get_viewport().get_visible_rect().size.x
    overhead.size = 45.0 if portrait else 40.0
    var overhead_target: Vector3 = car_position+Vector3(0,43,8)
    overhead.position = overhead.position.lerp(overhead_target,clampf(delta*7.0,0.0,1.0))
    overhead.look_at(car_position+f*6.0,Vector3.UP)
    var chase_target: Vector3 = car_position-f*9.5+Vector3(0,4.7,0)
    chase.position = chase.position.lerp(chase_target,clampf(delta*4.2,0.0,1.0))
    chase.look_at(car_position+f*11.0+Vector3.UP*1.5,Vector3.UP)

func _toggle_camera() -> void:
    camera_mode = 1-camera_mode
    overhead.current = camera_mode == 0
    chase.current = camera_mode == 1

func _toggle_pause() -> void:
    if finished:
        return
    paused = not paused
    _update_visuals()

func _restart() -> void:
    model.reset(track.start_position(),track.start_heading())
    time_elapsed = 0.0
    lap = 1
    last_progress = 0.0
    lap_started_at = 0.0
    lap_score = 0
    combo = 1.0
    combo_timer = 0.0
    paused = false
    finished = false
    offroad = false
    skid_segments.clear()
    skid_mesh.clear_surfaces()
    had_skid = false
    _update_visuals()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("camera_toggle"):
        get_viewport().set_input_as_handled()
        _toggle_camera()
    elif event.is_action_pressed("game_pause") or event.is_action_pressed("ui_cancel"):
        get_viewport().set_input_as_handled()
        _toggle_pause()
    elif event.is_action_pressed("race_restart"):
        get_viewport().set_input_as_handled()
        _restart()
    elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_M:
        get_viewport().set_input_as_handled()
        get_tree().change_scene_to_file("res://scenes/boot.tscn")

